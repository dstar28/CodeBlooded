from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from database import get_db
from models import UserLocation

router = APIRouter(
    prefix="/locations",
    tags=["Locations"]
)


class LocationUpdateBody(BaseModel):
    user_id: str
    group_id: str | None = None
    latitude: float
    longitude: float
    accuracy: float | None = None


@router.post("/update")
def update_location(
    body: LocationUpdateBody,
    db: Session = Depends(get_db)
):
    """
    Upserts the caller's latest known position. This is the single
    write path both the mobile GPS flow and the Group Safety Circle
    "share my location" flow use — everything downstream (safety-circle
    proximity status, geofence checks) reads from this table.
    """

    existing = (
        db.query(UserLocation)
        .filter(UserLocation.user_id == body.user_id)
        .first()
    )

    if existing:
        existing.group_id = body.group_id
        existing.latitude = body.latitude
        existing.longitude = body.longitude
        existing.accuracy = body.accuracy
    else:
        db.add(UserLocation(
            user_id=body.user_id,
            group_id=body.group_id,
            latitude=body.latitude,
            longitude=body.longitude,
            accuracy=body.accuracy,
        ))

    db.commit()

    return {
        "user_id": body.user_id,
        "latitude": body.latitude,
        "longitude": body.longitude,
        "saved": True,
    }
