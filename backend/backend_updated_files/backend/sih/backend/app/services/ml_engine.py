import os
import joblib
import numpy as np

MODEL_PATH = os.path.join(
    "app",
    "ml",
    "model.pkl"
)

model = joblib.load(MODEL_PATH)


def calculate_risk(
    group_distance_km,
    route_deviation_km,
    inactivity_minutes,
    speed_kmh,
    zone_risk,
    separation_minutes
):

    features = np.array([[
        group_distance_km,
        route_deviation_km,
        inactivity_minutes,
        speed_kmh,
        zone_risk,
        separation_minutes
    ]])

    prediction = model.predict(features)[0]

    anomaly_score = model.decision_function(
        features
    )[0]

    # Convert anomaly score into a simple
    # 0-100 internal risk score.

    normalized = max(
        0,
        min(
            1,
            0.5 - anomaly_score
        )
    )

    risk = normalized * 100

    # Safety rules strengthen the score.
    if zone_risk >= 0.8:
        risk += 15

    if inactivity_minutes >= 15:
        risk += 15

    if group_distance_km >= 1.5:
        risk += 10

    if separation_minutes >= 10:
        risk += 10

    risk = min(
        100,
        round(risk)
    )

    return {
        "risk_score": risk,
        "anomaly": prediction == -1
    }