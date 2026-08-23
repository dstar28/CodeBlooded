"""
Small, dependency-free geospatial helpers shared by the safety and zones
routers.

Deliberately NOT using Turf.js here — Turf is the JS/admin-layer tool per
the project's architecture. This is the Python-side equivalent used only
for the backend's own calculations (group proximity, point-in-geofence).
"""

import math


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle distance between two lat/lon points, in kilometers."""
    r = 6371.0088
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lon2 - lon1)

    a = (
        math.sin(d_phi / 2) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    )
    return 2 * r * math.asin(math.sqrt(a))


def _point_in_ring(lat: float, lon: float, ring: list) -> bool:
    """Ray-casting point-in-polygon test against a single GeoJSON ring.

    `ring` is a list of [lon, lat] pairs (GeoJSON coordinate order).
    """
    inside = False
    n = len(ring)
    j = n - 1
    for i in range(n):
        xi, yi = ring[i][0], ring[i][1]
        xj, yj = ring[j][0], ring[j][1]
        intersects = ((yi > lat) != (yj > lat)) and (
            lon < (xj - xi) * (lat - yi) / ((yj - yi) or 1e-15) + xi
        )
        if intersects:
            inside = not inside
        j = i
    return inside


def point_in_geometry(lat: float, lon: float, geometry: dict) -> bool:
    """
    True if (lat, lon) falls inside a GeoJSON Polygon or MultiPolygon.

    Supports holes: a point inside the outer ring but inside any
    subsequent (hole) ring is treated as outside.
    """
    geom_type = geometry.get("type")
    coordinates = geometry.get("coordinates", [])

    def polygon_contains(rings: list) -> bool:
        if not rings:
            return False
        if not _point_in_ring(lat, lon, rings[0]):
            return False
        for hole in rings[1:]:
            if _point_in_ring(lat, lon, hole):
                return False
        return True

    if geom_type == "Polygon":
        return polygon_contains(coordinates)

    if geom_type == "MultiPolygon":
        return any(polygon_contains(polygon) for polygon in coordinates)

    return False
