"""
Scaffolded to match lib/services/api/safeguard_api_client.dart ->
getSafetyStatus:

    GET /safety/groups/{group_id}/status

Returns each member's most recent location ping plus a per-member
safe/warning/danger status computed against active geofence zones, using
the same logic as POST /geofences/check (see geofences.py). Kept
intentionally simple — this is not the focus of the geofencing feature,
just enough to keep the existing group-status screen wired up.
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import GroupMember, Location, SafetyGroup
from .geofences import evaluate_point

router = APIRouter(
    prefix="/safety",
    tags=["Safety"],
)


@router.get("/groups/{group_id}/status")
def group_status(group_id: str, db: Session = Depends(get_db)):
    group = db.query(SafetyGroup).filter(SafetyGroup.id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")

    members = db.query(GroupMember).filter(GroupMember.group_id == group_id).all()

    member_statuses = []
    for member in members:
        latest = (
            db.query(Location)
            .filter(Location.user_id == member.user_id)
            .order_by(Location.timestamp.desc())
            .first()
        )
        if latest is None:
            member_statuses.append(
                {
                    "user_id": member.user_id,
                    "name": member.name,
                    "status": "unknown",
                    "inside_zone": False,
                }
            )
            continue

        result = evaluate_point(db, latest.latitude, latest.longitude)
        member_statuses.append(
            {
                "user_id": member.user_id,
                "name": member.name,
                "latitude": latest.latitude,
                "longitude": latest.longitude,
                **result,
            }
        )

    return {
        "group_id": group_id,
        "members": member_statuses,
    }
