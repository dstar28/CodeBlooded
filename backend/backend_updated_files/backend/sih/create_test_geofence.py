import json
import uuid

from app.database import SessionLocal
from app.models import Geofence


db = SessionLocal()


geofence = Geofence(
    id=str(uuid.uuid4()),

    name="Test High Risk Zone",

    description=(
        "Prototype admin-approved "
        "high risk tourism zone"
    ),

    polygon=json.dumps([
        [25.45, 91.34],
        [25.45, 91.45],
        [25.52, 91.45],
        [25.52, 91.34]
    ]),

    risk_level=0.8,

    active=True
)


db.add(geofence)

db.commit()

print(
    "Test geofence created:"
)

print(
    geofence.id
)

db.close()