-- Module 4: Real-Time Flood Map & Location Schema
-- Branch: feature/map-module
-- Created: 2026-07-07

CREATE TABLE IF NOT EXISTS flood_zones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  zone_name TEXT NOT NULL,
  district TEXT,
  state TEXT DEFAULT 'Bihar',
  risk_level TEXT CHECK (risk_level IN ('low', 'medium', 'high', 'critical')),
  polygon_coordinates JSONB NOT NULL, -- GeoJSON Polygon
  color_hex TEXT,
  is_active BOOLEAN DEFAULT true,
  last_updated TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS water_level_stations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  station_name TEXT NOT NULL,
  river_name TEXT,
  location_lat DECIMAL(9,6) NOT NULL,
  location_lng DECIMAL(9,6) NOT NULL,
  danger_level_meters DECIMAL(6,2),
  warning_level_meters DECIMAL(6,2),
  normal_level_meters DECIMAL(6,2),
  is_active BOOLEAN DEFAULT true
);

CREATE TABLE IF NOT EXISTS water_level_readings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  station_id UUID REFERENCES water_level_stations(id) ON DELETE CASCADE,
  level_meters DECIMAL(6,2) NOT NULL,
  discharge_cumecs DECIMAL(10,2),
  recorded_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_readings_station_time ON water_level_readings(station_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_zones_risk ON flood_zones(risk_level);

-- Latest reading view for map markers
CREATE OR REPLACE VIEW latest_water_levels AS
SELECT DISTINCT ON (station_id)
  r.station_id,
  s.station_name,
  s.river_name,
  s.location_lat,
  s.location_lng,
  r.level_meters,
  s.danger_level_meters,
  CASE
    WHEN r.level_meters >= s.danger_level_meters THEN 'danger'
    WHEN r.level_meters >= s.warning_level_meters THEN 'warning'
    ELSE 'normal'
  END AS status,
  r.recorded_at
FROM water_level_readings r
JOIN water_level_stations s ON s.id = r.station_id
ORDER BY station_id, recorded_at DESC;
