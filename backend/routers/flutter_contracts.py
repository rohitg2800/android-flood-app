# backend/routers/flutter_contracts.py
# Flutter app contract endpoints — shapes expected by the Flutter client.

from fastapi import APIRouter
from .wrd_bihar import stations_all_v1

router = APIRouter(prefix="/api/v1", tags=["Flutter Contracts"])


@router.get("/stations/all", summary="All Bihar stations (Flutter IndiaStationsService)")
async def flutter_stations_all():
    """Alias to wrd_bihar stations_all_v1 in the shape Flutter expects."""
    return await stations_all_v1()
