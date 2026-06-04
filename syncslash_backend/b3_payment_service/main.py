from fastapi import FastAPI, HTTPException, Depends
import redis
import uuid
from sqlalchemy.orm import Session
from database import SessionLocal, VirtualCard

app = FastAPI(title="B3 Payment Microservice")
redis_client = redis.Redis(host='localhost', port=6379, db=0, decode_responses=True)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.post("/virtualcard/create")
def create_card(user_id: str, subscription_id: str, db: Session = Depends(get_db)):
    card_token = str(uuid.uuid4())
    
    new_card = VirtualCard(user_id=user_id, subscription_id=subscription_id, token=card_token, status="active")
    db.add(new_card)
    db.commit()
    
    redis_client.set(f"card:{card_token}:status", "active")
    
    return {"message": "Card created", "card_token": card_token, "status": "active"}

@app.post("/virtualcard/{card_token}/freeze")
def freeze_card(card_token: str, db: Session = Depends(get_db)):
    
    card = db.query(VirtualCard).filter(VirtualCard.token == card_token).first()
    if not card:
        raise HTTPException(status_code=404, detail="Card not found")
    
    card.status = "frozen"
    db.commit()

    redis_client.set(f"card:{card_token}:status", "frozen")

    return {"message": "Kill-switch activated. Card is frozen."}

@app.post("/payments/simulate")
def simulate_charge(card_token: str, amount: float):
    
    status = redis_client.get(f"card:{card_token}:status")
    
    if status is None:
        raise HTTPException(status_code=404, detail="Invalid Card Token")
    
    if status == "frozen":
        
        raise HTTPException(status_code=403, detail="Transaction Blocked: Card is Frozen")
        
    return {"message": f"Successfully charged ${amount}"}

    @app.get("/virtualcards/all")
    def get_all_cards(db: Session = Depends(get_db)):
    
       cards = db.query(VirtualCard).all()
    return cards