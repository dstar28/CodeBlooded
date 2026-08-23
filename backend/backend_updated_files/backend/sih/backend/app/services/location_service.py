from datetime import timezone
from math import radians, sin, cos, sqrt, atan2


def distance_km(
    lat1,
    lon1,
    lat2,
    lon2
):

    earth_radius = 6371

    d_lat = radians(lat2 - lat1)
    d_lon = radians(lon2 - lon1)

    a = (
        sin(d_lat / 2) ** 2
        +
        cos(radians(lat1))
        * cos(radians(lat2))
        * sin(d_lon / 2) ** 2
    )

    c = 2 * atan2(
        sqrt(a),
        sqrt(1 - a)
    )

    return earth_radius * c


def calculate_group_distances(locations):

    results = []

    for current in locations:

        max_distance = 0

        for other in locations:

            if current.user_id == other.user_id:
                continue

            distance = distance_km(
                current.latitude,
                current.longitude,
                other.latitude,
                other.longitude
            )

            max_distance = max(
                max_distance,
                distance
            )

        results.append({
            "user_id": current.user_id,
            "max_distance_km": round(
                max_distance,
                2
            )
        })

    return results


def calculate_speed_kmh(
    previous_location,
    current_location
):

    if previous_location is None:
        return 0.0

    distance = distance_km(
        previous_location.latitude,
        previous_location.longitude,
        current_location.latitude,
        current_location.longitude
    )

    previous_time = previous_location.timestamp
    current_time = current_location.timestamp

    if previous_time.tzinfo is None:
        previous_time = previous_time.replace(
            tzinfo=timezone.utc
        )

    if current_time.tzinfo is None:
        current_time = current_time.replace(
            tzinfo=timezone.utc
        )

    elapsed_seconds = (
        current_time - previous_time
    ).total_seconds()

    if elapsed_seconds <= 0:
        return 0.0

    elapsed_hours = (
        elapsed_seconds / 3600
    )

    speed = distance / elapsed_hours

    return round(
        speed,
        2
    )


def calculate_inactivity_minutes(
    locations,
    stationary_radius_km=0.05
):
    """
    Calculates the current continuous inactivity
    period from recent GPS history.

    50 meters or less between consecutive points
    is considered stationary.
    """

    if not locations:
        return 0.0

    if len(locations) < 2:
        return 0.0

    ordered_locations = sorted(
        locations,
        key=lambda location: location.timestamp
    )

    inactivity_seconds = 0

    for index in range(
        len(ordered_locations) - 1,
        0,
        -1
    ):

        current = ordered_locations[index]

        previous = ordered_locations[
            index - 1
        ]

        distance = distance_km(
            previous.latitude,
            previous.longitude,
            current.latitude,
            current.longitude
        )

        previous_time = previous.timestamp
        current_time = current.timestamp

        if previous_time.tzinfo is None:
            previous_time = previous_time.replace(
                tzinfo=timezone.utc
            )

        if current_time.tzinfo is None:
            current_time = current_time.replace(
                tzinfo=timezone.utc
            )

        elapsed_seconds = (
            current_time - previous_time
        ).total_seconds()

        if elapsed_seconds <= 0:
            continue

        if distance > stationary_radius_km:
            break

        inactivity_seconds += (
            elapsed_seconds
        )

    return round(
        inactivity_seconds / 60,
        2
    )


def calculate_separation_minutes(
    user_locations,
    group_locations,
    separation_threshold_km=1.5,
    monitoring_window_minutes=60
):
    """
    Calculates continuous group separation duration.

    Only GPS records from the most recent monitoring
    window are considered.

    Separation is considered continuous while the
    user's distance from the available group members
    remains above the threshold.

    The timer resets when the user comes back within
    the group range.
    """

    if not user_locations:
        return 0.0

    if not group_locations:
        return 0.0

    ordered_user_locations = sorted(
        user_locations,
        key=lambda location: location.timestamp
    )

    # Latest known user timestamp
    latest_timestamp = (
        ordered_user_locations[-1].timestamp
    )

    # Only consider the last monitoring window
    window_seconds = (
        monitoring_window_minutes * 60
    )

    recent_user_locations = []

    for location in ordered_user_locations:

        time_from_latest = (
            latest_timestamp
            - location.timestamp
        ).total_seconds()

        if (
            0 <= time_from_latest
            <= window_seconds
        ):
            recent_user_locations.append(
                location
            )

    if not recent_user_locations:
        return 0.0

    separated_start = None

    for user_location in recent_user_locations:

        other_locations = []

        for other in group_locations:

            if other.user_id == user_location.user_id:
                continue

            time_difference = abs(
                (
                    other.timestamp
                    - user_location.timestamp
                ).total_seconds()
            )

            # Match locations recorded within
            # 5 minutes of each other.
            if time_difference <= 300:
                other_locations.append(
                    other
                )

        if not other_locations:
            continue

        max_distance = 0.0

        for other in other_locations:

            distance = distance_km(
                user_location.latitude,
                user_location.longitude,
                other.latitude,
                other.longitude
            )

            max_distance = max(
                max_distance,
                distance
            )

        if max_distance > separation_threshold_km:

            if separated_start is None:
                separated_start = (
                    user_location.timestamp
                )

        else:

            # User came back within range.
            separated_start = None

    if separated_start is None:
        return 0.0

    elapsed_seconds = (
        latest_timestamp
        - separated_start
    ).total_seconds()

    if elapsed_seconds <= 0:
        return 0.0

    # Never report more than the monitoring window.
    elapsed_seconds = min(
        elapsed_seconds,
        window_seconds
    )

    return round(
        elapsed_seconds / 60,
        2
    )