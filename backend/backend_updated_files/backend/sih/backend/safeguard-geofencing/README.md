# SafeGuard Geofencing — Implementation Report

## Important caveat first
Your uploaded `LICENSE.zip` did not contain the FastAPI backend's `routers/`
package, `database.py`, or `models.py` (only loose `main.py` and `groups.py`
files), and no Admin Dashboard existed anywhere in it. Per your instructions,
I scaffolded those fresh rather than guessing at code that wasn't there —
**merge this into your real repo, don't just drop it in blind**, since your
actual `database.py`/`models.py` (if they exist elsewhere) may differ from
what's here.

## Files created
```
backend/
  requirements.txt
  app/
    __init__.py
    main.py                    # modified: added geofences router + /admin static mount
    database.py                 # NEW (scaffolded — see caveat)
    models.py                   # NEW (scaffolded — see caveat)
    routers/
      __init__.py
      groups.py                 # unchanged logic, moved into routers/ package
      locations.py              # NEW (scaffolded to match Flutter's existing call)
      safety.py                 # NEW (scaffolded to match Flutter's existing call)
      incidents.py               # NEW minimal stub (out of scope, keeps import working)
      geofences.py               # NEW — the actual geofencing feature
  static/admin/index.html        # NEW — Leaflet + Turf.js admin dashboard
flutter-changes/
  lib/services/api/safeguard_api_client.dart   # modified: added checkGeofence()
  lib/screens/live_safety_screen.dart          # modified: wired real geofence check in
```

## Files modified (vs. your upload)
- `main.py` — added `geofences` router, `/admin` static file mount, startup DB init.
- `safeguard_api_client.dart` — added one method, `checkGeofence()`, nothing else touched.
- `live_safety_screen.dart` — after `_fetchPosition()` succeeds, it now also calls
  `checkGeofence()` and maps the real `safe`/`warning`/`danger` response onto the
  existing `SafetyStatus` enum. The "Simulate Safety Check (Demo)" button is left
  in place as a manual override. No other screens touched.

## Dependencies added
- Backend: `fastapi`, `uvicorn[standard]`, `sqlalchemy`, `pydantic`, `shapely`
- Admin dashboard: Leaflet, Leaflet.draw, Turf.js — all via CDN (`cdnjs.cloudflare.com`), no build step, no new Flutter deps
- Flutter: none (`http` was already a dependency)

## Leaflet integration location
`backend/static/admin/index.html`, served at `/admin/` by FastAPI's `StaticFiles` mount
(no separate frontend framework — a self-contained static page, since none existed).

## Turf.js integration location
Same file, client-side only. It's used to (a) convert a drawn circle into a real
polygon buffer for map preview and (b) keep GeoJSON as the shared format the whole
pipeline uses. **Turf.js is not used inside the Python backend** — it can't run in a
Python process without shelling out to Node per request. The actual server-side
point-in-zone check (`geofences.py`) uses **Shapely**, Python's equivalent geospatial
library, operating on the same GeoJSON Turf.js/Leaflet produced. This is flagged
in a docstring at the top of `geofences.py` — flag it back to me if you'd rather
I stand up a small Node microservice to run literal Turf.js server-side instead.

## API endpoints
| Method | Path | Purpose |
|---|---|---|
| GET | `/geofences/active` | Fetch active zones as GeoJSON (admin map + optional mobile use) |
| GET | `/geofences/pending` | Zones awaiting admin review |
| POST | `/geofences/propose` | Create a proposed zone (admin-drawn or AI) — never active on creation |
| POST | `/geofences/{id}/approve` | **Only** path that can set `active=true` |
| POST | `/geofences/{id}/reject` | Discards a proposal |
| POST | `/geofences/{id}/deactivate` | Turns an approved zone off without deleting it |
| POST | `/geofences/check` | `{latitude, longitude}` → `{status, inside_zone, zone_id?, zone_name?, risk_level?}` — what the Flutter app calls |
| GET | `/safety/groups/{id}/status` | Existing endpoint, extended to run the same check per group member |
| POST | `/locations/update` | Existing endpoint (scaffolded to match what Flutter already sends) |

## GeoJSON structure
Polygons are stored/returned as standard GeoJSON. Circles are stored as
`{"center": [lon, lat], "radius_m": N}` and returned to the map as a GeoJSON
`Point` with a `radius_m` property; the admin dashboard's Turf.js buffers that
back into a polygon for display, matching your spec's example `Feature` shape.

## How Flutter sends location
Unchanged from what was already in `safeguard_api_client.dart`/`live_safety_screen.dart`
— real GPS via `Geolocator.getCurrentPosition()`, no mock coordinates. The new part is
that the fetched position is now also POSTed to `/geofences/check`, and the response
drives `_safetyStatus` on the Live Safety screen.

## How admin approval works
A zone (admin-drawn or AI-proposed) is created via `/geofences/propose` with
`active=false`. It only becomes `active=true` through `/geofences/{id}/approve`,
which requires an admin action from the dashboard — there is no code path that lets
a proposal activate itself. This is enforced in the endpoint logic, not just by
convention.

## Commands to run everything
```bash
# Backend
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Admin dashboard
# open http://localhost:8000/admin/  (served by the backend, no separate step)

# Flutter (merge flutter-changes/lib/... into your real lib/ tree first)
flutter pub get
flutter run
```

**Note:** I could not actually run `uvicorn`/`flutter` in this sandbox (no network
access to install packages), so this was verified with `python3 -m py_compile` on
every backend file (all pass) and manual review of the Flutter diff, not a live
end-to-end run. Please run it locally before shipping.
