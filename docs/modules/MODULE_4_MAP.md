# Module 4: Real-Time Flood Map & Location

## GitHub Branch: `feature/map-module`

## Implementation Steps
1. Add `google_maps_flutter: ^2.x` to `pubspec.yaml`
2. Build `lib/features/map/flood_map_screen.dart` with:
   - Flood zone polygon overlays
   - Water level station markers
   - User location tracking
3. Pull water level data from Neon via REST API (polling every 60s)
4. Implement geofencing alerts when user enters flood zone
5. Cluster markers for performance on dense areas

## Folder Structure
```
lib/
  features/
    map/
      screens/
        flood_map_screen.dart
        zone_detail_screen.dart
      widgets/
        flood_zone_overlay.dart
        water_level_marker.dart
        station_info_sheet.dart
      services/
        location_service.dart
        geofence_service.dart
        map_repository.dart
      models/
        flood_zone_model.dart
        water_level_model.dart
```

## Neon DB Schema
```sql
CREATE TABLE flood_zones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  zone_name TEXT NOT NULL,
  risk_level TEXT CHECK (risk_level IN ('safe','watch','warning','danger')),
  polygon_coordinates JSONB NOT NULL,
  district TEXT,
  state TEXT DEFAULT 'Bihar',
  population_at_risk INTEGER,
  last_updated TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE water_level_stations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  station_name TEXT NOT NULL,
  river_name TEXT,
  location_lat DECIMAL(9,6) NOT NULL,
  location_lng DECIMAL(9,6) NOT NULL,
  danger_level_meters DECIMAL(5,2),
  warning_level_meters DECIMAL(5,2),
  is_active BOOLEAN DEFAULT true
);

CREATE TABLE water_level_readings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  station_id UUID REFERENCES water_level_stations(id),
  level_meters DECIMAL(5,2) NOT NULL,
  trend TEXT CHECK (trend IN ('rising','falling','stable')),
  recorded_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_readings_station_time ON water_level_readings(station_id, recorded_at DESC);
CREATE INDEX idx_zones_risk ON flood_zones(risk_level);
```

## Map Configuration
```dart
// Flood zone color mapping
const Map<String, Color> zoneColors = {
  'safe':    Color(0xFF4CAF50),
  'watch':   Color(0xFFFFEB3B),
  'warning': Color(0xFFFF9800),
  'danger':  Color(0xFFF44336),
};

// Zone fill opacity
const double zoneOpacity = 0.35;
```
