# Module 4: Real-Time Flood Map & Location

## GitHub Branch: `feature/map-module`

## Flutter Implementation Steps
1. Add dependency: `google_maps_flutter: ^2.9.0`
2. Create folder: `lib/features/map/`
   - `flood_map_screen.dart`
   - `map_bloc.dart`
   - `flood_zone_model.dart`
   - `water_level_marker.dart`
3. Draw flood zone polygon overlays from Neon JSONB GeoJSON data
4. Add water level markers with color-coded severity
5. Implement geofencing: notify user if they enter a flood zone
6. Stream water level updates via WebSocket

## Neon DB Schema
```sql
CREATE TABLE IF NOT EXISTS flood_zones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  zone_name TEXT NOT NULL,
  risk_level TEXT CHECK (risk_level IN ('safe','low','medium','high','critical')),
  district TEXT,
  state TEXT DEFAULT 'Bihar',
  polygon_coordinates JSONB NOT NULL, -- GeoJSON Polygon
  area_sq_km DECIMAL(10,2),
  affected_population INTEGER DEFAULT 0,
  last_updated TIMESTAMPTZ DEFAULT now(),
  is_active BOOLEAN DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_zones_district ON flood_zones(district);
CREATE INDEX IF NOT EXISTS idx_zones_risk ON flood_zones(risk_level);

CREATE TABLE IF NOT EXISTS water_level_readings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  station_id TEXT NOT NULL,
  station_name TEXT NOT NULL,
  river_name TEXT,
  location_lat DECIMAL(9,6) NOT NULL,
  location_lng DECIMAL(9,6) NOT NULL,
  level_meters DECIMAL(5,2) NOT NULL,
  danger_level_meters DECIMAL(5,2),
  warning_level_meters DECIMAL(5,2),
  is_above_danger BOOLEAN GENERATED ALWAYS AS (level_meters >= danger_level_meters) STORED,
  recorded_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_water_station ON water_level_readings(station_id);
CREATE INDEX IF NOT EXISTS idx_water_recorded ON water_level_readings(recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_water_danger ON water_level_readings(is_above_danger);
```

## Google Maps Setup (AndroidManifest.xml)
```xml
<meta-data
  android:name="com.google.android.geo.API_KEY"
  android:value="${GOOGLE_MAPS_API_KEY}"/>
```
