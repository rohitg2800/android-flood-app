"""Phase 2 – Pump Station & Motor Control API routes."""
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from typing import Optional, List
from uuid import UUID
from datetime import datetime
from ..db import get_db
from ..auth import get_current_user

router = APIRouter(prefix="/pump-stations", tags=["Motor Control"])


# ── Schemas ──────────────────────────────────────────────────────────────────

class PumpStationCreate(BaseModel):
    name: str
    district: Optional[str] = None
    state: str = "Bihar"
    location_lat: Optional[float] = None
    location_lng: Optional[float] = None
    capacity_lps: Optional[float] = None
    installed_at: Optional[datetime] = None


class PumpStationOut(PumpStationCreate):
    id: UUID
    status: str
    created_at: datetime
    updated_at: datetime


class MotorActionPayload(BaseModel):
    action: str = Field(..., pattern="^(start|stop|auto-trigger|fault-reset)$")
    reason: Optional[str] = None
    water_level_ref_id: Optional[int] = None


class MotorLogOut(BaseModel):
    id: int
    pump_station_id: UUID
    triggered_by: Optional[str]
    action: str
    reason: Optional[str]
    water_level_ref_id: Optional[int]
    logged_at: datetime


# ── Routes ───────────────────────────────────────────────────────────────────

@router.get("/", response_model=List[PumpStationOut])
async def list_pump_stations(
    district: Optional[str] = None,
    status_filter: Optional[str] = None,
    db=Depends(get_db),
):
    """List all pump stations. Optionally filter by district or status."""
    query = "SELECT * FROM pump_stations WHERE 1=1"
    params = []
    if district:
        params.append(district)
        query += f" AND district = ${len(params)}"
    if status_filter:
        params.append(status_filter)
        query += f" AND status = ${len(params)}"
    query += " ORDER BY created_at DESC"
    return await db.fetch(query, *params)


@router.post("/", response_model=PumpStationOut, status_code=status.HTTP_201_CREATED)
async def create_pump_station(
    payload: PumpStationCreate,
    db=Depends(get_db),
    user=Depends(get_current_user),
):
    """Create a new pump station (admin only)."""
    row = await db.fetchrow(
        """
        INSERT INTO pump_stations (name, district, state, location_lat, location_lng,
                                   capacity_lps, installed_at)
        VALUES ($1,$2,$3,$4,$5,$6,$7)
        RETURNING *
        """,
        payload.name, payload.district, payload.state,
        payload.location_lat, payload.location_lng,
        payload.capacity_lps, payload.installed_at,
    )
    return row


@router.get("/{station_id}", response_model=PumpStationOut)
async def get_pump_station(station_id: UUID, db=Depends(get_db)):
    row = await db.fetchrow("SELECT * FROM pump_stations WHERE id=$1", station_id)
    if not row:
        raise HTTPException(status_code=404, detail="Pump station not found")
    return row


@router.patch("/{station_id}/status")
async def update_station_status(
    station_id: UUID,
    new_status: str,
    db=Depends(get_db),
    user=Depends(get_current_user),
):
    """Update station status (active/inactive/fault)."""
    if new_status not in ("active", "inactive", "fault"):
        raise HTTPException(status_code=400, detail="Invalid status value")
    row = await db.fetchrow(
        "UPDATE pump_stations SET status=$1, updated_at=now() WHERE id=$2 RETURNING *",
        new_status, station_id,
    )
    if not row:
        raise HTTPException(status_code=404, detail="Pump station not found")
    return row


@router.post("/{station_id}/motor-action", response_model=MotorLogOut,
             status_code=status.HTTP_201_CREATED)
async def log_motor_action(
    station_id: UUID,
    payload: MotorActionPayload,
    db=Depends(get_db),
    user=Depends(get_current_user),
):
    """Log a motor action (start/stop/auto-trigger/fault-reset)."""
    row = await db.fetchrow(
        """
        INSERT INTO motor_logs
          (pump_station_id, triggered_by, action, reason, water_level_ref_id)
        VALUES ($1,$2,$3,$4,$5)
        RETURNING *
        """,
        station_id, user["id"],
        payload.action, payload.reason, payload.water_level_ref_id,
    )
    return row


@router.get("/{station_id}/motor-logs", response_model=List[MotorLogOut])
async def get_motor_logs(
    station_id: UUID,
    limit: int = 50,
    db=Depends(get_db),
):
    """Get motor action history for a station."""
    rows = await db.fetch(
        "SELECT * FROM motor_logs WHERE pump_station_id=$1 ORDER BY logged_at DESC LIMIT $2",
        station_id, limit,
    )
    return rows
