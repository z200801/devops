from sqlalchemy import Column, Integer, String, Text, ForeignKey, TIMESTAMP, Boolean
from datetime import datetime
from app.database import Base

class Site(Base):
    __tablename__ = 'sites'
    site_id = Column(Integer, primary_key=True, autoincrement=True)
    site_code = Column(String, unique=True, nullable=False)
    address = Column(Text, nullable=False)
    memo = Column(Text)

class Key(Base):
    __tablename__ = 'keys'
    key_id = Column(Integer, primary_key=True, autoincrement=True)
    site_code = Column(String, ForeignKey('sites.site_code'), nullable=False)
    description = Column(Text, nullable=False)
    key_count = Column(Integer, nullable=False)
    set_count = Column(Integer, nullable=False)
    is_issued = Column(Integer, default=0)  # Використовуємо Integer замість Boolean
    memo = Column(Text)

class History(Base):
    __tablename__ = 'history'
    history_id = Column(Integer, primary_key=True, autoincrement=True)
    key_id = Column(Integer, ForeignKey('keys.key_id'), nullable=False)
    issued_to = Column(String)
    issued_at = Column(TIMESTAMP, default=datetime.utcnow)
    returned_at = Column(TIMESTAMP)
    memo = Column(Text)

