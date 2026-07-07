# Module 6: Resource & Relief Management

## GitHub Branch: `feature/resources-module`

## Flutter Implementation Steps
1. Create folder: `lib/features/resources/`
   - `relief_camp_model.dart`
   - `relief_camps_screen.dart`
   - `camp_detail_screen.dart`
   - `resource_inventory_screen.dart`
   - `evacuation_routes_screen.dart`
   - `resources_bloc.dart`
   - `resources_repository.dart`
2. Citizen view: nearest relief camp (sorted by distance using Haversine formula)
3. Admin panel: add/edit camps, update occupancy, manage resources
4. Search/filter: by distance, capacity available, medical support available
5. Show evacuation routes on Google Maps

## Neon DB Schema
```sql
CREATE TABLE IF NOT EXISTS relief_camps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  address TEXT,
  latitude DECIMAL(9,6) NOT NULL,
  longitude DECIMAL(9,6) NOT NULL,
  district TEXT,
  state TEXT DEFAULT 'Bihar',
  capacity INTEGER NOT NULL DEFAULT 0,
  current_occupancy INTEGER DEFAULT 0,
  available_capacity INTEGER GENERATED ALWAYS AS (capacity - current_occupancy) STORED,
  has_medical BOOLEAN DEFAULT false,
  has_food BOOLEAN DEFAULT true,
  has_water BOOLEAN DEFAULT true,
  has_electricity BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  contact_phone TEXT,
  managed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_camps_district ON relief_camps(district);
CREATE INDEX IF NOT EXISTS idx_camps_active ON relief_camps(is_active);
CREATE INDEX IF NOT EXISTS idx_camps_medical ON relief_camps(has_medical);

CREATE TABLE IF NOT EXISTS resources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  camp_id UUID REFERENCES relief_camps(id) ON DELETE CASCADE,
  resource_type TEXT CHECK (resource_type IN ('food','water','medicine','clothing','blankets','boats','rescue_equipment','other')),
  quantity INTEGER NOT NULL DEFAULT 0,
  unit TEXT DEFAULT 'units',
  last_updated TIMESTAMPTZ DEFAULT now(),
  updated_by UUID REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS evacuation_routes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  from_area TEXT,
  to_camp_id UUID REFERENCES relief_camps(id) ON DELETE SET NULL,
  route_coordinates JSONB, -- GeoJSON LineString
  distance_km DECIMAL(6,2),
  is_safe BOOLEAN DEFAULT true,
  last_verified TIMESTAMPTZ DEFAULT now()
);
```

## Distance Query (Haversine in SQL)
```sql
-- Find nearest 5 active camps to a user location
SELECT *,
  (6371 * acos(
    cos(radians($1)) * cos(radians(latitude)) *
    cos(radians(longitude) - radians($2)) +
    sin(radians($1)) * sin(radians(latitude))
  )) AS distance_km
FROM relief_camps
WHERE is_active = true AND available_capacity > 0
ORDER BY distance_km
LIMIT 5;
```
