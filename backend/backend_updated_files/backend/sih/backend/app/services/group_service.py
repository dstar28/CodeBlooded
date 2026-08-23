import secrets
import uuid

from sqlalchemy.orm import Session

from ..models import SafetyGroup, GroupMember


def create_group(
    db: Session,
    name: str,
    user_id: str,
    user_name: str
):
    """
    Create a new Safety Circle and add
    the creator as the group owner.
    """

    group_id = str(uuid.uuid4())

    # Generate a short invite code
    invite_code = secrets.token_hex(3).upper()

    group = SafetyGroup(
        id=group_id,
        name=name,
        invite_code=invite_code,
        active=True
    )

    db.add(group)

    member = GroupMember(
        id=str(uuid.uuid4()),
        group_id=group_id,
        user_id=user_id,
        name=user_name,
        role="owner",
        share_location=False,
        emergency_location_share=True
    )

    db.add(member)

    db.commit()
    db.refresh(group)

    return group


def join_group(
    db: Session,
    invite_code: str,
    user_id: str,
    user_name: str
):
    """
    Add a tourist to an existing Safety Circle.
    """

    group = (
        db.query(SafetyGroup)
        .filter(
            SafetyGroup.invite_code == invite_code,
            SafetyGroup.active.is_(True)
        )
        .first()
    )

    if not group:
        return None, "Group not found or inactive"

    # Check if user is already a member
    existing_member = (
        db.query(GroupMember)
        .filter(
            GroupMember.group_id == group.id,
            GroupMember.user_id == user_id
        )
        .first()
    )

    if existing_member:
        return existing_member, "Already a member"

    member = GroupMember(
        id=str(uuid.uuid4()),
        group_id=group.id,
        user_id=user_id,
        name=user_name,
        role="member",
        share_location=False,
        emergency_location_share=True
    )

    db.add(member)
    db.commit()
    db.refresh(member)

    return member, "Joined group successfully"


def get_group(
    db: Session,
    group_id: str
):
    """
    Get a Safety Circle and its members.
    """

    group = (
        db.query(SafetyGroup)
        .filter(
            SafetyGroup.id == group_id,
            SafetyGroup.active.is_(True)
        )
        .first()
    )

    if not group:
        return None

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


def get_group_members(
    db: Session,
    group_id: str
):
    """
    Get only the members of a Safety Circle.
    """

    return (
        db.query(GroupMember)
        .filter(
            GroupMember.group_id == group_id
        )
        .all()
    )


def leave_group(
    db: Session,
    group_id: str,
    user_id: str
):
    """
    Remove a tourist from a Safety Circle.
    """

    member = (
        db.query(GroupMember)
        .filter(
            GroupMember.group_id == group_id,
            GroupMember.user_id == user_id
        )
        .first()
    )

    if not member:
        return False

    db.delete(member)
    db.commit()

    return True


def update_location_permission(
    db: Session,
    group_id: str,
    user_id: str,
    share_location: bool,
    emergency_location_share: bool = True
):
    """
    Update a member's location-sharing permissions.
    """

    member = (
        db.query(GroupMember)
        .filter(
            GroupMember.group_id == group_id,
            GroupMember.user_id == user_id
        )
        .first()
    )

    if not member:
        return None

    member.share_location = share_location
    member.emergency_location_share = emergency_location_share

    db.commit()
    db.refresh(member)

    return member