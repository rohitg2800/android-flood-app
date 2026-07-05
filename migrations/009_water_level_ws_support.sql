-- Migration 009: WebSocket water level feed support
-- Issue #45 — adds NOTIFY trigger, status column, flow_rate column, and station index
-- Safe to run multiple times (idempotent)

-- 1. Add status column (Normal/Warning/Danger/Critical) if not present
ALTER TABLE water_level_readings
  ADD COLUMN IF NOT EXISTS status TEXT
    CHECK (status IN ('Normal', 'Warning', 'Danger', 'Critical'))
    DEFAULT 'Normal';

-- 2. Add flow_rate column if not present
ALTER TABLE water_level_readings
  ADD COLUMN IF NOT EXISTS flow_rate DOUBLE PRECISION;

-- 3. Index on station_name + recorded_at DESC for efficient history queries
CREATE INDEX IF NOT EXISTS idx_wlr_station_time
  ON water_level_readings (station_name, recorded_at DESC);

-- 4. NOTIFY trigger function
CREATE OR REPLACE FUNCTION notify_water_level_insert()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM pg_notify(
    'water_level_channel',
    json_build_object(
      'station_name', NEW.station_name,
      'level_meters', NEW.level_meters,
      'flow_rate',    NEW.flow_rate,
      'status',       NEW.status,
      'recorded_at',  NEW.recorded_at
    )::text
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Attach trigger on INSERT
DROP TRIGGER IF EXISTS trg_water_level_notify ON water_level_readings;
CREATE TRIGGER trg_water_level_notify
  AFTER INSERT ON water_level_readings
  FOR EACH ROW EXECUTE FUNCTION notify_water_level_insert();
