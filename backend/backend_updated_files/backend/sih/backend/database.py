"""
Database setup for the SafeGuard FastAPI backend.

Uses a local SQLite file (safeguard.db) so the backend runs out of the
box with zero external services. Swap SQLALCHEMY_DATABASE_URL for a
Postgres/MySQL URL later without touching any router code.
"""

from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

SQLALCHEMY_DATABASE_URL = "sqlite:///./safeguard.db"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    # Needed only for SQLite: allows the connection to be used across
    # the different threads FastAPI's test/dev server may use.
    connect_args={"check_same_thread": False},
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db():
    """FastAPI dependency that yields a DB session and always closes it."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    """Create all tables that don't exist yet. Called once on startup."""
    # Import models here (not at module load time) so every model class
    # is registered on Base.metadata before create_all runs.
    import models  # noqa: F401

    Base.metadata.create_all(bind=engine)
