from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime
from app.database import get_db
from app.models import Key, Site, History
from app.schemas import KeyResponse, KeyBase, HistoryResponse, KeyIssueRequest, KeyReturnRequest

router = APIRouter(prefix="/keys", tags=["Keys"])

@router.post("/", response_model=KeyResponse, status_code=201)
async def create_key(key: KeyBase, db: Session = Depends(get_db)):
    db_site = db.query(Site).filter(Site.site_code == key.site_code).first()
    if db_site is None:
        raise HTTPException(status_code=404, detail=f"Site '{key.site_code}' not found")
    db_key = Key(site_code=key.site_code, description=key.description, key_count=key.key_count, 
                set_count=key.set_count, memo=key.memo)
    db.add(db_key)
    db.commit()
    db.refresh(db_key)
    return db_key

@router.get("/", response_model=List[KeyResponse])
async def get_keys(site_code: Optional[str] = None, db: Session = Depends(get_db)):
    if site_code:
        keys = db.query(Key).filter(Key.site_code == site_code).order_by(Key.key_id).all()
    else:
        keys = db.query(Key).order_by(Key.site_code, Key.key_id).all()
    return keys

@router.get("/{key_id}", response_model=KeyResponse)
async def get_key(key_id: int, db: Session = Depends(get_db)):
    key = db.query(Key).filter(Key.key_id == key_id).first()
    if key is None:
        raise HTTPException(status_code=404, detail=f"Key with ID {key_id} not found")
    return key

@router.put("/{key_id}", response_model=KeyResponse)
async def update_key(key_id: int, key: KeyBase, db: Session = Depends(get_db)):
    db_key = db.query(Key).filter(Key.key_id == key_id).first()
    if db_key is None:
        raise HTTPException(status_code=404, detail=f"Key with ID {key_id} not found")
    db_site = db.query(Site).filter(Site.site_code == key.site_code).first()
    if db_site is None:
        raise HTTPException(status_code=404, detail=f"Site '{key.site_code}' not found")
    db_key.site_code = key.site_code
    db_key.description = key.description
    db_key.key_count = key.key_count
    db_key.set_count = key.set_count
    db_key.memo = key.memo
    db.commit()
    db.refresh(db_key)
    return db_key

@router.delete("/{key_id}", status_code=204)
async def delete_key(key_id: int, db: Session = Depends(get_db)):
    db_key = db.query(Key).filter(Key.key_id == key_id).first()
    if db_key is None:
        raise HTTPException(status_code=404, detail=f"Key with ID {key_id} not found")
    db.delete(db_key)
    db.commit()
    return None

# Ендпоінти для видачі та повернення ключів
@router.post("/issue/", response_model=HistoryResponse)
async def issue_key(key_issue: KeyIssueRequest, db: Session = Depends(get_db)):
    # Якщо дата не вказана, використовуємо поточну (вже як datetime об'єкт)
    if not key_issue.issued_at:
        key_issue.issued_at = datetime.utcnow()
    
    # Змінено умову з is_issued == False на is_issued == 0
    db_key = db.query(Key).filter(Key.site_code == key_issue.site_code, Key.is_issued == 0).first()
    if db_key is None:
        raise HTTPException(status_code=404, detail=f"No available keys for site '{key_issue.site_code}'")
    
    # Встановлюємо значення 1 замість True
    db_key.is_issued = 1
    db.commit()
    
    db_history = History(key_id=db_key.key_id, issued_to=key_issue.issued_to, issued_at=key_issue.issued_at)
    db.add(db_history)
    db.commit()
    db.refresh(db_history)
    return db_history

@router.post("/return/", response_model=HistoryResponse)
async def return_key(key_return: KeyReturnRequest, db: Session = Depends(get_db)):
    if not key_return.returned_at:
        key_return.returned_at = datetime.utcnow()
    
    # Знаходимо ключ, який потрібно повернути
    db_key = db.query(Key).filter(Key.site_code == key_return.site_code, Key.is_issued == 1).first()
    if db_key is None:
        raise HTTPException(status_code=404, detail=f"No issued keys found for site '{key_return.site_code}'")
    
    # Знаходимо останній запис історії для цього ключа без дати повернення
    db_history = db.query(History)\
                    .filter(History.key_id == db_key.key_id, History.returned_at == None)\
                    .order_by(History.issued_at.desc())\
                    .first()
    
    if db_history is None:
        # Якщо запис історії не знайдено, створюємо новий (нестандартна ситуація)
        db_history = History(key_id=db_key.key_id, returned_at=key_return.returned_at, memo=key_return.memo)
        db.add(db_history)
    else:
        # Оновлюємо існуючий запис
        db_history.returned_at = key_return.returned_at
        if key_return.memo:
            db_history.memo = key_return.memo
    
    # Змінюємо статус ключа на "не виданий"
    db_key.is_issued = 0
    db.commit()
    db.refresh(db_history)
    
    return db_history
