-- Module 4: Map - Flood Zones & Water Level Readings
CREATE TABLE IF NOT EXISTS flood_zones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  zone_name TEXT NOT NULL,
  risk_level TEXT CHECK (risk_level IN ('low','medium','high','critical')),
  polygon_coordinates JSONB NOT NULL,
  last_updated TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS water_level_readings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  station_name TEXT NOT NULL,
  location_lat DECIMAL(9,6) NOT NULL,
  location_lng DECIMAL(9,6) NOT NULL,
  level_meters DECIMAL(5,2) NOT NULL,
  recorded_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_zones_risk ON flood_zones(risk_level);
CREATE INDEX IF NOT EXISTS idx_water_station ON water_level_readings(station_name);
CREATE INDEX IF NOT EXISTS idx_water_recorded ON water_level_readings(recorded_at DESC);
