from sqlalchemy.orm import Session
from app.models import Site, Key, History
from app.schemas import SiteBase, KeyBase, HistoryBase
from sqlalchemy.exc import IntegrityError


def create_site(db: Session, site: SiteBase):
    db_site = Site(**site.dict())
    db.add(db_site)
    try:
        db.commit()
        db.refresh(db_site)
    except IntegrityError:
        db.rollback()
        return None
    return db_site


def get_sites(db: Session):
    return db.query(Site).all()


def get_site(db: Session, site_code: str):
    return db.query(Site).filter(Site.site_code == site_code).first()


def create_key(db: Session, key: KeyBase):
    db_key = Key(**key.dict())
    db.add(db_key)
    db.commit()
    db.refresh(db_key)
    return db_key


def get_keys(db: Session):
    return db.query(Key).all()
