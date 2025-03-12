from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
import yaml
import tempfile
import os

from app.database import get_db
from app.models import Site, Key, History

router = APIRouter()

@router.get("/", response_class=FileResponse)
async def backup_data(db: Session = Depends(get_db)):
    """Створює резервну копію даних у форматі YAML"""
    try:
        # Отримуємо всі дані з бази
        sites = db.query(Site).all()
        keys = db.query(Key).all()
        history = db.query(History).all()
        
        # Перетворюємо об'єкти SQLAlchemy в словники
        sites_data = [
            {
                "site_id": site.site_id,
                "site_code": site.site_code,
                "address": site.address,
                "memo": site.memo
            } for site in sites
        ]
        
        keys_data = [
            {
                "key_id": key.key_id,
                "site_code": key.site_code,
                "description": key.description,
                "key_count": key.key_count,
                "set_count": key.set_count,
                "is_issued": key.is_issued,
                "memo": key.memo
            } for key in keys
        ]
        
        history_data = [
            {
                "history_id": h.history_id,
                "key_id": h.key_id,
                "issued_to": h.issued_to,
                "issued_at": h.issued_at.isoformat() if h.issued_at else None,
                "returned_at": h.returned_at.isoformat() if h.returned_at else None,
                "memo": h.memo
            } for h in history
        ]
        
        # Створюємо структуру даних для YAML
        backup_data = {
            "sites": sites_data,
            "keys": keys_data,
            "history": history_data
        }
        
        # Створюємо тимчасовий файл для зберігання YAML
        fd, path = tempfile.mkstemp(suffix='.yaml')
        
        try:
            with os.fdopen(fd, 'w') as tmp:
                yaml.dump(backup_data, tmp, sort_keys=False, default_flow_style=False)
                
            # Повертаємо файл для завантаження
            return FileResponse(
                path=path, 
                filename="key_tracker_backup.yaml", 
                media_type="application/x-yaml"
            )
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Error creating backup: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error processing backup: {str(e)}")
