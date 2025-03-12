from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.database import init_db
from app.routers import sites, keys, history, active_keys
from app.routers import db_backup, db_restore, db_clear

app = FastAPI(title="Key Tracker API", version="1.0.0")

# Додавання CORS middleware для доступу з фронтенду
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Ініціалізація бази даних при старті
@app.on_event("startup")
async def startup_event():
    init_db()

# Підключення роутерів
app.include_router(sites.router)
app.include_router(keys.router)
app.include_router(history.router)
app.include_router(active_keys.router)
app.include_router(db_backup.router, prefix="/backup", tags=["backup"])
app.include_router(db_restore.router, prefix="/backup/restore", tags=["backup"])
app.include_router(db_clear.router, prefix="/backup/clear", tags=["backup"])

@app.get("/")
async def root():
    return {"message": "Welcome to Key Tracker API"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

