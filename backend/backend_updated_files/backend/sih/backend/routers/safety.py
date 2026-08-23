from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from database import get_db
from geo_utils import haversine_km
from models import GroupMember, UserLocation

router = APIRouter(
    prefix="/safety",
    tags=["Safety"]
)

# If a member is farther than this from the group's centroid, they're
# flagged WARNING in the safety-circle view.
_GROUP_SPREAD_WARNING_KM = 1.0


@router.get("/groups/{group_id}/status")
def get_group_safety_status(
    group_id: str,
    db: Session = Depends(get_db)
):
    """
    Per-member proximity status for a Safety Circle group.

    Response shape (matches what SafetyCircleStore already expects):
    {
      "members": [
        {"user_id": ..., "status": "OK" | "WARNING", "distance_km": float | null}
      ]
    }

    Members who aren't sharing location, or have no location on file
    yet, are returned with status "OK" and distance_km null rather than
    omitted, so the UI still lists every member.
    """

    members = (
        db.query(GroupMember)
        .filter(GroupMember.group_id == group_id)
        .all()
    )

    locations_by_user = {
        loc.user_id: loc
        for loc in db.query(UserLocation)
        .filter(UserLocation.user_id.in_([m.user_id for m in members]))
        .all()
    }

    sharing_points = [
        (locations_by_user[m.user_id].latitude, locations_by_user[m.user_id].longitude)
        for m in members
        if m.share_location and m.user_id in locations_by_user
    ]

    centroid = None
    if sharing_points:
        centroid = (
            sum(p[0] for p in sharing_points) / len(sharing_points),
            sum(p[1] for p in sharing_points) / len(sharing_points),
        )

    result = []
    for member in members:
        location = locations_by_user.get(member.user_id)

        if not member.share_location or location is None or centroid is None:
            result.append({
                "user_id": member.user_id,
                "status": "OK",
                "distance_km": None,
            })
            continue

        distance_km = haversine_km(
            location.latitude, location.longitude, centroid[0], centroid[1]
        )
        status = "WARNING" if distance_km > _GROUP_SPREAD_WARNING_KM else "OK"

        result.append({
            "user_id": member.user_id,
            "status": status,
            "distance_km": round(distance_km, 3),
        })

    return {"group_id": group_id, "members": result}
