import json

from .location_service import distance_km


def distance_point_to_segment_km(
    point_lat,
    point_lon,
    start_lat,
    start_lon,
    end_lat,
    end_lon
):
    """
    Approximate minimum distance between a GPS point
    and a route segment.

    For hackathon-scale geographic areas, this
    equirectangular approximation is sufficient.
    """

    lat_scale = 111.0

    avg_lat = (
        point_lat
        + start_lat
        + end_lat
    ) / 3

    lon_scale = (
        111.0
        * __import__("math").cos(
            __import__("math").radians(
                avg_lat
            )
        )
    )

    px = point_lon * lon_scale
    py = point_lat * lat_scale

    ax = start_lon * lon_scale
    ay = start_lat * lat_scale

    bx = end_lon * lon_scale
    by = end_lat * lat_scale

    dx = bx - ax
    dy = by - ay

    if dx == 0 and dy == 0:
        return distance_km(
            point_lat,
            point_lon,
            start_lat,
            start_lon
        )

    t = (
        (px - ax) * dx
        + (py - ay) * dy
    ) / (
        dx * dx + dy * dy
    )

    t = max(
        0,
        min(1, t)
    )

    closest_x = ax + t * dx
    closest_y = ay + t * dy

    closest_lat = (
        closest_y / lat_scale
    )

    closest_lon = (
        closest_x / lon_scale
    )

    return distance_km(
        point_lat,
        point_lon,
        closest_lat,
        closest_lon
    )


def calculate_route_deviation_km(
    latitude,
    longitude,
    route
):
    """
    Calculates the shortest distance from the
    tourist's current GPS position to the
    expected route.
    """

    if not route:
        return 0.0

    if len(route) == 1:
        return distance_km(
            latitude,
            longitude,
            route[0][0],
            route[0][1]
        )

    minimum_distance = float("inf")

    for index in range(
        len(route) - 1
    ):

        start = route[index]
        end = route[index + 1]

        distance = distance_point_to_segment_km(
            latitude,
            longitude,
            start[0],
            start[1],
            end[0],
            end[1]
        )

        minimum_distance = min(
            minimum_distance,
            distance
        )

    return round(
        minimum_distance,
        2
    )


def find_route_deviation(
    latitude,
    longitude,
    routes
):
    """
    Finds the active route with the smallest
    deviation from the tourist's current position.
    """

    best_route = None
    best_distance = float("inf")

    for safety_route in routes:

        try:
            route = json.loads(
                safety_route.path
            )
        except Exception:
            continue

        deviation = calculate_route_deviation_km(
            latitude,
            longitude,
            route
        )

        if deviation < best_distance:
            best_distance = deviation
            best_route = safety_route

    if best_route is None:
        return None

    return {
        "route_id": best_route.id,
        "route_name": best_route.name,
        "deviation_km": best_distance
    }