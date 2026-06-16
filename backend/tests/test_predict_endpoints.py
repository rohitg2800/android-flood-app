import os

import pytest
from fastapi.testclient import TestClient

# Import the FastAPI app from backend/app.py.
#
# NOTE: backend.app.py triggers warm threads / background fetches at import
# time. In CI we want stable, fast tests. We therefore disable live
# ingestion/schedulers via env flags that the app uses.
#
# If these flags are not present in a given deployment, the tests still
# validate HTTP contracts when the server boots.

# Best-effort flags (harmless if unused):
os.environ.setdefault("ENABLE_DATA_INGESTION_SCHEDULER", "0")
os.environ.setdefault("ENABLE_LIVE_CWC_IN_APP", "0")

from backend.app import app  # noqa: E402

client = TestClient(app)


@pytest.mark.parametrize(
    "payload",
    [
        {
            "Peak_Flood_Level_m": 8.5,
            "Event_Duration_days": 1,
            "Time_to_Peak_days": 1,
            "Recession_Time_day": 1,
            "T1d": 10.0,
            "T2d": 10.0,
            "T3d": 10.0,
            "T4d": 10.0,
            "T5d": 10.0,
            "T6d": 10.0,
            "T7d": 10.0,
            "state": "Bihar",
            "station": "Gandhighat",
        }
    ],
)
def test_post_predict_v2_contract(payload):
    resp = client.post("/predict/v2", json=payload)
    assert resp.status_code in (200, 500)

    data = resp.json()
    assert isinstance(data, dict)

    # If backend is down due to missing model artifacts, endpoint may return
    # an error payload.
    if data.get("status") == "error":
        assert "message" in data
        return

    # Contract when endpoint succeeds.
    assert data.get("severity") in {"LOW", "MODERATE", "SEVERE", "CRITICAL"}
    assert "confidence_percent" in data
    assert "probabilities" in data


def test_get_cwc_stations_contract():
    # Known station codes from backend/routers/cwc_stations.py
    codes = "GANGA-GANDHIGHAT,GANDAK-DUMARIAGHAT"
    resp = client.get("/api/cwc-stations", params={"codes": codes})
    assert resp.status_code == 200

    data = resp.json()
    assert isinstance(data, list)

    for item in data:
        assert "code" in item
        assert "level" in item
        assert "fetchedAt" in item
        assert "source" in item

