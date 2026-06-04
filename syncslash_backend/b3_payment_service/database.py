from sqlalchemy import create_engine, Column, String, select
from sqlalchemy.orm import declarative_base, sessionmaker
import uuid

DATABASE_URL = "postgresql://admin:password@localhost:5432/payments_db"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

class VirtualCard(Base):
    __tablename__ = "virtual_cards"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, index=True)
    subscription_id = Column(String)
    token = Column(String, unique=True, index=True)
    status = Column(String, default="active")

Base.metadata.create_all(bind=engine)