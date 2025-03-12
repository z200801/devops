from pydantic import BaseModel, ConfigDict
from datetime import datetime
from typing import Optional

# --- Схеми для об'єктів Site ---
class SiteBase(BaseModel):
    site_code: str
    address: str
    memo: Optional[str] = None

class SiteResponse(SiteBase):
    site_id: int
    
    model_config = ConfigDict(from_attributes=True)

# --- Схеми для об'єктів Key ---
class KeyBase(BaseModel):
    site_code: str
    description: str
    key_count: int
    set_count: int
    memo: Optional[str] = None

class KeyResponse(KeyBase):
    key_id: int
    is_issued: bool
    
    model_config = ConfigDict(from_attributes=True)
    
    # Додаємо метод для перетворення is_issued з Integer в bool
    @classmethod
    def model_validate(cls, obj, *args, **kwargs):
        # Якщо це словник
        if isinstance(obj, dict) and 'is_issued' in obj:
            obj['is_issued'] = bool(obj['is_issued'])
        # Якщо це ORM модель
        elif hasattr(obj, 'is_issued'):
            # Створюємо копію об'єкта як словник
            obj_dict = {key: getattr(obj, key) for key in dir(obj) 
                       if not key.startswith('_') and key != 'metadata'}
            # Перетворюємо is_issued
            obj_dict['is_issued'] = bool(obj.is_issued)
            obj = obj_dict
        return super().model_validate(obj, *args, **kwargs)

# --- Схеми для історії видачі ключів ---
class HistoryBase(BaseModel):
    key_id: int
    issued_to: Optional[str] = None
    issued_at: Optional[datetime] = None  # тип datetime
    returned_at: Optional[datetime] = None  # тип datetime
    memo: Optional[str] = None
    
    model_config = ConfigDict(from_attributes=True)

class HistoryResponse(HistoryBase):
    history_id: int

class HistoryUpdateRequest(BaseModel):
    issued_to: Optional[str] = None
    issued_at: Optional[datetime] = None  # тип datetime
    returned_at: Optional[datetime] = None  # тип datetime
    memo: Optional[str] = None

# --- Схеми для запитів на видачу/повернення ключів ---
class KeyIssueRequest(BaseModel):
    site_code: str
    issued_to: str
    issued_at: Optional[datetime] = None  # тип datetime

class KeyReturnRequest(BaseModel):
    site_code: str
    returned_at: Optional[datetime] = None  # тип datetime
    memo: Optional[str] = None

# --- Схема для активних виданих ключів ---
class ActiveIssuedKeyResponse(BaseModel):
    site_code: str
    key_description: str
    issued_to: str
    issued_at: datetime  # тип datetime
    
    model_config = ConfigDict(from_attributes=True)

