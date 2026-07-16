import asyncio
import json
import os

import psycopg

from services.water_level_ws_service import water_level_ws_manager

DATABASE_URL = os.getenv("DATABASE_URL")


async def start_water_level_listener() -> None:
    if not DATABASE_URL:
        print("[water-level-listener] DATABASE_URL missing; listener disabled")
        return

    async with await psycopg.AsyncConnection.connect(DATABASE_URL) as conn:
        await conn.execute("LISTEN water_level_channel;")
        print("[water-level-listener] listening on water_level_channel")

        while True:
            notify = await conn.notifies().get()
            try:
                payload = json.loads(notify.payload)
                await water_level_ws_manager.broadcast_reading(payload)
            except Exception as exc:
                print(f"[water-level-listener] payload error: {exc}")
