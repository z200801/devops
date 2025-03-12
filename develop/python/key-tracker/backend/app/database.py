from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from app.config import settings

# Створення рядка підключення до бази даних
DATABASE_URL = f"{settings.db_type}://{settings.db_user}:{settings.db_password}@{settings.db_host}:{settings.db_port}/{settings.db_name}"

# Створення engine з параметрами пулу з'єднань
engine = create_engine(DATABASE_URL, pool_size=10, max_overflow=20)

# Створення сесії
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Базовий клас для ORM моделей
Base = declarative_base()

# Функція-залежність для отримання сесії в ендпоінтах
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Функція для ініціалізації бази даних (створення таблиць)
def init_db():
    Base.metadata.create_all(bind=engine)

