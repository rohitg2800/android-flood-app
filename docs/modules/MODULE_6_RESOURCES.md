# Module 6: Resource & Relief Management

## GitHub Branch: `feature/resources-module`

## Implementation Steps
1. Build `lib/features/resources/` with:
   - Relief camps list + detail screen
   - Evacuation routes map layer
   - Resource inventory tracking
2. Admin panel features:
   - Add/edit/deactivate relief camps
   - Assign and track resources
   - Occupancy management
3. Citizen view:
   - Nearest relief camp with distance + directions
   - Filter by medical support, capacity, distance
4. Real-time occupancy updates via Neon

## Folder Structure
```
lib/
  features/
    resources/
      screens/
        relief_camps_screen.dart
        camp_detail_screen.dart
        evacuation_routes_screen.dart
        resource_inventory_screen.dart
        admin_camp_management_screen.dart
      bloc/
        resources_bloc.dart
      models/
        relief_camp_model.dart
        resource_model.dart
        evacuation_route_model.dart
      services/
        resources_repository.dart
      widgets/
        camp_card.dart
        capacity_indicator.dart
        resource_item_tile.dart
```

## Neon DB Schema
```sql
CREATE TABLE relief_camps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  address TEXT,
  district TEXT,
  latitude DECIMAL(9,6),
  longitude DECIMAL(9,6),
  capacity INTEGER NOT NULL,
  current_occupancy INTEGER DEFAULT 0,
  has_medical BOOLEAN DEFAULT false,
  has_food BOOLEAN DEFAULT false,
  has_water BOOLEAN DEFAULT false,
  contact_phone TEXT,
  managed_by UUID REFERENCES users(id),
  is_active BOOLEAN DEFAULT true,
  opened_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE resources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  camp_id UUID REFERENCES relief_camps(id) ON DELETE CASCADE,
  resource_type TEXT CHECK (resource_type IN ('food','water','medicine','blankets','boats','rescue_kit')),
  quantity INTEGER NOT NULL DEFAULT 0,
  unit TEXT,
  last_updated TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE evacuation_routes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  route_name TEXT,
  from_area TEXT,
  to_camp_id UUID REFERENCES relief_camps(id),
  route_polyline JSONB,
  distance_km DECIMAL(6,2),
  is_accessible BOOLEAN DEFAULT true,
  last_verified TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_camps_active ON relief_camps(is_active, district);
CREATE INDEX idx_camps_location ON relief_camps(latitude, longitude);
CREATE INDEX idx_resources_camp ON resources(camp_id, resource_type);
```

## Capacity Calculation
```dart
// Availability percentage
double get availabilityPercent =>
    ((capacity - currentOccupancy) / capacity * 100).clamp(0, 100);

// Status label
String get statusLabel {
  if (availabilityPercent > 50) return 'Available';
  if (availabilityPercent > 20) return 'Filling Up';
  if (availabilityPercent > 0)  return 'Almost Full';
  return 'Full';
}
```
