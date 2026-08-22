from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .routers import groups
from .routers import locations
from .routers import incidents
from .routers import safety


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


app.include_router(groups.router)
app.include_router(locations.router)
app.include_router(incidents.router)
app.include_router(safety.router)


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