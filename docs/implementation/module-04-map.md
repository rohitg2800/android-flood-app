# Module 4: Real-Time Flood Map & Location

## GitHub Branch
`feature/map-module` → PR → `develop`

## Flutter Structure

```
lib/features/map/
  models/
    flood_zone_model.dart
    water_level_model.dart
    station_model.dart
  screens/
    flood_map_screen.dart
    zone_detail_screen.dart
  bloc/
    map_bloc.dart
    map_event.dart
    map_state.dart
  repository/
    map_repository.dart
  widgets/
    flood_zone_overlay.dart
    water_level_marker.dart
    map_legend.dart
    station_info_card.dart
test/map/
```

## Implementation Steps

1. Integrate `google_maps_flutter` with custom map style
2. Overlay flood zones as coloured polygons from Neon DB (GeoJSON)
3. Render water level station markers with real-time readings
4. Implement geofencing: alert user on entering a flood zone
5. WebSocket connection for live water level updates
6. Offline map tiles caching for low-connectivity areas
7. Toggle layers: flood zones / evacuation routes / relief camps

## Neon DB Schema

```sql
-- Run on neon/dev branch
CREATE TABLE flood_zones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  zone_name TEXT NOT NULL,
  district TEXT,
  risk_level TEXT CHECK (risk_level IN ('safe', 'watch', 'warning', 'danger')),
  polygon_coordinates JSONB NOT NULL,  -- GeoJSON Polygon
  area_sq_km DECIMAL(10,3),
  population_at_risk INTEGER,
  last_updated TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE water_level_stations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  station_code TEXT UNIQUE NOT NULL,
  station_name TEXT NOT NULL,
  river_name TEXT,
  district TEXT,
  location_lat DECIMAL(9,6) NOT NULL,
  location_lng DECIMAL(9,6) NOT NULL,
  danger_level_m DECIMAL(5,2),
  warning_level_m DECIMAL(5,2),
  normal_level_m DECIMAL(5,2),
  is_active BOOLEAN DEFAULT true
);

CREATE TABLE water_level_readings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  station_id UUID REFERENCES water_level_stations(id),
  level_meters DECIMAL(5,2) NOT NULL,
  flow_rate DECIMAL(10,3),
  trend TEXT CHECK (trend IN ('rising', 'falling', 'steady')),
  recorded_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE evacuation_routes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  route_name TEXT NOT NULL,
  from_area TEXT,
  to_area TEXT,
  route_coordinates JSONB,  -- GeoJSON LineString
  distance_km DECIMAL(8,2),
  is_passable BOOLEAN DEFAULT true,
  last_checked TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_readings_station_time ON water_level_readings(station_id, recorded_at DESC);
CREATE INDEX idx_zones_district ON flood_zones(district);
```
