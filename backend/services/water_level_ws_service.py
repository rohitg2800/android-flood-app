import asyncio
import json
from typing import Any, Dict, List, Optional, Set

from fastapi import WebSocket


class WaterLevelConnectionManager:
    def __init__(self) -> None:
        self._clients: Set[WebSocket] = set()
        self._filters: Dict[WebSocket, Dict[str, Any]] = {}
        self._lock = asyncio.Lock()

    async def connect(
        self,
        websocket: WebSocket,
        *,
        state: Optional[str] = None,
        district: Optional[str] = None,
        stations: Optional[List[str]] = None,
    ) -> None:
        await websocket.accept()
        async with self._lock:
            self._clients.add(websocket)
            self._filters[websocket] = {
                "state": state,
                "district": district,
                "stations": set(stations or []),
            }

    async def disconnect(self, websocket: WebSocket) -> None:
        async with self._lock:
            self._clients.discard(websocket)
            self._filters.pop(websocket, None)

    async def broadcast_snapshot(self, rows: List[Dict[str, Any]]) -> None:
        payload = {
            "type": "snapshot",
            "data": rows,
        }
        await self._broadcast(payload)

    async def broadcast_reading(self, row: Dict[str, Any]) -> None:
        payload = {
            "type": "reading",
            "data": row,
        }
        await self._broadcast(payload)

    async def _broadcast(self, payload: Dict[str, Any]) -> None:
        dead: List[WebSocket] = []

        async with self._lock:
            clients = list(self._clients)

        for websocket in clients:
            try:
                if self._matches_filter(websocket, payload["data"]):
                    await websocket.send_text(json.dumps(payload, default=str))
            except Exception:
                dead.append(websocket)

        for websocket in dead:
            await self.disconnect(websocket)

    def _matches_filter(self, websocket: WebSocket, data: Any) -> bool:
        filters = self._filters.get(websocket, {})
        if isinstance(data, list):
            return True

        state = filters.get("state")
        district = filters.get("district")
        stations = filters.get("stations") or set()

        if state and data.get("state") != state:
            return False
        if district and data.get("district") != district:
            return False
        if stations and data.get("station_id") not in stations:
            return False

        return True


water_level_ws_manager = WaterLevelConnectionManager()
