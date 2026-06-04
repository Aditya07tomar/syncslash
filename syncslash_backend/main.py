import os
from dotenv import load_dotenv
load_dotenv()

db_url = os.getenv("DATABASE_URL", "")
if db_url.startswith("postgres://"):
    os.environ["DATABASE_URL"] = db_url.replace("postgres://", "postgresql://", 1)

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware 
from backend.b1_ingestion.routes import router as b1_router
from backend.auth.routes import router as auth_router 
from backend.b2_analytics.routes import router as b2_router  

app = FastAPI(
    title="Subscription Fatigue Optimizer API",
    version="1.0.0",
    description="DBMS Project — IIIT Allahabad"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  
    allow_credentials=True,
    allow_methods=["*"],  
    allow_headers=["*"],  
)

@app.on_event("startup")
def on_startup():
    from backend.init_db import init_database
    init_database()

app.include_router(b1_router)
app.include_router(auth_router) 
app.include_router(b2_router)   

from backend.db.connection import run_query
from fastapi import HTTPException
from pydantic import BaseModel
import uuid

class CreateCardRequest(BaseModel):
    user_id: int
    sub_id: int

class SimulatePaymentRequest(BaseModel):
    card_token: str
    amount: float

@app.post("/virtualcard/create", tags=["B3 — Payments"])
def create_virtual_card(req: CreateCardRequest):
    try:
        card_number = "VC-" + str(uuid.uuid4())[:12].upper()
        run_query(
,
            params=(req.user_id, req.sub_id, card_number),
            fetch=True
        )
        
        card_rows = run_query(
            "SELECT card_id FROM Virtual_Cards WHERE card_number = %s",
            params=(card_number,)
        )
        if card_rows:
            run_query(
                "UPDATE Subscriptions SET virtual_card_id = %s WHERE sub_id = %s AND user_id = %s",
                params=(card_rows[0]['card_id'], req.sub_id, req.user_id),
                fetch=False
            )
        return {"success": True, "card_number": card_number, "status": "active"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/virtualcards/{user_id}", tags=["B3 — Payments"])
def get_user_cards(user_id: int):
    try:
        rows = run_query("""
            SELECT vc.card_id, vc.card_number, vc.status, vc.created_at,
                   s.sub_id, sv.service_name, s.detected_cost
            FROM Virtual_Cards vc
            LEFT JOIN Subscriptions s ON vc.sub_id = s.sub_id
            LEFT JOIN Services sv ON s.service_id = sv.service_id
            WHERE vc.user_id = %s
            ORDER BY vc.created_at DESC
Freeze a virtual card (kill switch)."""
    try:
        result = run_query(
            "UPDATE Virtual_Cards SET status = 'frozen' WHERE card_id = %s RETURNING card_id",
            params=(card_id,),
            fetch=True
        )
        if not result:
            raise HTTPException(status_code=404, detail="Card not found")
        
        run_query(
            "UPDATE Subscriptions SET status = 'frozen' WHERE virtual_card_id = %s",
            params=(card_id,),
            fetch=False
        )
        return {"success": True, "message": "Card frozen successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/virtualcard/{card_id}/unfreeze", tags=["B3 — Payments"])
def unfreeze_card(card_id: int):
    try:
        result = run_query(
            "UPDATE Virtual_Cards SET status = 'active' WHERE card_id = %s RETURNING card_id",
            params=(card_id,),
            fetch=True
        )
        if not result:
            raise HTTPException(status_code=404, detail="Card not found")
        run_query(
            "UPDATE Subscriptions SET status = 'active' WHERE virtual_card_id = %s",
            params=(card_id,),
            fetch=False
        )
        return {"success": True, "message": "Card unfrozen successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/virtualcard/{card_id}", tags=["B3 — Payments"])
def cancel_card(card_id: int):
    try:
        
        run_query(
            "UPDATE Subscriptions SET virtual_card_id = NULL WHERE virtual_card_id = %s",
            params=(card_id,),
            fetch=False
        )
        result = run_query(
            "DELETE FROM Virtual_Cards WHERE card_id = %s RETURNING card_id",
            params=(card_id,),
            fetch=True
        )
        if not result:
            raise HTTPException(status_code=404, detail="Card not found")
        return {"success": True, "message": "Card cancelled and deleted"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/payments/simulate", tags=["B3 — Payments"])
def simulate_payment(req: SimulatePaymentRequest):
    try:
        rows = run_query(
            "SELECT status FROM Virtual_Cards WHERE card_number = %s",
            params=(req.card_token,)
        )
        if not rows:
            raise HTTPException(status_code=404, detail="Invalid card token")
        if rows[0]['status'] == 'frozen':
            raise HTTPException(status_code=403, detail="Transaction Blocked: Card is Frozen")
        return {"success": True, "message": f"Successfully charged ₹{req.amount}"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

class CreateBillRequest(BaseModel):
    sub_id: int
    payer_id: int
    debtor_id: int
    amount_owed: float
    due_date: str = None

class SettleBillRequest(BaseModel):
    bill_id: int

@app.get("/p2p/balances/{user_id}", tags=["P2P — Shared Bills"])
def get_p2p_balances(user_id: int):
    try:
        
        owes_you = run_query("""
            SELECT sb.bill_id, sb.amount_owed, sb.status, sb.due_date,
                   u.name AS friend_name, u.email AS friend_email,
                   sv.service_name
            FROM Shared_Bills sb
            JOIN Users u ON sb.debtor_id = u.user_id
            LEFT JOIN Subscriptions s ON sb.sub_id = s.sub_id
            LEFT JOIN Services sv ON s.service_id = sv.service_id
            WHERE sb.payer_id = %s AND sb.status = 'pending'
            ORDER BY sb.created_at DESC
            SELECT sb.bill_id, sb.amount_owed, sb.status, sb.due_date,
                   u.name AS friend_name, u.email AS friend_email,
                   sv.service_name
            FROM Shared_Bills sb
            JOIN Users u ON sb.payer_id = u.user_id
            LEFT JOIN Subscriptions s ON sb.sub_id = s.sub_id
            LEFT JOIN Services sv ON s.service_id = sv.service_id
            WHERE sb.debtor_id = %s AND sb.status = 'pending'
            ORDER BY sb.created_at DESC
Create a new shared bill / P2P request."""
    try:
        run_query(
,
            params=(req.sub_id, req.payer_id, req.debtor_id, req.amount_owed, req.due_date),
            fetch=False
        )
        return {"success": True, "message": "Shared bill created"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/p2p/settle", tags=["P2P — Shared Bills"])
def settle_bill(req: SettleBillRequest):
    try:
        result = run_query(
,
            params=(req.bill_id,),
            fetch=True
        )
        if not result:
            raise HTTPException(status_code=404, detail="Bill not found or already settled")
        return {"success": True, "message": "Bill settled successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/p2p/history/{user_id}", tags=["P2P — Shared Bills"])
def get_p2p_history(user_id: int):
    try:
        rows = run_query("""
            SELECT sb.bill_id, sb.amount_owed, sb.status, sb.due_date, sb.settled_at,
                   payer.name AS payer_name, debtor.name AS debtor_name,
                   sv.service_name,
                   CASE WHEN sb.payer_id = %s THEN 'sent' ELSE 'received' END AS direction
            FROM Shared_Bills sb
            JOIN Users payer ON sb.payer_id = payer.user_id
            JOIN Users debtor ON sb.debtor_id = debtor.user_id
            LEFT JOIN Subscriptions s ON sb.sub_id = s.sub_id
            LEFT JOIN Services sv ON s.service_id = sv.service_id
            WHERE sb.payer_id = %s OR sb.debtor_id = %s
            ORDER BY sb.created_at DESC
            LIMIT 50
        CREATE TABLE IF NOT EXISTS Subscription_Groups (
            group_id     SERIAL PRIMARY KEY,
            name         VARCHAR(100) NOT NULL,
            invite_code  VARCHAR(10) UNIQUE NOT NULL,
            sub_id       INT REFERENCES Subscriptions(sub_id),
            creator_id   INT NOT NULL REFERENCES Users(user_id),
            created_at   TIMESTAMP DEFAULT NOW()
        )
        CREATE TABLE IF NOT EXISTS Group_Members (
            id         SERIAL PRIMARY KEY,
            group_id   INT NOT NULL REFERENCES Subscription_Groups(group_id) ON DELETE CASCADE,
            user_id    INT NOT NULL REFERENCES Users(user_id),
            joined_at  TIMESTAMP DEFAULT NOW(),
            UNIQUE(group_id, user_id)
        )
Get groups the user belongs to."""
    try:
        rows = run_query("""
            SELECT sg.group_id, sg.name, sg.invite_code, sg.sub_id,
                   sv.service_name, sv.category, s.detected_cost,
                   (SELECT COUNT(*) FROM Group_Members gm WHERE gm.group_id = sg.group_id) AS member_count
            FROM Group_Members gm
            JOIN Subscription_Groups sg ON gm.group_id = sg.group_id
            LEFT JOIN Subscriptions s ON sg.sub_id = s.sub_id
            LEFT JOIN Services sv ON s.service_id = sv.service_id
            WHERE gm.user_id = %s
            ORDER BY sg.created_at DESC
Create a new group with an invite code."""
    try:
        invite_code = _gen_invite_code()
        run_query(
,
            params=(req.name, invite_code, req.sub_id, req.creator_id),
            fetch=False
        )
        
        group_rows = run_query(
            "SELECT group_id FROM Subscription_Groups WHERE invite_code = %s",
            params=(invite_code,)
        )
        if group_rows:
            
            run_query(
                "INSERT INTO Group_Members (group_id, user_id) VALUES (%s, %s)",
                params=(group_rows[0]['group_id'], req.creator_id),
                fetch=False
            )
        return {"success": True, "invite_code": invite_code, "name": req.name}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

class JoinGroupRequest(BaseModel):
    invite_code: str
    user_id: int

@app.post("/groups/join", tags=["Groups"])
def join_group(req: JoinGroupRequest):
    try:
        group_rows = run_query(
            "SELECT group_id, name FROM Subscription_Groups WHERE invite_code = %s",
            params=(req.invite_code,)
        )
        if not group_rows:
            raise HTTPException(status_code=404, detail="Invalid invite code")

        group_id = group_rows[0]['group_id']
        group_name = group_rows[0]['name']

        existing = run_query(
            "SELECT id FROM Group_Members WHERE group_id = %s AND user_id = %s",
            params=(group_id, req.user_id)
        )
        if existing:
            return {"success": True, "message": "Already a member", "group_name": group_name}

        run_query(
            "INSERT INTO Group_Members (group_id, user_id) VALUES (%s, %s)",
            params=(group_id, req.user_id),
            fetch=False
        )
        return {"success": True, "message": f"Joined '{group_name}' successfully!", "group_name": group_name}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

class SubFreezeRequest(BaseModel):
    user_id: int

@app.post("/subscription/{sub_id}/freeze", tags=["B3 — Payments"])
def freeze_subscription(sub_id: int, req: SubFreezeRequest):
    try:
        result = run_query(
            "UPDATE Subscriptions SET status = 'frozen' WHERE sub_id = %s AND user_id = %s RETURNING sub_id",
            params=(sub_id, req.user_id),
            fetch=True
        )
        if not result:
            raise HTTPException(status_code=404, detail="Subscription not found")
        return {"success": True, "message": "Subscription frozen"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/subscription/{sub_id}/unfreeze", tags=["B3 — Payments"])
def unfreeze_subscription(sub_id: int, req: SubFreezeRequest):
    try:
        result = run_query(
            "UPDATE Subscriptions SET status = 'active' WHERE sub_id = %s AND user_id = %s RETURNING sub_id",
            params=(sub_id, req.user_id),
            fetch=True
        )
        if not result:
            raise HTTPException(status_code=404, detail="Subscription not found")
        return {"success": True, "message": "Subscription unfrozen"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

import sys as _sys
import os as _os
_cpp_path = _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "cpp_engine-P2P")
if _cpp_path not in _sys.path:
    _sys.path.insert(0, _cpp_path)

from settlement_wrapper import settle_debts_as_dicts, CPP_AVAILABLE

@app.get("/settlement/engine-status", tags=["C++ Engine"])
def settlement_engine_status():
    return {
        "cpp_engine_loaded": CPP_AVAILABLE,
        "engine": "C++ pybind11 (O3 optimized)" if CPP_AVAILABLE else "Python fallback",
        "algorithm": "Minimum Cash Flow — Greedy"
    }

@app.get("/settlement/optimize/{group_id}", tags=["C++ Engine"])
def optimize_group_settlement(group_id: int):
    try:
        
        group_rows = run_query("""
            SELECT sg.group_id, sg.name, sg.creator_id, sg.sub_id,
                   COALESCE(s.detected_cost, 0) as total_cost,
                   u.name as creator_name
            FROM Subscription_Groups sg
            LEFT JOIN Subscriptions s ON sg.sub_id = s.sub_id
            LEFT JOIN Users u ON sg.creator_id = u.user_id
            WHERE sg.group_id = %s
            SELECT gm.user_id, u.name
            FROM Group_Members gm
            JOIN Users u ON gm.user_id = u.user_id
            WHERE gm.group_id = %s
    Health check endpoint.
    Why does this exist?
    In production, monitoring tools ping /health every 30 seconds.
    If it stops responding, alerts fire and the server restarts.
    Standard practice for any production API.
    """
    from backend.db.connection import run_query
    try:
        run_query("SELECT 1")
        db_status = "connected"
    except:
        db_status = "disconnected"

    return {
        "api": "running",
        "database": db_status
    }