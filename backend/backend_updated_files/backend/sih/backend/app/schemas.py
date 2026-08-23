from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field, ConfigDict


# ============================================================
# GROUP SCHEMAS
# ============================================================

class CreateGroupRequest(BaseModel):
    name: str = Field(
        ...,
        min_length=2,
        max_length=100
    )

    user_id: str = Field(
        ...,
        min_length=1
    )

    user_name: str = Field(
        ...,
        min_length=1,
        max_length=100
    )


class JoinGroupRequest(BaseModel):
    invite_code: str = Field(
        ...,
        min_length=4,
        max_length=20
    )

    user_id: str = Field(
        ...,
        min_length=1
    )

    user_name: str = Field(
        ...,
        min_length=1,
        max_length=100
    )


class GroupMemberResponse(BaseModel):
    user_id: str
    name: str
    role: str

    share_location: bool
    emergency_location_share: bool

    model_config = ConfigDict(
        from_attributes=True
    )


class GroupResponse(BaseModel):
    group_id: str
    name: str
    invite_code: Optional[str] = None
    active: bool
    member_count: int
    members: List[GroupMemberResponse]


# ============================================================
# LOCATION SCHEMAS
# ============================================================

class LocationUpdateRequest(BaseModel):
    user_id: str
    group_id: str

    latitude: float = Field(
        ...,
        ge=-90,
        le=90
    )

    longitude: float = Field(
        ...,
        ge=-180,
        le=180
    )

    accuracy: Optional[float] = Field(
        default=None,
        ge=0
    )


class LocationResponse(BaseModel):
    user_id: str
    latitude: float
    longitude: float
    accuracy: Optional[float] = None
    timestamp: datetime

    model_config = ConfigDict(
        from_attributes=True
    )


# ============================================================
# SAFETY SCHEMAS
# ============================================================

class MemberSafetyStatus(BaseModel):
    user_id: str
    name: str

    status: str
    distance_km: float


class GroupSafetyStatusResponse(BaseModel):
    group_id: str

    overall_status: str
    message: str

    member_count: int

    max_distance_km: float
    within_range: bool
    group_range_km: float

    members: List[MemberSafetyStatus]


# ============================================================
# SAFETY SETTINGS
# ============================================================

class LocationPermissionRequest(BaseModel):
    user_id: str
    group_id: str

    share_location: bool = False

    emergency_location_share: bool = True


class LocationPermissionResponse(BaseModel):
    user_id: str

    share_location: bool
    emergency_location_share: bool


# ============================================================
# INCIDENT / SOS SCHEMAS
# ============================================================

class SOSRequest(BaseModel):
    user_id: str
    group_id: Optional[str] = None

    latitude: float = Field(
        ...,
        ge=-90,
        le=90
    )

    longitude: float = Field(
        ...,
        ge=-180,
        le=180
    )

    message: Optional[str] = Field(
        default=None,
        max_length=500
    )


class IncidentResponse(BaseModel):
    incident_id: str

    status: str
    message: str


# ============================================================
# ADMIN-ONLY AI RISK SCHEMAS
# ============================================================

class RiskAssessmentResponse(BaseModel):
    """
    This schema is intended for authorized
    emergency administrators only.

    DO NOT expose this response directly
    to the tourist app.
    """

    user_id: str

    risk_score: float = Field(
        ...,
        ge=0,
        le=100
    )

    risk_level: str

    anomaly_detected: bool

    factors: List[str]


# ============================================================
# GROUP DISTANCE SCHEMAS
# ============================================================

class MemberDistance(BaseModel):
    user_id: str
    max_distance_km: float


class GroupDistanceResponse(BaseModel):
    group_id: str

    max_distance_km: float

    within_range: bool

    members: List[MemberDistance]