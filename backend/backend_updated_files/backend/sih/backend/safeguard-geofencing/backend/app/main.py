from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .database import init_db
from .routers import groups
from .routers import locations
from .routers import incidents
from .routers import safety
from .routers import geofences


app = FastAPI(
    title="SafeGuard API",
    version="1.0.0"
)

# Minimal local-dev CORS so the Flutter app (emulator, physical device,
# or Flutter web) can reach this backend. Not scoped further since the
# backend has no auth/session cookies for CORS to protect.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def _startup() -> None:
    init_db()


app.include_router(groups.router)
app.include_router(locations.router)
app.include_router(incidents.router)
app.include_router(safety.router)
app.include_router(geofences.router)

# Admin dashboard (Leaflet + Turf.js, static HTML/JS — no separate
# frontend framework/build step). Served at /admin/.
_STATIC_DIR = Path(__file__).resolve().parent.parent / "static"
app.mount("/admin", StaticFiles(directory=_STATIC_DIR / "admin", html=True), name="admin")


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
