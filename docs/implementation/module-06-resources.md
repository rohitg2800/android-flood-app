# Module 6: Resource & Relief Management

## GitHub Branch
`feature/resources-module` → PR → `develop`

## Flutter Structure

```
lib/features/resources/
  models/
    relief_camp_model.dart
    resource_model.dart
    evacuation_route_model.dart
  screens/
    relief_camps_screen.dart
    camp_detail_screen.dart
    resource_inventory_screen.dart  # admin only
    nearest_camp_screen.dart
  bloc/
    resources_bloc.dart
    resources_event.dart
    resources_state.dart
  repository/
    resources_repository.dart
  widgets/
    camp_card.dart
    capacity_bar.dart
    resource_item_tile.dart
test/resources/
```

## Implementation Steps

1. Citizen view: list nearest relief camps sorted by distance
2. Camp detail: capacity, occupancy bar, facilities, contact number
3. Get directions to camp via Google Maps deep link
4. Admin: add/edit/deactivate camps and update resource inventory
5. Filter camps by: distance, medical facility, capacity available
6. Real-time occupancy updates via WebSocket

## Neon DB Schema

```sql
-- Run on neon/dev branch
CREATE TABLE relief_camps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  address TEXT,
  district TEXT NOT NULL,
  latitude DECIMAL(9,6) NOT NULL,
  longitude DECIMAL(9,6) NOT NULL,
  capacity INTEGER NOT NULL,
  current_occupancy INTEGER DEFAULT 0,
  has_medical BOOLEAN DEFAULT false,
  has_food BOOLEAN DEFAULT true,
  has_water BOOLEAN DEFAULT true,
  has_electricity BOOLEAN DEFAULT false,
  contact_phone TEXT,
  contact_person TEXT,
  managed_by UUID REFERENCES users(id),
  is_active BOOLEAN DEFAULT true,
  opened_at TIMESTAMPTZ DEFAULT now(),
  closed_at TIMESTAMPTZ
);

CREATE TABLE resources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  camp_id UUID REFERENCES relief_camps(id) ON DELETE CASCADE,
  resource_type TEXT CHECK (resource_type IN ('food', 'water', 'medicine', 'blanket', 'boat', 'generator', 'other')),
  resource_name TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  unit TEXT DEFAULT 'units',
  last_updated TIMESTAMPTZ DEFAULT now(),
  updated_by UUID REFERENCES users(id)
);

CREATE TABLE resource_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  camp_id UUID REFERENCES relief_camps(id),
  resource_type TEXT NOT NULL,
  quantity_needed INTEGER NOT NULL,
  urgency TEXT CHECK (urgency IN ('low', 'medium', 'high', 'critical')) DEFAULT 'medium',
  status TEXT CHECK (status IN ('pending', 'approved', 'dispatched', 'received')) DEFAULT 'pending',
  requested_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_camps_district ON relief_camps(district);
CREATE INDEX idx_camps_active ON relief_camps(is_active);
CREATE INDEX idx_resources_camp ON resources(camp_id);
```
