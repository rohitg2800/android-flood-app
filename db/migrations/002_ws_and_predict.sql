-- Migration 002: WebSocket feed + ML predict DB setup
-- Applies to: equinox-bh / neondb
-- Issues: #45 (WebSocket water level feed), #47 (ML predict endpoint)
-- Applied: 2026-07-05

-- ── #45: NOTIFY trigger on water_level_readings ───────────────────────────────
CREATE OR REPLACE FUNCTION notify_water_level_insert()
RETURNS trigger LANGUAGE plpgsql AS
'BEGIN
  PERFORM pg_notify(
    ''water_level_channel'',
    json_build_object(
      ''id'',           NEW.id,
      ''station_name'', NEW.station_name,
      ''zone_id'',      NEW.zone_id,
      ''level_meters'', NEW.level_meters,
      ''source'',       NEW.source,
      ''recorded_at'',  NEW.recorded_at
    )::text
  );
  RETURN NEW;
END;';

DROP TRIGGER IF EXISTS trg_water_level_notify ON water_level_readings;
CREATE TRIGGER trg_water_level_notify
  AFTER INSERT ON water_level_readings
  FOR EACH ROW EXECUTE FUNCTION notify_water_level_insert();

-- ── #45: Index for efficient station history queries ─────────────────────────
CREATE INDEX IF NOT EXISTS idx_wlr_station_recorded
  ON water_level_readings (station_name, recorded_at DESC);

-- ── #47: Index for GET /predict/latest?station_name= ─────────────────────────
CREATE INDEX IF NOT EXISTS idx_predictions_station_created
  ON predictions (station_name, created_at DESC);

-- ── #47: Confidence range constraint (0–100 scale) ───────────────────────────
ALTER TABLE predictions
  ADD CONSTRAINT chk_confidence_range
  CHECK (confidence_percent BETWEEN 0.0 AND 100.0);
