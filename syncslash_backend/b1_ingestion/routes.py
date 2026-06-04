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
    Returns raw transaction log for a user.
    Used by the 'Discovery' screen in F1 to show
    what the bank reported before classification.
    Why 'limit: int = 50' as a parameter?
    Transactions can be thousands of rows.
    Sending all of them kills mobile performance.
    Default limit of 50 is enough for the screen.
    Frontend can pass ?limit=100 if it needs more.
    This is called pagination — a standard API pattern.
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
    A summary endpoint for the dashboard header.
    B2 also uses this to know the baseline cost
    before computing the fatigue score.
    Returns: total burn, count by category,
    most expensive subscription, next renewal date.
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