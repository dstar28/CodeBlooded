"""
SQLAlchemy models for the SafeGuard FastAPI backend.

Tables:
- SafetyGroup / GroupMember: Group Safety Circle (pre-existing feature).
- UserLocation: latest known location per user (drives both the safety
  circle proximity status and the mobile geofence check).
- Incident: minimal incident record (the Flutter app's own Incidents
  screens use Supabase directly, not this backend — this table exists
  only so the /incidents router the app already imports has somewhere
  real to read/write).
- DangerZone: the geofence/danger-zone feature this prompt adds. Zones
  are always created as "proposed" and only become "active" through an
  explicit admin approval — never automatically.
"""

import uuid

from sqlalchemy import Boolean, Column, DateTime, Float, ForeignKey, String, Text
from sqlalchemy.sql import func

from database import Base


def _uuid() -> str:
    return str(uuid.uuid4())


class SafetyGroup(Base):
    __tablename__ = "safety_groups"

    id = Column(String, primary_key=True, default=_uuid)
    name = Column(String, nullable=False)
    invite_code = Column(String, unique=True, nullable=False, index=True)
    active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class GroupMember(Base):
    __tablename__ = "group_members"

    id = Column(String, primary_key=True, default=_uuid)
    group_id = Column(String, ForeignKey("safety_groups.id"), nullable=False, index=True)
    user_id = Column(String, nullable=False, index=True)
    name = Column(String, nullable=False)
    role = Column(String, nullable=False, default="member")
    share_location = Column(Boolean, nullable=False, default=True)
    emergency_location_share = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class UserLocation(Base):
    """Latest known position for a user. One row per user (upserted)."""

    __tablename__ = "user_locations"

    user_id = Column(String, primary_key=True)
    group_id = Column(String, nullable=True, index=True)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    accuracy = Column(Float, nullable=True)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class Incident(Base):
    __tablename__ = "incidents"

    id = Column(String, primary_key=True, default=_uuid)
    user_id = Column(String, nullable=False, index=True)
    incident_type = Column(String, nullable=False, default="other")
    description = Column(Text, nullable=False, default="")
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    status = Column(String, nullable=False, default="open")
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class DangerZone(Base):
    """
    A geofenced safety zone, stored as GeoJSON geometry.

    zone_type: "danger" | "warning" | "safe"
    status:    "proposed" | "active" | "rejected"
    source:    "admin"    | "ai"

    An AI-recommended zone is always inserted with status="proposed" and
    source="ai". Only an explicit admin approve action moves it to
    "active". This is enforced in the router, not just by convention.
    """

    __tablename__ = "danger_zones"

    id = Column(String, primary_key=True, default=_uuid)
    name = Column(String, nullable=False)
    zone_type = Column(String, nullable=False, default="danger")
    status = Column(String, nullable=False, default="proposed")
    source = Column(String, nullable=False, default="admin")
    # GeoJSON geometry (Polygon/MultiPolygon), stored as raw JSON text.
    geometry_json = Column(Text, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
