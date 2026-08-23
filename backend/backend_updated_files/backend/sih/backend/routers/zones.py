import json

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
from typing import Literal

from database import get_db
from geo_utils import point_in_geometry
from models import DangerZone

router = APIRouter(
    prefix="/zones",
    tags=["Zones"]
)

ZoneType = Literal["danger", "warning", "safe"]
ZoneSource = Literal["admin", "ai"]


class ZoneCreate(BaseModel):
    name: str
    zone_type: ZoneType = "danger"
    # A GeoJSON Polygon or MultiPolygon geometry object, e.g.
    # {"type": "Polygon", "coordinates": [[[lon, lat], ...]]}
    geometry: dict
    source: ZoneSource = "admin"


class ZoneGeometryUpdate(BaseModel):
    geometry: dict


def _to_feature(zone: DangerZone) -> dict:
    return {
        "type": "Feature",
        "id": zone.id,
        "properties": {
            "id": zone.id,
            "name": zone.name,
            "zone_type": zone.zone_type,
            "status": zone.status,
            "source": zone.source,
        },
        "geometry": json.loads(zone.geometry_json),
    }


def _feature_collection(zones: list[DangerZone]) -> dict:
    return {
        "type": "FeatureCollection",
        "features": [_to_feature(z) for z in zones],
    }


@router.get("/active")
def get_active_zones(db: Session = Depends(get_db)):
    """
    GeoJSON FeatureCollection of currently ACTIVE zones.

    This is what both the Flutter mobile map and the admin dashboard's
    base view load — the single source of truth for "what's live right
    now". Proposed/rejected zones are intentionally excluded.
    """
    zones = db.query(DangerZone).filter(DangerZone.status == "active").all()
    return _feature_collection(zones)


@router.get("/")
def list_zones(status: str | None = None, db: Session = Depends(get_db)):
    """
    All zones regardless of status, optionally filtered by
    ?status=proposed|active|rejected. Used by the admin dashboard to
    show the review queue alongside active zones.
    """
    query = db.query(DangerZone)
    if status:
        query = query.filter(DangerZone.status == status)
    return _feature_collection(query.all())


@router.post("/")
def propose_zone(body: ZoneCreate, db: Session = Depends(get_db)):
    """
    Create a new zone. Always created as status="proposed" — this is
    intentional and applies even when source="ai": an AI-recommended
    zone must go through explicit admin approval before it can ever
    affect a traveler's safety status. Nothing in this codepath sets
    status="active".
    """
    zone = DangerZone(
        name=body.name,
        zone_type=body.zone_type,
        source=body.source,
        status="proposed",
        geometry_json=json.dumps(body.geometry),
    )
    db.add(zone)
    db.commit()
    db.refresh(zone)
    return _to_feature(zone)


@router.put("/{zone_id}/geometry")
def update_zone_geometry(
    zone_id: str, body: ZoneGeometryUpdate, db: Session = Depends(get_db)
):
    """Admin edits a zone's geometry (e.g. adjusting a drawn polygon)."""
    zone = db.query(DangerZone).filter(DangerZone.id == zone_id).first()
    if not zone:
        raise HTTPException(status_code=404, detail="Zone not found")

    zone.geometry_json = json.dumps(body.geometry)
    db.commit()
    db.refresh(zone)
    return _to_feature(zone)


@router.post("/{zone_id}/approve")
def approve_zone(zone_id: str, db: Session = Depends(get_db)):
    """The only codepath that can move a zone to status='active'."""
    zone = db.query(DangerZone).filter(DangerZone.id == zone_id).first()
    if not zone:
        raise HTTPException(status_code=404, detail="Zone not found")

    zone.status = "active"
    db.commit()
    db.refresh(zone)
    return _to_feature(zone)


@router.post("/{zone_id}/reject")
def reject_zone(zone_id: str, db: Session = Depends(get_db)):
    zone = db.query(DangerZone).filter(DangerZone.id == zone_id).first()
    if not zone:
        raise HTTPException(status_code=404, detail="Zone not found")

    zone.status = "rejected"
    db.commit()
    db.refresh(zone)
    return _to_feature(zone)


@router.delete("/{zone_id}")
def delete_zone(zone_id: str, db: Session = Depends(get_db)):
    zone = db.query(DangerZone).filter(DangerZone.id == zone_id).first()
    if not zone:
        raise HTTPException(status_code=404, detail="Zone not found")

    db.delete(zone)
    db.commit()
    return {"deleted": True, "zone_id": zone_id}


@router.get("/check")
def check_point(lat: float, lng: float, db: Session = Depends(get_db)):
    """
    Point-in-geofence check for a single coordinate, used by the
    mobile app to translate the traveler's real GPS position into a
    plain-language safety status.

    Only ACTIVE zones are considered. If the point falls in more than
    one zone, the most severe (danger > warning > safe) wins.
    """
    severity = {"danger": 2, "warning": 1, "safe": 0}
    zones = db.query(DangerZone).filter(DangerZone.status == "active").all()

    matched = None
    for zone in zones:
        geometry = json.loads(zone.geometry_json)
        if point_in_geometry(lat, lng, geometry):
            if matched is None or severity[zone.zone_type] > severity[matched.zone_type]:
                matched = zone

    if matched is None:
        return {"status": "safe", "zone": None}

    return {
        "status": matched.zone_type,
        "zone": _to_feature(matched),
    }
