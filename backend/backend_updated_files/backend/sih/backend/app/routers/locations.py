"""
Scaffolded to match the request the Flutter app already sends
(lib/services/api/safeguard_api_client.dart -> updateLocation):

    POST /locations/update
    { "user_id": ..., "group_id": ..., "latitude": ..., "longitude": ...,
      "accuracy": ... }
"""

import uuid

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Location

router = APIRouter(
    prefix="/locations",
    tags=["Locations"],
)


class LocationUpdate(BaseModel):
    user_id: str
    group_id: str | None = None
    latitude: float
    longitude: float
    accuracy: float | None = None


@router.post("/update")
def update_location(
    payload: LocationUpdate,
    db: Session = Depends(get_db),
):
    location = Location(
        id=str(uuid.uuid4()),
        user_id=payload.user_id,
        group_id=payload.group_id,
        latitude=payload.latitude,
        longitude=payload.longitude,
        accuracy=payload.accuracy,
    )
    db.add(location)
    db.commit()

    return {
        "status": "ok",
        "location_id": location.id,
    }
