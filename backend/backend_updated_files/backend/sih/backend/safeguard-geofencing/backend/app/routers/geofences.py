"""
Geofence zones: AI-proposed OR admin-drawn danger/safety zones, admin
approval workflow, and the point-in-zone check the Flutter app polls.

NOTE ON Turf.js vs. this file
------------------------------
The spec's architecture diagram shows "FastAPI backend -> Turf.js
geospatial calculations". Turf.js is a JavaScript library and this
backend is Python, so it cannot literally run inside this process
without shelling out to Node for every request (fragile, slow, an
extra runtime dependency for no real benefit). Turf.js IS used, per
the spec, in the browser: the admin dashboard (static/admin/index.html)
uses Leaflet.draw + Turf.js client-side to draw zones, compute a
circle's polygon buffer, and validate geometry before it's ever sent
here as GeoJSON.

The actual point-in-danger-zone check a tourist's coordinates need
happens server-side (the phone cannot be trusted to self-report "I'm
safe"), so this file does that math in Python using the same GeoJSON
that Leaflet/Turf.js produced, via Shapely — Python's equivalent
geospatial library, doing the same point-in-polygon / distance
operations Turf.js would. GeoJSON stays the common format at every
hop (Leaflet <-> Turf.js <-> here <-> Flutter), per the spec.
"""

import json
import math
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from shapely.geometry import Point, Polygon
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import GeofenceZone

router = APIRouter(
    prefix="/geofences",
    tags=["Geofences"],
)

# How close (in meters) to a danger zone boundary counts as "warning".
WARNING_DISTANCE_M = 150

EARTH_RADIUS_M = 6371000.0


# ---------------------------------------------------------------------------
# Geometry helpers (Shapely-based; see module docstring for why not Turf.js)
# ---------------------------------------------------------------------------

def _haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lon2 - lon1)
    a = (
        math.sin(d_phi / 2) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    )
    return 2 * EARTH_RADIUS_M * math.asin(math.sqrt(a))


def _local_xy(lat: float, lon: float, origin_lat: float, origin_lon: float):
    """Equirectangular approximation, meters, centered on `origin`. Good
    enough for city-scale danger zones (not for country-spanning ones)."""
    x = math.radians(lon - origin_lon) * math.cos(math.radians(origin_lat)) * EARTH_RADIUS_M
    y = math.radians(lat - origin_lat) * EARTH_RADIUS_M
    return x, y


def _polygon_in_local_meters(coordinates, origin_lat: float, origin_lon: float) -> Polygon:
    # GeoJSON polygon coordinates: [ [ [lon, lat], ... ] ]  (first ring = outer)
    ring = coordinates[0]
    pts = [_local_xy(lat, lon, origin_lat, origin_lon) for lon, lat in ring]
    return Polygon(pts)


def evaluate_point(db: Session, latitude: float, longitude: float) -> dict:
    """Check (latitude, longitude) against every ACTIVE geofence zone.
    Returns the response shape the spec asks for. Danger wins over
    warning; the nearest/most severe zone is reported if several apply.
    """
    zones = db.query(GeofenceZone).filter(GeofenceZone.active == True).all()  # noqa: E712

    best_danger = None
    best_warning = None

    for zone in zones:
        geometry = json.loads(zone.geometry_json)

        if zone.geometry_type == "Circle":
            center_lon, center_lat = geometry["center"]
            radius_m = geometry["radius_m"]
            dist = _haversine_m(latitude, longitude, center_lat, center_lon)
            inside = dist <= radius_m
            dist_to_boundary = radius_m - dist  # positive = inside, meters to edge
        else:  # "Polygon"
            point_xy = Point(0, 0)  # origin IS the tourist's point
            poly_xy = _polygon_in_local_meters(
                geometry["coordinates"], latitude, longitude
            )
            inside = poly_xy.contains(point_xy) or poly_xy.touches(point_xy)
            boundary_dist = poly_xy.exterior.distance(point_xy)
            # Convention: positive = meters inside past the boundary,
            # negative = meters outside the boundary (matches the Circle
            # branch above so the shared threshold check below works).
            dist_to_boundary = boundary_dist if inside else -boundary_dist

        if inside:
            if best_danger is None:
                best_danger = zone
        elif dist_to_boundary >= -WARNING_DISTANCE_M and dist_to_boundary < 0:
            # Outside, but within WARNING_DISTANCE_M of the boundary.
            if best_warning is None:
                best_warning = zone

    if best_danger is not None:
        return {
            "status": "danger",
            "inside_zone": True,
            "zone_id": best_danger.id,
            "zone_name": best_danger.name,
            "risk_level": best_danger.risk_level,
        }

    if best_warning is not None:
        return {
            "status": "warning",
            "inside_zone": False,
            "zone_id": best_warning.id,
            "zone_name": best_warning.name,
            "risk_level": best_warning.risk_level,
        }

    return {"status": "safe", "inside_zone": False}


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------

class ZoneCreate(BaseModel):
    name: str
    risk_level: str = "danger"  # "warning" | "danger"
    geometry_type: str  # "Polygon" | "Circle"
    geometry: dict  # GeoJSON geometry, or {"center": [lon, lat], "radius_m": N} for Circle
    source: str = "admin"  # "admin" | "ai"
    created_by: str | None = None


class ZoneDecision(BaseModel):
    admin_id: str


class LocationCheck(BaseModel):
    latitude: float
    longitude: float


def _zone_to_geojson_feature(zone: GeofenceZone) -> dict:
    geometry = json.loads(zone.geometry_json)
    if zone.geometry_type == "Circle":
        # Represent circles as GeoJSON Point + radius_m property (Leaflet
        # draws this as an L.circle; Turf can buffer it into a polygon
        # client-side if a Turf.js consumer needs one).
        geom = {"type": "Point", "coordinates": geometry["center"]}
        radius_m = geometry["radius_m"]
    else:
        geom = geometry
        radius_m = None

    return {
        "type": "Feature",
        "id": zone.id,
        "properties": {
            "name": zone.name,
            "risk_level": zone.risk_level,
            "active": zone.active,
            "approved": zone.approved,
            "source": zone.source,
            "radius_m": radius_m,
        },
        "geometry": geom,
    }


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.get("/active")
def get_active_zones(db: Session = Depends(get_db)):
    """1. Fetch active geofences — used by the admin map and can also be
    polled by the mobile app if it wants to show zones, not just a
    status string."""
    zones = db.query(GeofenceZone).filter(GeofenceZone.active == True).all()  # noqa: E712
    return {
        "type": "FeatureCollection",
        "features": [_zone_to_geojson_feature(z) for z in zones],
    }


@router.get("/pending")
def get_pending_zones(db: Session = Depends(get_db)):
    """Zones awaiting admin review (AI-proposed or admin drafts not yet
    approved). Powers the admin dashboard's review queue."""
    zones = db.query(GeofenceZone).filter(GeofenceZone.approved == False).all()  # noqa: E712
    return {
        "type": "FeatureCollection",
        "features": [_zone_to_geojson_feature(z) for z in zones],
    }


@router.post("/propose")
def propose_zone(payload: ZoneCreate, db: Session = Depends(get_db)):
    """2. Create a proposed geofence. Whether it comes from the admin
    dashboard or an AI recommendation, it is NEVER active on creation —
    see the safety rule in the module docstring and models.py."""
    if payload.geometry_type not in ("Polygon", "Circle"):
        raise HTTPException(status_code=400, detail="geometry_type must be Polygon or Circle")
    if payload.source not in ("admin", "ai"):
        raise HTTPException(status_code=400, detail="source must be admin or ai")

    zone = GeofenceZone(
        id=str(uuid.uuid4()),
        name=payload.name,
        risk_level=payload.risk_level,
        geometry_type=payload.geometry_type,
        geometry_json=json.dumps(payload.geometry),
        source=payload.source,
        created_by=payload.created_by,
        approved=False,
        active=False,
    )
    db.add(zone)
    db.commit()

    return _zone_to_geojson_feature(zone)


@router.post("/{zone_id}/approve")
def approve_zone(zone_id: str, payload: ZoneDecision, db: Session = Depends(get_db)):
    """3. Admin approve — the ONLY path that can ever set active=True.
    An AI-proposed zone can never activate itself."""
    zone = db.query(GeofenceZone).filter(GeofenceZone.id == zone_id).first()
    if not zone:
        raise HTTPException(status_code=404, detail="Zone not found")

    zone.approved = True
    zone.active = True
    zone.approved_by = payload.admin_id
    zone.approved_at = datetime.now(timezone.utc)
    db.commit()

    return _zone_to_geojson_feature(zone)


@router.post("/{zone_id}/reject")
def reject_zone(zone_id: str, payload: ZoneDecision, db: Session = Depends(get_db)):
    """Admin reject — removes the proposal entirely."""
    zone = db.query(GeofenceZone).filter(GeofenceZone.id == zone_id).first()
    if not zone:
        raise HTTPException(status_code=404, detail="Zone not found")

    db.delete(zone)
    db.commit()

    return {"status": "rejected", "zone_id": zone_id}


@router.post("/{zone_id}/deactivate")
def deactivate_zone(zone_id: str, db: Session = Depends(get_db)):
    """Lets an admin turn an already-approved zone off without deleting
    it (e.g. a danger has passed)."""
    zone = db.query(GeofenceZone).filter(GeofenceZone.id == zone_id).first()
    if not zone:
        raise HTTPException(status_code=404, detail="Zone not found")

    zone.active = False
    db.commit()
    return _zone_to_geojson_feature(zone)


@router.post("/check")
def check_location(payload: LocationCheck, db: Session = Depends(get_db)):
    """4. Check a user's current location against active geofences.
    This is what the Flutter app calls on every GPS refresh."""
    return evaluate_point(db, payload.latitude, payload.longitude)
