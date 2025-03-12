from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import delete

from app.database import get_db
from app.models import Site, Key, History

router = APIRouter()

@router.delete("/", status_code=200)
async def clear_database(db: Session = Depends(get_db)):
    """Повністю очищає базу даних"""
    try:
        # Видаляємо всі записи з таблиць
        db.execute(delete(History))
        db.execute(delete(Key))
        db.execute(delete(Site))
        db.commit()
        
        return {"message": "Database cleared successfully"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error clearing database: {str(e)}")
