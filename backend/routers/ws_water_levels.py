# routers/ws_water_levels.py
# Closes #45 — WebSocket water level feed
import asyncio
import json
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query, Depends
from app.db import get_asyncpg_conn, get_db_session

router = APIRouter()

# Active subscribers: station_name -> set[WebSocket]
# Use "*" for wildcard (all stations)
_subscribers: dict[str, set[WebSocket]] = {}


async def broadcast_loop():
    """Background task: LISTEN on water_level_channel and fan-out to subscribers.
    Register in main.py: asyncio.create_task(broadcast_loop())
    """
    conn = await get_asyncpg_conn()
    await conn.add_listener("water_level_channel", _on_notify)
    # Keep the connection alive indefinitely
    while True:
        await asyncio.sleep(60)


def _on_notify(conn, pid, channel, payload: str):
    """Called by asyncpg on NOTIFY — schedule fan-out on the event loop."""
    data = json.loads(payload)
    station = data.get("station_name", "*")
    loop = asyncio.get_event_loop()
    loop.create_task(_fanout(station, data))


async def _fanout(station_name: str, data: dict):
    """Send delta update to all matching WebSocket subscribers."""
    dead: set[WebSocket] = set()
    targets = (
        _subscribers.get(station_name, set())
        | _subscribers.get("*", set())
    )
    for ws in targets:
        try:
            await ws.send_json(data)
        except Exception:
            dead.add(ws)
    for ws in dead:
        _remove_subscriber(ws, station_name)


def _remove_subscriber(ws: WebSocket, station_name: str):
    for key in (station_name, "*"):
        _subscribers.get(key, set()).discard(ws)


@router.websocket("/ws/water-levels")
async def water_levels_ws(
    websocket: WebSocket,
    station_name: str = Query(default="*"),
):
    """
    WebSocket endpoint for real-time water level streaming.

    Query params:
        station_name: filter by station name, or "*" for all stations (default)

    On connect:
        - Sends last 20 readings as {"type": "history", "data": [...]}
        - Then streams live delta updates as flat JSON objects

    Schema note: water_level_readings uses (station_name TEXT, level_meters FLOAT8)
    """
    await websocket.accept()
    _subscribers.setdefault(station_name, set()).add(websocket)

    # Send history on connect
    async with get_db_session() as db:
        filter_clause = "" if station_name == "*" else "WHERE station_name = $1"
        args = [] if station_name == "*" else [station_name]
        rows = await db.fetch(
            f"""
            SELECT id::text, station_name, zone_id::text,
                   level_meters, source, recorded_at
            FROM water_level_readings
            {filter_clause}
            ORDER BY recorded_at DESC
            LIMIT 20
            """,
            *args,
        )
        history = [dict(r) for r in rows]
        # Serialize datetimes
        for item in history:
            if hasattr(item.get("recorded_at"), "isoformat"):
                item["recorded_at"] = item["recorded_at"].isoformat()

    await websocket.send_json({"type": "history", "data": history})

    try:
        while True:
            # Await client keep-alive pings; disconnect raises WebSocketDisconnect
            await websocket.receive_text()
    except WebSocketDisconnect:
        _remove_subscriber(websocket, station_name)
