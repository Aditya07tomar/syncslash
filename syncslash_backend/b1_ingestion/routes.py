from fastapi import APIRouter, HTTPException
from backend.b1_ingestion.importer import setup_sandbox_user, import_transactions
from backend.b1_ingestion.pattern_matcher import run_pipeline
from backend.db.connection import run_query

router = APIRouter(
    prefix="/ingestion",   
    tags=["B1 - Ingestion"] 
)

@router.post("/connect/{user_id}")
def connect_bank(user_id: int):
    """
    Step 1 of the user journey: connect their bank account.
    Creates a Plaid sandbox token, exchanges it for an
    access token, stores it in Users.plaid_token.
    Why POST and not GET?
    GET requests should only READ data, never change it.
    This endpoint WRITES an access token to the database.
    HTTP convention: anything that changes server state = POST.
    Why is user_id in the URL and not the request body?
    It identifies WHICH resource we're acting on.
    URL path = resource identifier.
    Request body = data being sent to create/update something.
    """
    try:
        access_token = setup_sandbox_user(user_id)
        return {
            "success": True,
            "message": f"Bank connected for user {user_id}",
            "user_id": user_id
            
        }
    except Exception as e:
        
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/sync/{user_id}")
def sync_transactions(user_id: int):
    """
    Step 2: pull latest transactions from Plaid and run
    the full classification pipeline.
    This is the most important endpoint in B1.
    It triggers: fetch → insert → classify → upsert subscriptions
    Everything in one call.
    Why POST and not GET?
    Syncing writes new rows to Transaction_Logs and updates
    Subscriptions. It changes database state → POST.
    """
    try:
        
        rows = run_query(
            "SELECT plaid_token FROM Users WHERE user_id = %s",
            params=(user_id,)
        )

        if not rows:
            raise HTTPException(
                status_code=404,  
                detail=f"User {user_id} not found"
            )

        if not rows[0]['plaid_token']:
            raise HTTPException(
                status_code=400,  
                detail="Bank account not connected. Call /connect first."
            )

        access_token = rows[0]['plaid_token']
        result = import_transactions(user_id, access_token)

        return {
            "success": True,
            "user_id": user_id,
            **result  
        }
    except HTTPException:
        raise  
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/subscriptions/{user_id}")
def get_subscriptions(user_id: int):
    """
    The main endpoint F1 (frontend) calls to render
    the subscription list screen.
    Returns all active subscriptions with service details
    and total monthly burn.
    Why GET?
    This only reads data, changes nothing → GET.
    GET requests can be cached by browsers and CDNs.
    POST requests cannot. For read-heavy endpoints
    this is a meaningful performance difference.
    """
    try:
        rows = run_query("""
            SELECT
                sub.sub_id,
                sub.detected_cost,
                sub.next_renewal,
                sub.status,
                sub.detected_by_b1,
                s.service_name,
                s.category,
                s.logo_url,
                -- Calculate days until next renewal
                -- Why in SQL and not Python?
                -- Sending raw dates to frontend means frontend
                -- does date math in multiple places.
                -- Centralise it here once.
                (sub.next_renewal - CURRENT_DATE) AS days_until_renewal
            FROM Subscriptions sub
            JOIN Services s ON sub.service_id = s.service_id
            WHERE sub.user_id = %s
              AND sub.status = 'active'
            ORDER BY sub.detected_cost DESC
        """, params=(user_id,))

        total_burn = sum(
            float(r['detected_cost']) for r in rows
            if r['detected_cost']
        )

        return {
            "user_id": user_id,
            "total_subscriptions": len(rows),
            "total_monthly_burn": round(total_burn, 2),
            "subscriptions": rows
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/transactions/{user_id}")
def get_transactions(user_id: int, limit: int = 50):
    """
    Returns raw transaction log for a user.
    Used by the 'Discovery' screen in F1 to show
    what the bank reported before classification.
    Why 'limit: int = 50' as a parameter?
    Transactions can be thousands of rows.
    Sending all of them kills mobile performance.
    Default limit of 50 is enough for the screen.
    Frontend can pass ?limit=100 if it needs more.
    This is called pagination — a standard API pattern.
    """
    try:
        rows = run_query("""
            SELECT
                txn_id,
                merchant_name,
                description,
                amount,
                txn_date,
                is_subscription,
                service_id
            FROM Transaction_Logs
            WHERE user_id = %s
            ORDER BY txn_date DESC
            LIMIT %s
        """, params=(user_id, limit))

        return {
            "user_id": user_id,
            "count": len(rows),
            "transactions": rows
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/summary/{user_id}")
def get_summary(user_id: int):
    """
    A summary endpoint for the dashboard header.
    B2 also uses this to know the baseline cost
    before computing the fatigue score.
    Returns: total burn, count by category,
    most expensive subscription, next renewal date.
    """
    try:
        
        category_rows = run_query("""
            SELECT
                s.category,
                COUNT(*) AS count,
                SUM(sub.detected_cost) AS category_total
            FROM Subscriptions sub
            JOIN Services s ON sub.service_id = s.service_id
            WHERE sub.user_id = %s
              AND sub.status = 'active'
            GROUP BY s.category
            ORDER BY category_total DESC
        """, params=(user_id,))

        next_renewal_rows = run_query("""
            SELECT
                s.service_name,
                sub.next_renewal,
                sub.detected_cost
            FROM Subscriptions sub
            JOIN Services s ON sub.service_id = s.service_id
            WHERE sub.user_id = %s
              AND sub.status = 'active'
              AND sub.next_renewal >= CURRENT_DATE
            ORDER BY sub.next_renewal ASC
            LIMIT 1
        """, params=(user_id,))

        total_row = run_query("""
            SELECT
                COALESCE(SUM(detected_cost), 0) AS total_monthly,
                COUNT(*) AS total_count
            FROM Subscriptions
            WHERE user_id = %s AND status = 'active'
        """, params=(user_id,))

        return {
            "user_id": user_id,
            "total_monthly_burn": float(total_row[0]['total_monthly']),
            "total_subscriptions": total_row[0]['total_count'],
            "by_category": category_rows,
            "next_renewal": next_renewal_rows[0] if next_renewal_rows else None
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))