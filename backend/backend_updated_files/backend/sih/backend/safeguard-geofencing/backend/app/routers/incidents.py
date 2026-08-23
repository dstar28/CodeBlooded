"""
Minimal placeholder router. Incident reporting is already handled via
Supabase in the Flutter app (lib/services/supabase/incident_repository.dart)
— this file exists only so main.py's pre-existing
`from .routers import incidents` import resolves. Not part of the
geofencing feature; not built out further here.
"""

from fastapi import APIRouter

router = APIRouter(
    prefix="/incidents",
    tags=["Incidents"],
)


@router.get("/")
def list_incidents():
    return {"incidents": [], "note": "Incidents are managed via Supabase, not this API."}
