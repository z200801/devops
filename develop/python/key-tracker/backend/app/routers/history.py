from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from app.database import get_db
from app.models import History, Key
from app.schemas import HistoryResponse, HistoryUpdateRequest

router = APIRouter(prefix="/history", tags=["History"])

@router.get("/", response_model=List[HistoryResponse])
async def get_history(site_code: Optional[str] = None, db: Session = Depends(get_db)):
    if site_code:
        history = db.query(History).join(Key, History.key_id == Key.key_id)\
                  .filter(Key.site_code == site_code).order_by(History.issued_at.desc()).all()
    else:
        history = db.query(History).order_by(History.issued_at.desc()).all()
    return history

@router.put("/{history_id}", response_model=HistoryResponse)
async def update_history(history_id: int, history_update: HistoryUpdateRequest, db: Session = Depends(get_db)):
    db_history = db.query(History).filter(History.history_id == history_id).first()
    if db_history is None:
        raise HTTPException(status_code=404, detail=f"History entry with ID {history_id} not found")
    for field, value in history_update.dict(exclude_unset=True).items():
        setattr(db_history, field, value)
    db.commit()
    db.refresh(db_history)
    return db_history

@router.delete("/{history_id}", status_code=204)
async def delete_history_entry(history_id: int, db: Session = Depends(get_db)):
    db_history = db.query(History).filter(History.history_id == history_id).first()
    if db_history is None:
        raise HTTPException(status_code=404, detail=f"History entry with ID {history_id} not found")
    db.delete(db_history)
    db.commit()
    return None

