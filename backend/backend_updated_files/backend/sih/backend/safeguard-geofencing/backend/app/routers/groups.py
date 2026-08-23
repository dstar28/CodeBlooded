import uuid
import secrets

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import SafetyGroup, GroupMember

router = APIRouter(
    prefix="/groups",
    tags=["Groups"]
)


@router.post("/")
def create_group(
    name: str,
    user_id: str,
    user_name: str,
    db: Session = Depends(get_db)
):

    group_id = str(uuid.uuid4())

    invite_code = secrets.token_hex(3).upper()

    group = SafetyGroup(
        id=group_id,
        name=name,
        invite_code=invite_code
    )

    db.add(group)

    member = GroupMember(
        id=str(uuid.uuid4()),
        group_id=group_id,
        user_id=user_id,
        name=user_name,
        role="owner",
        emergency_location_share=True
    )

    db.add(member)

    db.commit()

    return {
        "group_id": group_id,
        "name": name,
        "invite_code": invite_code
    }


@router.post("/join")
def join_group(
    invite_code: str,
    user_id: str,
    user_name: str,
    db: Session = Depends(get_db)
):

    group = (
        db.query(SafetyGroup)
        .filter(
            SafetyGroup.invite_code == invite_code,
            SafetyGroup.active == True
        )
        .first()
    )

    if not group:
        raise HTTPException(
            status_code=404,
            detail="Group not found"
        )

    existing = (
        db.query(GroupMember)
        .filter(
            GroupMember.group_id == group.id,
            GroupMember.user_id == user_id
        )
        .first()
    )

    if existing:
        return {
            "message": "Already a member",
            "group_id": group.id
        }

    member = GroupMember(
        id=str(uuid.uuid4()),
        group_id=group.id,
        user_id=user_id,
        name=user_name,
        role="member",
        emergency_location_share=True
    )

    db.add(member)
    db.commit()

    return {
        "message": "Joined group",
        "group_id": group.id
    }

@router.get("/{group_id}")
def get_group(
    group_id: str,
    db: Session = Depends(get_db)
):

    group = (
        db.query(SafetyGroup)
        .filter(SafetyGroup.id == group_id)
        .first()
    )

    if not group:
        raise HTTPException(
            status_code=404,
            detail="Group not found"
        )

    members = (
        db.query(GroupMember)
        .filter(
            GroupMember.group_id == group_id
        )
        .all()
    )

    return {
        "group_id": group.id,
        "name": group.name,
        "invite_code": group.invite_code,
        "active": group.active,
        "member_count": len(members),
        "members": [
            {
                "user_id": member.user_id,
                "name": member.name,
                "role": member.role,
                "share_location": member.share_location,
                "emergency_location_share":
                    member.emergency_location_share
            }
            for member in members
        ]
    }
