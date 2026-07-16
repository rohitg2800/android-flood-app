from typing import List, Optional

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect
from sqlalchemy import text

from db import engine
from services.water_level_ws_service import water_level_ws_manager

router = APIRouter(tags=["water-level-ws"])


def _is_token_valid(token: Optional[str]) -> bool:
    return token is not None and token.strip() != ""


def _fetch_snapshot(
    state: Optional[str] = None,
    district: Optional[str] = None,
    stations: Optional[List[str]] = None,
    limit: int = 100,
):
    sql = """
    SELECT
        id,
        station_id,
        water_level,
        rainfall,
        flow_rate,
        temperature,
        humidity,
        data_source,
        is_verified,
        recorded_at,
        created_at
    FROM water_level_readings
    ORDER BY recorded_at DESC
    LIMIT :limit
    """

    with engine.connect() as conn:
        rows = conn.execute(text(sql), {"limit": limit}).mappings().all()
        return [dict(row) for row in rows]


@router.websocket("/ws/water-levels")
async def water_level_ws(
    websocket: WebSocket,
    token: Optional[str] = Query(default=None),
    state: Optional[str] = Query(default=None),
    district: Optional[str] = Query(default=None),
    stations: Optional[str] = Query(default=None),
):
    if not _is_token_valid(token):
        await websocket.close(code=1008)
        return

    station_list = [s.strip() for s in stations.split(",")] if stations else []

    await water_level_ws_manager.connect(
        websocket,
        state=state,
        district=district,
        stations=station_list,
    )

    try:
        snapshot = _fetch_snapshot(
            state=state,
            district=district,
            stations=station_list,
            limit=100,
        )
        await websocket.send_json({
            "type": "snapshot",
            "data": snapshot,
        })

        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        await water_level_ws_manager.disconnect(websocket)
    except Exception:
        await water_level_ws_manager.disconnect(websocket)
        await websocket.close(code=1011)
