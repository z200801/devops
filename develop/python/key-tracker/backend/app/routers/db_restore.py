from fastapi import APIRouter, Depends, HTTPException, File, UploadFile
from sqlalchemy.orm import Session
from sqlalchemy import delete
from datetime import datetime
import yaml

from app.database import get_db
from app.models import Site, Key, History

router = APIRouter()

from fastapi import APIRouter, Depends, HTTPException, File, UploadFile
from sqlalchemy.orm import Session
from sqlalchemy import delete
from datetime import datetime
import yaml

from app.database import get_db
from app.models import Site, Key, History

router = APIRouter()

@router.post("/", status_code=200)
async def restore_data(file: UploadFile = File(...), db: Session = Depends(get_db)):
    """Відновлює дані з YAML-файлу"""
    try:
        # Зчитуємо вміст файлу
        contents = await file.read()
        
        # Парсимо YAML
        backup_data = yaml.safe_load(contents)
        
        # Перевіряємо структуру файлу
        if not all(key in backup_data for key in ["sites", "keys", "history"]):
            raise HTTPException(status_code=400, detail="Invalid backup file format")
        
        # Транзакція для всього процесу відновлення
        try:
            # Очищаємо поточні дані у зворотному порядку (спочатку залежні таблиці)
            db.execute(delete(History))
            db.execute(delete(Key))
            db.execute(delete(Site))
            db.commit()
        except Exception as clear_err:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Error clearing database: {str(clear_err)}")
            
        # Відновлюємо дані у правильному порядку з урахуванням залежностей
        try:
            # 1. Відновлюємо Sites
            site_code_map = {}  # Мапування для кодів сайтів
            for site_data in backup_data["sites"]:
                old_site_code = site_data["site_code"]
                # Створюємо новий об'єкт Site
                db_site = Site(
                    site_code=old_site_code,
                    address=site_data["address"],
                    memo=site_data["memo"]
                )
                db.add(db_site)
                site_code_map[old_site_code] = old_site_code  # Зберігаємо код сайту
            
            # Комітимо зміни, щоб застосувати вставки в таблицю sites
            db.commit()
            
            # 2. Відновлюємо Keys з використанням збережених site_code
            key_id_map = {}  # Мапування для ID ключів
            for key_data in backup_data["keys"]:
                old_key_id = key_data["key_id"]
                site_code = key_data["site_code"]
                
                # Перевіряємо чи існує site_code в мапуванні
                if site_code in site_code_map:
                    # Створюємо новий ключ
                    db_key = Key(
                        site_code=site_code,
                        description=key_data["description"],
                        key_count=key_data["key_count"],
                        set_count=key_data["set_count"],
                        is_issued=key_data["is_issued"],
                        memo=key_data["memo"]
                    )
                    db.add(db_key)
                    db.flush()  # Отримуємо ID для ключа
                    key_id_map[old_key_id] = db_key.key_id  # Зберігаємо маппінг ID
                else:
                    print(f"Warning: Site with code {site_code} not found for key {old_key_id}")
            
            # Комітимо зміни, щоб застосувати вставки в таблицю keys
            db.commit()
            
            # 3. Відновлюємо History з використанням нових ID ключів
            for history_data in backup_data["history"]:
                old_key_id = history_data["key_id"]
                
                # Перевіряємо чи існує ключ в маппінгу
                if old_key_id in key_id_map:
                    new_key_id = key_id_map[old_key_id]
                    
                    # Створюємо новий запис історії
                    db_history = History(
                        key_id=new_key_id,
                        issued_to=history_data["issued_to"],
                        issued_at=datetime.fromisoformat(history_data["issued_at"]) if history_data["issued_at"] else None,
                        returned_at=datetime.fromisoformat(history_data["returned_at"]) if history_data["returned_at"] else None,
                        memo=history_data["memo"]
                    )
                    db.add(db_history)
                else:
                    print(f"Warning: Key with old ID {old_key_id} not found in restored data")
            
            # Фінальний коміт для всіх змін
            db.commit()
            
        except Exception as restore_err:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Error during restore process: {str(restore_err)}")
            
        return {"message": "Data restored successfully"}
    
    except Exception as e:
        # Загальна обробка помилок
        if isinstance(e, HTTPException):
            raise e
        else:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Error restoring data: {str(e)}")

