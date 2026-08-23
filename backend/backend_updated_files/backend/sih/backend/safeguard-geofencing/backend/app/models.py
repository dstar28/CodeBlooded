"""
SQLAlchemy ORM models for the SafeGuard FastAPI backend.

Scaffolded fresh (see database.py header) to match what groups.py and the
Flutter SafeguardApiClient already assume exists:
  - SafetyGroup / GroupMember  -> used by routers/groups.py (unchanged
    logic from the uploaded groups.py)
  - Location                   -> used by routers/locations.py, matches
    the {latitude, longitude, timestamp} payload the Flutter app sends
  - Incident                   -> minimal placeholder so main.py's
    existing `from .routers import incidents` import keeps working;
    NOT part of the geofencing feature, kept intentionally small
  - GeofenceZone                -> NEW, for this feature (danger/safety
    zones, AI-proposed vs. admin-approved)
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    String,
    Text,
)
from sqlalchemy.orm import relationship

from .database import Base


def _uuid() -> str:
    return str(uuid.uuid4())


def _now() -> datetime:
    return datetime.now(timezone.utc)


class SafetyGroup(Base):
    __tablename__ = "safety_groups"

    id = Column(String, primary_key=True, default=_uuid)
    name = Column(String, nullable=False)
    invite_code = Column(String, unique=True, nullable=False, index=True)
    active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), default=_now)

    members = relationship(
        "GroupMember", back_populates="group", cascade="all, delete-orphan"
    )


class GroupMember(Base):
    __tablename__ = "group_members"

    id = Column(String, primary_key=True, default=_uuid)
    group_id = Column(String, ForeignKey("safety_groups.id"), nullable=False)
    user_id = Column(String, nullable=False, index=True)
    name = Column(String, nullable=False)
    role = Column(String, default="member", nullable=False)  # "owner" | "member"
    share_location = Column(Boolean, default=True)
    emergency_location_share = Column(Boolean, default=True)

    group = relationship("SafetyGroup", back_populates="members")


class Location(Base):
    """Most-recent-location-per-user ping, used for the geofence check
    and for the group's live safety status."""

    __tablename__ = "locations"

    id = Column(String, primary_key=True, default=_uuid)
    user_id = Column(String, nullable=False, index=True)
    group_id = Column(String, ForeignKey("safety_groups.id"), nullable=True)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    accuracy = Column(Float, nullable=True)
    timestamp = Column(DateTime(timezone=True), default=_now)


class Incident(Base):
    """Minimal placeholder — incidents are largely handled via the
    Supabase repositories already in the Flutter app
    (lib/services/supabase/incident_repository.dart). This exists only
    so the pre-existing `from .routers import incidents` import in
    main.py resolves; it is intentionally out of scope for the
    geofencing feature and not built out further here."""

    __tablename__ = "incidents"

    id = Column(String, primary_key=True, default=_uuid)
    user_id = Column(String, nullable=False, index=True)
    description = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), default=_now)


class GeofenceZone(Base):
    """A safety/danger zone. Stored as GeoJSON geometry (Polygon or a
    circle expressed as {center, radius_m}) so the same shape can flow
    unchanged between Leaflet <-> Turf.js <-> this table <-> the mobile
    app's geofence-check response.

    active=False + approved=False  -> AI-proposed, awaiting admin review
    active=False + approved=True   -> admin approved but toggled off
    active=True  + approved=True   -> live danger/safety zone
    A zone can never become active=True without approved=True — enforced
    in routers/geofences.py, not just here.
    """

    __tablename__ = "geofence_zones"

    id = Column(String, primary_key=True, default=_uuid)
    name = Column(String, nullable=False)
    risk_level = Column(String, default="danger", nullable=False)  # "warning" | "danger"

    # GeoJSON Polygon coordinates OR a circle {center: [lon, lat], radius_m}
    geometry_type = Column(String, nullable=False)  # "Polygon" | "Circle"
    geometry_json = Column(Text, nullable=False)  # raw GeoJSON geometry, as text

    source = Column(String, default="admin", nullable=False)  # "admin" | "ai"
    approved = Column(Boolean, default=False, nullable=False)
    active = Column(Boolean, default=False, nullable=False)

    created_by = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), default=_now)
    approved_by = Column(String, nullable=True)
    approved_at = Column(DateTime(timezone=True), nullable=True)
