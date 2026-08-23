"""
Single SQLAlchemy engine/session/Base for the SafeGuard FastAPI backend.

This file did not exist in the uploaded bundle (only main.py and a loose
groups.py were present), so it has been scaffolded fresh per the "scaffold
missing backend files" instruction. If you already have a real
database.py elsewhere, replace this one and keep the same `get_db` /
`Base` names so the routers below don't need to change.

SQLite is used as the default so the backend runs with zero extra setup.
Swap DATABASE_URL for Postgres/etc. in production — SQLAlchemy's ORM
layer (used throughout models.py) works unchanged either way.
"""

import os

from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

DATABASE_URL = os.environ.get("SAFEGUARD_DATABASE_URL", "sqlite:///./safeguard.db")

_connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}

engine = create_engine(DATABASE_URL, connect_args=_connect_args)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db():
    """FastAPI dependency: yields a DB session and always closes it."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db() -> None:
    """Create all tables. Call once at startup (see main.py)."""
    # Importing here (not at module top) avoids a circular import between
    # database.py and models.py.
    from . import models  # noqa: F401

    Base.metadata.create_all(bind=engine)
