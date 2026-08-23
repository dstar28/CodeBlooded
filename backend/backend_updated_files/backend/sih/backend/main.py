from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from database import init_db
from routers import groups
from routers import locations
from routers import incidents
from routers import safety
from routers import zones


app = FastAPI(
    title="SafeGuard API",
    version="1.0.0"
)

# Minimal local-dev CORS so the Flutter app (emulator, physical device,
# or Flutter web) and the admin dashboard can reach this backend. Not
# scoped further since the backend has no auth/session cookies for CORS
# to protect.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def on_startup():
    # Creates safeguard.db and all tables on first run. Safe to call
    # every startup — it only creates tables that don't already exist.
    init_db()


app.include_router(groups.router)
app.include_router(locations.router)
app.include_router(incidents.router)
app.include_router(safety.router)
app.include_router(zones.router)


@app.get("/")
def root():
    return {
        "service": "SafeGuard API",
        "status": "running"
    }


@app.get("/health")
def health():
    return {
        "status": "healthy"
    }
