from .ml_engine import calculate_risk


def evaluate_member(
    group_distance_km,
    route_deviation_km,
    inactivity_minutes,
    speed_kmh,
    zone_risk,
    separation_minutes
):
    """
    Combines safety rules with ML anomaly detection.

    The final risk score is intended for authorized
    administrators only.
    """

    ml_result = calculate_risk(
        group_distance_km=group_distance_km,
        route_deviation_km=route_deviation_km,
        inactivity_minutes=inactivity_minutes,
        speed_kmh=speed_kmh,
        zone_risk=zone_risk,
        separation_minutes=separation_minutes
    )

    ml_anomaly = bool(
        ml_result["anomaly"]
    )

    factors = []

    # --------------------------------------------------
    # RULE-BASED SAFETY SCORE
    # --------------------------------------------------

    rule_score = 0

    # Group separation
    if group_distance_km > 1.5:
        rule_score += 25
        factors.append("Group separation")

    # Route deviation
    if route_deviation_km > 0.5:
        rule_score += 20
        factors.append("Route deviation")

    # Inactivity
    if inactivity_minutes >= 15:
        rule_score += 20
        factors.append("Prolonged inactivity")

    elif inactivity_minutes >= 10:
        rule_score += 10
        factors.append("Unusual inactivity")

    # No movement
    if speed_kmh == 0 and inactivity_minutes >= 10:
        rule_score += 15
        factors.append("No movement detected")

    # High-risk zone
    if zone_risk >= 0.8:
        rule_score += 20
        factors.append("High-risk zone")

    elif zone_risk >= 0.5:
        rule_score += 10
        factors.append("Elevated zone risk")

    # Extended separation
    if separation_minutes >= 15:
        rule_score += 15
        factors.append("Extended group separation")

    elif separation_minutes >= 10:
        rule_score += 8
        factors.append("Group separation duration")

    # --------------------------------------------------
    # ML CONTRIBUTION
    # --------------------------------------------------

    # ML is treated as supporting evidence,
    # not the sole decision maker.

    if ml_anomaly:
        rule_score += 10

        factors.append(
            "Unusual movement pattern detected by AI"
        )

    # Keep score between 0 and 100
    risk_score = min(
        100,
        float(rule_score)
    )

    # --------------------------------------------------
    # RISK LEVEL
    # --------------------------------------------------

    if risk_score >= 80:
        risk_level = "CRITICAL"

    elif risk_score >= 60:
        risk_level = "HIGH"

    elif risk_score >= 35:
        risk_level = "MEDIUM"

    else:
        risk_level = "LOW"

    return {
        "risk_score": risk_score,
        "risk_level": risk_level,
        "anomaly_detected": ml_anomaly,
        "factors": factors
    }