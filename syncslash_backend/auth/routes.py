from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from google.oauth2 import id_token
from google.auth.transport import requests
import jwt
import datetime
from backend.db.connection import run_query
import os

router = APIRouter(prefix="/auth", tags=["Authentication"])

GOOGLE_CLIENT_ID = os.getenv("GOOGLE_WEB_CLIENT_ID", "your_google_web_client_id_here")
JWT_SECRET = os.getenv("JWT_SECRET", "super_secret_dev_key")

class GoogleAuthRequest(BaseModel):
    idToken: str

@router.post("/google")
def google_login(request: GoogleAuthRequest):
    try:
        
        idinfo = id_token.verify_oauth2_token(
            request.idToken, requests.Request(), GOOGLE_CLIENT_ID
        )
        
        email = idinfo['email']
        name = idinfo.get('name', '')

        user_rows = run_query("SELECT * FROM Users WHERE email = %s", (email,))
        
        if not user_rows:
            
            run_query(
                "INSERT INTO Users (name, email) VALUES (%s, %s)",
                (name, email), fetch=False
            )
            user_rows = run_query("SELECT * FROM Users WHERE email = %s", (email,))
            
        user = user_rows[0]

        expiration = datetime.datetime.utcnow() + datetime.timedelta(days=7)
        token = jwt.encode(
            {"user_id": user['user_id'], "email": email, "exp": expiration},
            JWT_SECRET,
            algorithm="HS256"
        )

        return {"access_token": token, "user": {"user_id": user['user_id'], "name": name}}

    except ValueError:
        raise HTTPException(status_code=401, detail="Invalid Google token")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

class DirectLoginRequest(BaseModel):
    email: str
    name: str

@router.post("/login")
def direct_login(request: DirectLoginRequest):
    try:
        email = request.email
        name = request.name

        user_rows = run_query("SELECT * FROM Users WHERE email = %s", (email,))

        if not user_rows:
            run_query(
                "INSERT INTO Users (name, email) VALUES (%s, %s)",
                (name, email), fetch=False
            )
            user_rows = run_query("SELECT * FROM Users WHERE email = %s", (email,))

        user = user_rows[0]

        expiration = datetime.datetime.utcnow() + datetime.timedelta(days=7)
        token = jwt.encode(
            {"user_id": user['user_id'], "email": email, "exp": expiration},
            JWT_SECRET,
            algorithm="HS256"
        )

        return {"access_token": token, "user": {"user_id": user['user_id'], "name": user['name']}}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))