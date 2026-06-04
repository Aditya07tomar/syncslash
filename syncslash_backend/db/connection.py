import psycopg2
import psycopg2.extras  
import os
from dotenv import load_dotenv

load_dotenv()

def get_connection():
    return psycopg2.connect(os.getenv("DATABASE_URL"))

def run_query(sql: str, params=None, fetch=True):
    conn = get_connection()
    
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        cur.execute(sql, params)
        if fetch:
            rows = cur.fetchall()
            conn.commit()
            
            from decimal import Decimal
            from datetime import date, datetime
            cleaned = []
            for row in rows:
                d = {}
                for k, v in dict(row).items():
                    if isinstance(v, Decimal):
                        d[k] = float(v)
                    elif isinstance(v, (date, datetime)):
                        d[k] = str(v)
                    else:
                        d[k] = v
                cleaned.append(d)
            return cleaned
        else:
            conn.commit()
            return cur.rowcount
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        cur.close()
        conn.close()