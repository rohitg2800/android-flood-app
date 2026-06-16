# backend/ws_server.py  v1.1
# FastAPI WebSocket endpoint: /ws/gauges
# Broadcasts full gauge list every 45s to all connected clients.
#
# v1.1 fix: json.loads errors inside the receive loop are now caught per-message
#           so a malformed / non-JSON frame no longer kills the connection
#           (was crashing with code 1006 on plain-string "ping" from clients).

import asyncio
import json
import logging
from typing import Set
from fastapi import WebSocket, WebSocketDisconnect

logger = logging.getLogger(__name__)

# ── Connection registry ────────────────────────────────────────────────────────
_connections: Set[WebSocket] = set()
_last_payload: str | None = None          # cached last broadcast payload

BROADCAST_INTERVAL_SEC = 45
PING_INTERVAL_SEC      = 20


async def ws_gauges_endpoint(websocket: WebSocket, get_live_data_fn):
    """
    Mount this in your FastAPI app:

        from ws_server import ws_gauges_endpoint

        @app.websocket('/ws/gauges')
        async def _ws(ws: WebSocket):
            await ws_gauges_endpoint(ws, get_live_levels)  # your data fn
    """
    await websocket.accept()
    _connections.add(websocket)
    logger.info(f'[WS] client connected. total={len(_connections)}')

    # Send cached payload immediately so client gets data without waiting 45s
    if _last_payload:
        try:
            await websocket.send_text(_last_payload)
        except Exception:
            pass

    ping_task      = asyncio.create_task(_ping_loop(websocket))
    broadcast_task = asyncio.create_task(_broadcast_loop(websocket, get_live_data_fn))

    try:
        while True:
            raw = await websocket.receive_text()
            # ── Per-message guard: never crash the loop on bad input ──────────
            try:
                msg = json.loads(raw)
            except (json.JSONDecodeError, ValueError):
                logger.debug(f'[WS] non-JSON frame ignored: {raw[:120]}')
                continue
            if not isinstance(msg, dict):
                continue
            if msg.get('type') == 'ping':
                await websocket.send_text(json.dumps({'type': 'pong'}))
    except WebSocketDisconnect:
        logger.info('[WS] client disconnected')
    except Exception as e:
        logger.warning(f'[WS] error: {e}')
    finally:
        ping_task.cancel()
        broadcast_task.cancel()
        _connections.discard(websocket)


async def _ping_loop(ws: WebSocket):
    """Send server-side ping every PING_INTERVAL_SEC."""
    try:
        while True:
            await asyncio.sleep(PING_INTERVAL_SEC)
            await ws.send_text(json.dumps({'type': 'ping'}))
    except Exception:
        pass


async def _broadcast_loop(ws: WebSocket, get_live_data_fn):
    """Fetch fresh data and push every BROADCAST_INTERVAL_SEC."""
    global _last_payload
    try:
        while True:
            await asyncio.sleep(BROADCAST_INTERVAL_SEC)
            try:
                data    = await asyncio.to_thread(get_live_data_fn)
                payload = json.dumps({'data': data})
                _last_payload = payload
                # Broadcast to ALL connected clients, not just this one
                dead: Set[WebSocket] = set()
                for conn in _connections.copy():
                    try:
                        await conn.send_text(payload)
                    except Exception:
                        dead.add(conn)
                _connections -= dead
            except Exception as e:
                logger.error(f'[WS] broadcast error: {e}')
    except asyncio.CancelledError:
        pass


async def push_update(data: list):
    """
    Call this from live_levels.py when new CWC data arrives to push
    on-demand (not waiting for the 45s timer).
    """
    global _last_payload
    if not _connections:
        return
    payload = json.dumps({'data': data})
    _last_payload = payload
    dead: Set[WebSocket] = set()
    for conn in _connections.copy():
        try:
            await conn.send_text(payload)
        except Exception:
            dead.add(conn)
    _connections -= dead
