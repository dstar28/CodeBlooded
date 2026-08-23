import numpy as np
import joblib

from sklearn.ensemble import IsolationForest

# Example NORMAL tourist behaviour.
#
# Columns:
# [group_distance_km,
#  route_deviation_km,
#  inactivity_minutes,
#  speed_kmh,
#  zone_risk,
#  separation_minutes]

X = np.array([
    [0.2, 0.1, 2, 2.5, 0.1, 3],
    [0.4, 0.2, 4, 3.1, 0.1, 5],
    [0.7, 0.3, 5, 2.8, 0.2, 7],
    [0.3, 0.1, 3, 2.0, 0.1, 4],
    [0.8, 0.4, 6, 3.5, 0.2, 8],
    [0.5, 0.2, 4, 2.4, 0.1, 5],
    [0.9, 0.5, 7, 3.0, 0.2, 10],
])

model = IsolationForest(
    n_estimators=150,
    contamination=0.1,
    random_state=42
)

model.fit(X)

joblib.dump(
    model,
    "model.pkl"
)

print("Model trained.")