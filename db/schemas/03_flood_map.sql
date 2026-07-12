-- Module 4: Real-Time Flood Map & Location
-- Neon PostgreSQL Schema

CREATE TABLE IF NOT EXISTS flood_zones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  zone_name TEXT NOT NULL,
  risk_level TEXT CHECK (risk_level IN ('low', 'medium', 'high', 'critical')),
  polygon_coordinates JSONB,  -- GeoJSON polygon
  district TEXT,
  state TEXT DEFAULT 'Bihar',
  last_updated TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS water_level_readings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  station_name TEXT NOT NULL,
  station_code TEXT,
  location_lat DECIMAL(9,6),
  location_lng DECIMAL(9,6),
  level_meters DECIMAL(5,2),
  danger_level DECIMAL(5,2),
  warning_level DECIMAL(5,2),
  recorded_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_water_station ON water_level_readings(station_code);
CREATE INDEX IF NOT EXISTS idx_water_recorded ON water_level_readings(recorded_at DESC);
