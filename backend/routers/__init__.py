# backend/routers/__init__.py
# Auto-registers all routers. Import this in app.py via:
#   from backend.routers import all_routers
#   for r in all_routers: app.include_router(r)

from backend.routers.core           import router as core_router
from backend.routers.predict        import router as predict_router
from backend.routers.live_levels    import router as live_levels_router
from backend.routers.wrd_bihar      import router as wrd_bihar_router
from backend.routers.cwc_ffs        import router as cwc_ffs_router
from backend.routers.cwc_stations   import router as cwc_stations_router
from backend.routers.data_gov_cwc   import router as data_gov_cwc_router
from backend.routers.glofas         import router as glofas_router
from backend.routers.fcm            import router as fcm_router
from backend.routers.rainfall       import router as rainfall_router
from backend.routers.weather        import router as weather_router
from backend.routers.ingestion      import router as ingestion_router
from backend.routers.telemetry      import router as telemetry_router
from backend.routers.news           import router as news_router
from backend.routers.model_artifacts import router as model_artifacts_router
from backend.routers.metrics        import router as metrics_router  # P3: /metrics endpoint

all_routers = [
    core_router,
    predict_router,
    live_levels_router,
    wrd_bihar_router,
    cwc_ffs_router,
    cwc_stations_router,
    data_gov_cwc_router,
    glofas_router,
    fcm_router,
    rainfall_router,
    weather_router,
    ingestion_router,
    telemetry_router,
    news_router,
    model_artifacts_router,
    metrics_router,  # P3
]
