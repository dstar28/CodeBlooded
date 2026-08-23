import json
import uuid

from app.database import SessionLocal
from app.models import SafetyRoute


db = SessionLocal()


route = SafetyRoute(
    id=str(uuid.uuid4()),

    name="Shillong Tourist Route",

    path=json.dumps([
        [25.46, 91.35],
        [25.47, 91.36],
        [25.48, 91.37],
        [25.49, 91.38],
        [25.50, 91.39]
    ]),

    active=True
)


db.add(route)

db.commit()

print(
    "Test route created:"
)

print(
    route.id
)

db.close()