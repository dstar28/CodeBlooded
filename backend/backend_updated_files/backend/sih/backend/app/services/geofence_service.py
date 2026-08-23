import json


def point_in_polygon(
    latitude,
    longitude,
    polygon
):
    """
    Determines whether a GPS point is inside
    a polygon.

    polygon format:

    [
        [latitude, longitude],
        [latitude, longitude],
        ...
    ]
    """

    inside = False

    j = len(polygon) - 1

    for i in range(len(polygon)):

        lat_i = polygon[i][0]
        lon_i = polygon[i][1]

        lat_j = polygon[j][0]
        lon_j = polygon[j][1]

        intersects = (
            (lon_i > longitude)
            != (lon_j > longitude)
        ) and (
            latitude
            <
            (
                (lat_j - lat_i)
                *
                (longitude - lon_i)
                /
                (lon_j - lon_i)
                +
                lat_i
            )
        )

        if intersects:
            inside = not inside

        j = i

    return inside


def find_risk_zone(
    latitude,
    longitude,
    geofences
):
    """
    Returns the highest-risk active geofence
    containing the tourist.

    Returns None if the tourist is not inside
    any geofence.
    """

    matched_zone = None

    highest_risk = 0.0

    for geofence in geofences:

        try:
            polygon = json.loads(
                geofence.polygon
            )
        except Exception:
            continue

        inside = point_in_polygon(
            latitude,
            longitude,
            polygon
        )

        if inside:

            if (
                matched_zone is None
                or geofence.risk_level > highest_risk
            ):
                matched_zone = geofence
                highest_risk = (
                    geofence.risk_level
                )

    if matched_zone is None:
        return None

    return {
        "zone_id": matched_zone.id,
        "zone_name": matched_zone.name,
        "zone_risk": round(
            highest_risk,
            2
        )
    }