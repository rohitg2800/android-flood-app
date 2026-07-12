import os
from contextlib import contextmanager
from typing import Any, Dict, Iterator, List, Optional


try:
    import psycopg
    from psycopg.rows import dict_row
    from psycopg.types.json import Jsonb
except ImportError:  # pragma: no cover - optional until dependency is installed
    psycopg = None
    dict_row = None
    Jsonb = None



SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS predictions (
    id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    state_name TEXT NOT NULL,
    city_name TEXT,
    station_name TEXT,
    peak_level_m DOUBLE PRECISION NOT NULL,
    rainfall_total_mm DOUBLE PRECISION NOT NULL,
    severity TEXT NOT NULL,
    confidence_percent DOUBLE PRECISION NOT NULL,
    risk_score INTEGER,
    data_source TEXT,
    algorithm TEXT,
    model_version TEXT,
    monitoring_level TEXT,
    monitoring_action TEXT,
    source_policy_mode TEXT,
    source_policy_label TEXT,
    input_payload JSONB NOT NULL,
    prediction_payload JSONB NOT NULL
);


CREATE INDEX IF NOT EXISTS idx_predictions_created_at ON predictions (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_predictions_state_station ON predictions (state_name, station_name, created_at DESC);


CREATE TABLE IF NOT EXISTS telemetry_snapshots (
    id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    state_name TEXT NOT NULL,
    station_name TEXT,
    request_limit INTEGER,
    snapshot_status TEXT,
    data_source TEXT,
    source_policy_mode TEXT,
    node_count INTEGER NOT NULL DEFAULT 0,
    payload JSONB NOT NULL
);


CREATE INDEX IF NOT EXISTS idx_telemetry_snapshots_created_at ON telemetry_snapshots (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_telemetry_snapshots_state_station ON telemetry_snapshots (state_name, station_name, created_at DESC);


CREATE TABLE IF NOT EXISTS station_snapshots (
    id              SERIAL PRIMARY KEY,
    station         TEXT NOT NULL,
    river           TEXT,
    district        TEXT,
    level_m         FLOAT,
    danger_level_m  FLOAT,
    warning_level_m FLOAT,
    status          TEXT,
    change_24h_m    FLOAT,
    source          TEXT,
    recorded_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS flood_alerts (
    id              SERIAL PRIMARY KEY,
    station         TEXT NOT NULL,
    river           TEXT,
    district        TEXT,
    severity        TEXT,
    level_m         FLOAT,
    danger_level_m  FLOAT,
    alert_type      TEXT,
    message         TEXT,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    resolved_at     TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS audit_logs (
    id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    event_type TEXT NOT NULL,
    route TEXT NOT NULL,
    event_status TEXT NOT NULL,
    state_name TEXT,
    station_name TEXT,
    severity TEXT,
    details JSONB NOT NULL
);


CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_route_event ON audit_logs (route, event_type, created_at DESC);
"""



class PostgresOperationalStore:
    def __init__(self):
        self.database_url = (os.getenv("DATABASE_URL") or "").strip()
        self.enabled = bool(self.database_url)
        self.driver_available = psycopg is not None
        self.ready = False
        self.last_error: Optional[str] = None


    @property
    def configured(self) -> bool:
        return self.enabled


    @contextmanager
    def connection(self) -> Iterator[Any]:
        if not self.enabled:
            raise RuntimeError("DATABASE_URL is not configured.")
        if not self.driver_available or psycopg is None or dict_row is None:
            raise RuntimeError("psycopg is not installed.")


        connection = psycopg.connect(self.database_url, row_factory=dict_row)
        try:
            yield connection
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()


    def initialize(self) -> Dict[str, Any]:
        if not self.enabled:
            self.ready = False
            self.last_error = None
            return self.status()


        if not self.driver_available:
            self.ready = False
            self.last_error = "psycopg dependency is unavailable."
            return self.status()


        try:
            with self.connection() as conn:
                with conn.cursor() as cur:
                    cur.execute(SCHEMA_SQL)
            self.ready = True
            self.last_error = None
        except Exception as exc:
            self.ready = False
            self.last_error = str(exc)
        return self.status()


    def status(self) -> Dict[str, Any]:
        if not self.enabled:
            return {
                "backend": "postgresql",
                "configured": False,
                "ready": False,
                "message": "DATABASE_URL is not configured.",
            }


        if not self.driver_available:
            return {
                "backend": "postgresql",
                "configured": True,
                "ready": False,
                "message": "psycopg dependency is unavailable.",
            }


        return {
            "backend": "postgresql",
            "configured": True,
            "ready": self.ready,
            "message": self.last_error or ("ready" if self.ready else "initializing"),
        }


    def _jsonb(self, payload: Dict[str, Any]) -> Any:
        if Jsonb is None:
            raise RuntimeError("psycopg JSON adapter is unavailable.")
        return Jsonb(payload)


    def save_prediction(self, payload: Dict[str, Any]) -> Optional[int]:
        if not self.ready:
            return None


        with self.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO predictions (
                        state_name,
                        city_name,
                        station_name,
                        peak_level_m,
                        rainfall_total_mm,
                        severity,
                        confidence_percent,
                        risk_score,
                        data_source,
                        algorithm,
                        model_version,
                        monitoring_level,
                        monitoring_action,
                        source_policy_mode,
                        source_policy_label,
                        input_payload,
                        prediction_payload
                    )
                    VALUES (
                        %(state_name)s,
                        %(city_name)s,
                        %(station_name)s,
                        %(peak_level_m)s,
                        %(rainfall_total_mm)s,
                        %(severity)s,
                        %(confidence_percent)s,
                        %(risk_score)s,
                        %(data_source)s,
                        %(algorithm)s,
                        %(model_version)s,
                        %(monitoring_level)s,
                        %(monitoring_action)s,
                        %(source_policy_mode)s,
                        %(source_policy_label)s,
                        %(input_payload)s,
                        %(prediction_payload)s
                    )
                    RETURNING id
                    """,
                    {
                        **payload,
                        "input_payload": self._jsonb(payload["input_payload"]),
                        "prediction_payload": self._jsonb(payload["prediction_payload"]),
                    },
                )
                row = cur.fetchone()
                return int(row["id"]) if row else None


    def save_telemetry_snapshot(self, payload: Dict[str, Any]) -> Optional[int]:
        if not self.ready:
            return None


        with self.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO telemetry_snapshots (
                        state_name,
                        station_name,
                        request_limit,
                        snapshot_status,
                        data_source,
                        source_policy_mode,
                        node_count,
                        payload
                    )
                    VALUES (
                        %(state_name)s,
                        %(station_name)s,
                        %(request_limit)s,
                        %(snapshot_status)s,
                        %(data_source)s,
                        %(source_policy_mode)s,
                        %(node_count)s,
                        %(payload)s
                    )
                    RETURNING id
                    """,
                    {
                        **payload,
                        "payload": self._jsonb(payload["payload"]),
                    },
                )
                row = cur.fetchone()
                return int(row["id"]) if row else None


    def save_audit_log(self, payload: Dict[str, Any]) -> Optional[int]:
        if not self.ready:
            return None


        with self.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO audit_logs (
                        event_type,
                        route,
                        event_status,
                        state_name,
                        station_name,
                        severity,
                        details
                    )
                    VALUES (
                        %(event_type)s,
                        %(route)s,
                        %(event_status)s,
                        %(state_name)s,
                        %(station_name)s,
                        %(severity)s,
                        %(details)s
                    )
                    RETURNING id
                    """,
                    {
                        **payload,
                        "details": self._jsonb(payload["details"]),
                    },
                )
                row = cur.fetchone()
                return int(row["id"]) if row else None


    def save_station_snapshot(self, stations: list) -> int:
        """Save WRD Bihar station snapshots to DB."""
        if not stations: return 0
        try:
            with self._connect() as conn:
                with conn.cursor() as cur:
                    count = 0
                    for s in stations:
                        cur.execute("""
                            INSERT INTO station_snapshots
                                (station, river, district, level_m, danger_level_m,
                                 warning_level_m, status, change_24h_m, source)
                            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)
                        """, (
                            s.get('station'), s.get('river'), s.get('district'),
                            s.get('current_level_m'), s.get('danger_level_m'),
                            s.get('yesterday_level_m'), s.get('status'),
                            s.get('change_24h_m'), s.get('source','WRD_BIHAR')
                        ))
                        count += 1
                    conn.commit()
                    return count
        except Exception as e:
            self.last_error = str(e)
            return 0

    def save_flood_alert(self, payload: dict) -> bool:
        """Save a flood alert event to DB."""
        try:
            with self._connect() as conn:
                with conn.cursor() as cur:
                    cur.execute("""
                        INSERT INTO flood_alerts
                            (station, river, district, severity, level_m,
                             danger_level_m, alert_type, message)
                        VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
                    """, (
                        payload.get('station'), payload.get('river'),
                        payload.get('district'), payload.get('severity'),
                        payload.get('level_m'), payload.get('danger_level_m'),
                        payload.get('alert_type','THRESHOLD'), payload.get('message','')
                    ))
                    conn.commit()
                    return True
        except Exception as e:
            self.last_error = str(e)
            return False

    def list_station_snapshots(self, station: str = None, limit: int = 100) -> list:
        """Get recent station snapshots."""
        try:
            with self._connect() as conn:
                with conn.cursor() as cur:
                    if station:
                        cur.execute(
                            "SELECT * FROM station_snapshots WHERE station=%s ORDER BY recorded_at DESC LIMIT %s",
                            (station, limit))
                    else:
                        cur.execute(
                            "SELECT * FROM station_snapshots ORDER BY recorded_at DESC LIMIT %s",
                            (limit,))
                    return cur.fetchall()
        except Exception as e:
            self.last_error = str(e)
            return []

    def list_flood_alerts(self, active_only: bool = True, limit: int = 50) -> list:
        """Get flood alerts."""
        try:
            with self._connect() as conn:
                with conn.cursor() as cur:
                    if active_only:
                        cur.execute(
                            "SELECT * FROM flood_alerts WHERE is_active=TRUE ORDER BY created_at DESC LIMIT %s",
                            (limit,))
                    else:
                        cur.execute(
                            "SELECT * FROM flood_alerts ORDER BY created_at DESC LIMIT %s",
                            (limit,))
                    return cur.fetchall()
        except Exception as e:
            self.last_error = str(e)
            return []

    def list_predictions(self, *, limit: int = 100, state_name: Optional[str] = None, station_name: Optional[str] = None) -> List[Dict[str, Any]]:
        if not self.ready:
            return []


        where_clauses = []
        params: Dict[str, Any] = {"limit": max(1, min(limit, 500))}


        if state_name:
            where_clauses.append("state_name = %(state_name)s")
            params["state_name"] = state_name
        if station_name:
            where_clauses.append("(station_name = %(station_name)s OR city_name = %(station_name)s)")
            params["station_name"] = station_name


        where_sql = f"WHERE {' AND '.join(where_clauses)}" if where_clauses else ""


        with self.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    f"""
                    SELECT
                        id,
                        created_at,
                        state_name,
                        city_name,
                        station_name,
                        peak_level_m,
                        rainfall_total_mm,
                        severity,
                        confidence_percent,
                        risk_score,
                        data_source,
                        algorithm,
                        model_version,
                        monitoring_level,
                        monitoring_action,
                        source_policy_mode,
                        source_policy_label
                    FROM predictions
                    {where_sql}
                    ORDER BY created_at DESC
                    LIMIT %(limit)s
                    """,
                    params,
                )
                return list(cur.fetchall())


    def list_telemetry_snapshots(self, *, limit: int = 50, state_name: Optional[str] = None, station_name: Optional[str] = None) -> List[Dict[str, Any]]:
        if not self.ready:
            return []


        where_clauses = []
        params: Dict[str, Any] = {"limit": max(1, min(limit, 500))}


        if state_name:
            where_clauses.append("state_name = %(state_name)s")
            params["state_name"] = state_name
        if station_name:
            where_clauses.append("station_name = %(station_name)s")
            params["station_name"] = station_name


        where_sql = f"WHERE {' AND '.join(where_clauses)}" if where_clauses else ""


        with self.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    f"""
                    SELECT
                        id,
                        created_at,
                        state_name,
                        station_name,
                        request_limit,
                        snapshot_status,
                        data_source,
                        source_policy_mode,
                        node_count
                    FROM telemetry_snapshots
                    {where_sql}
                    ORDER BY created_at DESC
                    LIMIT %(limit)s
                    """,
                    params,
                )
                return list(cur.fetchall())


    def list_audit_logs(self, *, limit: int = 50) -> List[Dict[str, Any]]:
        if not self.ready:
            return []


        with self.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT
                        id,
                        created_at,
                        event_type,
                        route,
                        event_status,
                        state_name,
                        station_name,
                        severity
                    FROM audit_logs
                    ORDER BY created_at DESC
                    LIMIT %(limit)s
                    """,
                    {"limit": max(1, min(limit, 500))},
                )
                return list(cur.fetchall())
            