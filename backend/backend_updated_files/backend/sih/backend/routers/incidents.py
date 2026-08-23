from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from database import get_db
from models import Incident

router = APIRouter(
    prefix="/incidents",
    tags=["Incidents"]
)


class IncidentCreate(BaseModel):
    user_id: str
    incident_type: str = "other"
    description: str = ""
    latitude: float | None = None
    longitude: float | None = None


def _serialize(incident: Incident) -> dict:
    return {
        "id": incident.id,
        "user_id": incident.user_id,
        "incident_type": incident.incident_type,
        "description": incident.description,
        "latitude": incident.latitude,
        "longitude": incident.longitude,
        "status": incident.status,
    }


@router.get("/")
def list_incidents(db: Session = Depends(get_db)):
    incidents = db.query(Incident).order_by(Incident.created_at.desc()).all()
    return {"incidents": [_serialize(i) for i in incidents]}


@router.post("/")
def create_incident(body: IncidentCreate, db: Session = Depends(get_db)):
    incident = Incident(
        user_id=body.user_id,
        incident_type=body.incident_type,
        description=body.description,
        latitude=body.latitude,
        longitude=body.longitude,
    )
    db.add(incident)
    db.commit()
    db.refresh(incident)
    return _serialize(incident)


@router.get("/{incident_id}")
def get_incident(incident_id: str, db: Session = Depends(get_db)):
    incident = db.query(Incident).filter(Incident.id == incident_id).first()
    if not incident:
        raise HTTPException(status_code=404, detail="Incident not found")
    return _serialize(incident)
