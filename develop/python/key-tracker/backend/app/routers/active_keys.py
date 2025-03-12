from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func, and_
from typing import List
from app.database import get_db
from app.models import Site, Key, History
from app.schemas import ActiveIssuedKeyResponse

router = APIRouter(tags=["Active Keys"])

@router.get("/active-keys/", response_model=List[ActiveIssuedKeyResponse])
async def get_active_issued_keys(db: Session = Depends(get_db)):
    # Знаходимо останні записи історії для кожного ключа
    latest_history = (
        db.query(
            History.key_id,
            func.max(History.history_id).label("latest_id")
        )
        .group_by(History.key_id)
        .subquery()
    )
    
    history_data = (
        db.query(History)
        .join(latest_history, and_(
            History.key_id == latest_history.c.key_id,
            History.history_id == latest_history.c.latest_id
        ))
        .subquery()
    )
    
    # Отримуємо всі ключі, позначені як видані
    active_keys = (
        db.query(
            Site.site_code,
            Key.description.label("key_description"),
            history_data.c.issued_to,
            history_data.c.issued_at
        )
        .join(Key, Site.site_code == Key.site_code)
        .outerjoin(history_data, Key.key_id == history_data.c.key_id)
        .filter(Key.is_issued == 1)  # is_issued - це Integer, 1 означає видано
        .order_by(Site.site_code)
        .all()
    )
    
    return active_keys

