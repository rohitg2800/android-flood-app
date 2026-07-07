-- Module 3: Flood Map & Location Schema
-- Neon DB Migration: 03_map_schema.sql
-- Branch: feature/map-module

CREATE TABLE IF NOT EXISTS flood_zones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  zone_name TEXT NOT NULL,
  risk_level TEXT NOT NULL CHECK (risk_level IN ('safe', 'low', 'medium', 'high', 'critical')),
  polygon_coordinates JSONB NOT NULL, -- GeoJSON Polygon
  district TEXT,
  state TEXT DEFAULT 'Bihar',
  last_updated TIMESTAMPTZ DEFAULT now(),
  is_active BOOLEAN DEFAULT true
);

CREATE TABLE IF NOT EXISTS water_level_stations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  station_name TEXT NOT NULL,
  station_code TEXT UNIQUE,
  river_name TEXT,
  location_lat DECIMAL(9,6) NOT NULL,
  location_lng DECIMAL(9,6) NOT NULL,
  danger_level DECIMAL(5,2),
  warning_level DECIMAL(5,2),
  is_active BOOLEAN DEFAULT true
);

CREATE TABLE IF NOT EXISTS water_level_readings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  station_id UUID REFERENCES water_level_stations(id) ON DELETE CASCADE,
  level_meters DECIMAL(6,3) NOT NULL,
  discharge_cumecs DECIMAL(10,2),
  trend TEXT CHECK (trend IN ('rising', 'falling', 'steady')),
  recorded_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_readings_station ON water_level_readings(station_id);
CREATE INDEX IF NOT EXISTS idx_readings_time ON water_level_readings(recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_zones_risk ON flood_zones(risk_level);
