from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app.models import Site
from app.schemas import SiteResponse, SiteBase

router = APIRouter(prefix="/sites", tags=["Sites"])

@router.post("/", response_model=SiteResponse, status_code=201)
async def create_site(site: SiteBase, db: Session = Depends(get_db)):
    db_site = Site(site_code=site.site_code, address=site.address, memo=site.memo)
    db.add(db_site)
    db.commit()
    db.refresh(db_site)
    return db_site

@router.get("/", response_model=List[SiteResponse])
async def get_sites(db: Session = Depends(get_db)):
    sites = db.query(Site).order_by(Site.site_code).all()
    return sites

@router.get("/{site_code}", response_model=SiteResponse)
async def get_site(site_code: str, db: Session = Depends(get_db)):
    site = db.query(Site).filter(Site.site_code == site_code).first()
    if site is None:
        raise HTTPException(status_code=404, detail=f"Site '{site_code}' not found")
    return site

@router.put("/{site_code}", response_model=SiteResponse)
async def update_site(site_code: str, site: SiteBase, db: Session = Depends(get_db)):
    db_site = db.query(Site).filter(Site.site_code == site_code).first()
    if db_site is None:
        raise HTTPException(status_code=404, detail=f"Site '{site_code}' not found")
    db_site.address = site.address
    db_site.memo = site.memo
    db.commit()
    db.refresh(db_site)
    return db_site

@router.delete("/{site_code}", status_code=204)
async def delete_site(site_code: str, db: Session = Depends(get_db)):
    db_site = db.query(Site).filter(Site.site_code == site_code).first()
    if db_site is None:
        raise HTTPException(status_code=404, detail=f"Site '{site_code}' not found")
    db.delete(db_site)
    db.commit()
    return None

