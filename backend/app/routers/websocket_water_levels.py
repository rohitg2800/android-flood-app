"""WebSocket endpoint for real-time water level feed.

Issue #45 — Water Level WebSocket Feed
Flow: water_level_readings INSERT → NOTIFY → broadcast to subscribed clients
"""

import asyncio
import json
import logging
from typing import Optional

import asyncpg
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query
from app.core.config import settings

router = APIRouter(tags=["websocket"])
logger = logging.getLogger(__name__)


class ConnectionManager:
    """Manages active WebSocket connections per station."""

    def __init__(self):
        # station_name -> set of websockets
        self.active: dict[str, set[WebSocket]] = {}
        # broadcast-all bucket
        self.wildcard: set[WebSocket] = set()

    async def connect(self, ws: WebSocket, station: Optional[str]):
        await ws.accept()
        if station:
            self.active.setdefault(station, set()).add(ws)
        else:
            self.wildcard.add(ws)
        logger.info("WS connected station=%s total=%d", station, self.total())

    def disconnect(self, ws: WebSocket, station: Optional[str]):
        if station and station in self.active:
            self.active[station].discard(ws)
        else:
            self.wildcard.discard(ws)
        logger.info("WS disconnected station=%s total=%d", station, self.total())

    def total(self) -> int:
        return sum(len(v) for v in self.active.values()) + len(self.wildcard)

    async def broadcast(self, payload: dict, station: Optional[str]):
        message = json.dumps(payload)
        targets: set[WebSocket] = set()
        if station and station in self.active:
            targets |= self.active[station]
        targets |= self.wildcard
        dead: list[WebSocket] = []
        for ws in targets:
            try:
                await ws.send_text(message)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.wildcard.discard(ws)
            for s in self.active:
                self.active[s].discard(ws)


manager = ConnectionManager()
_pg_conn: Optional[asyncpg.Connection] = None


async def _get_history(conn: asyncpg.Connection, station: Optional[str], limit: int = 20) -> list[dict]:
    """Fetch last N readings for the requested station."""
    if station:
        rows = await conn.fetch(
            """
            SELECT id::text, station_name, level_meters,
                   flow_rate, status, recorded_at
            FROM water_level_readings
            WHERE station_name = $1
            ORDER BY recorded_at DESC
            LIMIT $2
            """,
            station, limit,
        )
    else:
        rows = await conn.fetch(
            """
            SELECT id::text, station_name, level_meters,
                   flow_rate, status, recorded_at
            FROM water_level_readings
            ORDER BY recorded_at DESC
            LIMIT $1
            """,
            limit,
        )
    return [
        {
            "station_name": r["station_name"],
            "level_meters": r["level_meters"],
            "flow_rate": r["flow_rate"],
            "status": r["status"],
            "recorded_at": r["recorded_at"].isoformat(),
            "type": "history",
        }
        for r in reversed(rows)
    ]


async def _listen_loop():
    """Background task: LISTEN for water_level_channel and broadcast."""
    global _pg_conn
    while True:
        try:
            _pg_conn = await asyncpg.connect(settings.DATABASE_URL)

            async def on_notify(conn, pid, channel, payload):
                try:
                    data = json.loads(payload)
                    data["type"] = "update"
                    await manager.broadcast(data, data.get("station_name"))
                except Exception as exc:
                    logger.warning("notify parse error: %s", exc)

            await _pg_conn.add_listener("water_level_channel", on_notify)
            logger.info("Listening on water_level_channel")
            # keep alive
            while True:
                await asyncio.sleep(30)
                await _pg_conn.execute("SELECT 1")
        except Exception as exc:
            logger.error("LISTEN loop error: %s — reconnecting in 5s", exc)
            if _pg_conn:
                try:
                    await _pg_conn.close()
                except Exception:
                    pass
            await asyncio.sleep(5)


@router.on_event("startup")  # type: ignore[attr-defined]
async def start_listen_loop():
    asyncio.create_task(_listen_loop())


@router.websocket("/ws/water-levels")
async def water_level_ws(
    websocket: WebSocket,
    station_name: Optional[str] = Query(None, alias="station_id"),
):
    """WebSocket: stream real-time water level readings.

    Query param: ?station_id=<station_name>  (omit for all stations)
    """
    await manager.connect(websocket, station_name)
    try:
        # Send history on connect
        conn: asyncpg.Connection = await asyncpg.connect(settings.DATABASE_URL)
        try:
            history = await _get_history(conn, station_name)
        finally:
            await conn.close()

        for item in history:
            await websocket.send_text(json.dumps(item))

        # Keep connection open; updates arrive via broadcast
        while True:
            # Heartbeat / keep-alive ping every 20s
            await asyncio.sleep(20)
            await websocket.send_text(json.dumps({"type": "ping"}))

    except WebSocketDisconnect:
        manager.disconnect(websocket, station_name)
    except Exception as exc:
        logger.error("WS error: %s", exc)
        manager.disconnect(websocket, station_name)
