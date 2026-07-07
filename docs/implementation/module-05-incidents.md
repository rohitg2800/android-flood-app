# Module 5: Incident Reporting & Field Agent Tools

## GitHub Branch
`feature/incident-module` → PR → `develop`

## Flutter Structure

```
lib/features/incidents/
  models/
    incident_model.dart
    incident_update_model.dart
  screens/
    incident_list_screen.dart
    incident_detail_screen.dart
    report_incident_screen.dart
    field_agent_dashboard.dart
  bloc/
    incident_bloc.dart
    incident_event.dart
    incident_state.dart
  repository/
    incident_repository.dart
    local_incident_cache.dart   # SQLite offline cache
  widgets/
    incident_card.dart
    photo_picker_widget.dart
    status_timeline.dart
test/incidents/
```

## Implementation Steps

1. Build incident report form with GPS auto-tagging
2. Photo upload (up to 5 images) → Firebase Storage → store URLs in Neon
3. Offline-first: cache reports in local SQLite, sync when online
4. Field Agent dashboard: assigned incidents, update status, route to incident
5. Status workflow: `open` → `assigned` → `in_progress` → `resolved`
6. Priority scoring based on severity + location + population density

## Neon DB Schema

```sql
-- Run on neon/dev branch
CREATE TABLE incidents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reported_by UUID REFERENCES users(id),
  assigned_to UUID REFERENCES users(id),
  title TEXT NOT NULL,
  description TEXT,
  category TEXT CHECK (category IN ('flooding', 'road_blocked', 'building_damage', 'rescue_needed', 'other')),
  status TEXT CHECK (status IN ('open', 'assigned', 'in_progress', 'resolved', 'closed')) DEFAULT 'open',
  priority INTEGER DEFAULT 3 CHECK (priority BETWEEN 1 AND 5),
  latitude DECIMAL(9,6) NOT NULL,
  longitude DECIMAL(9,6) NOT NULL,
  area_name TEXT,
  district TEXT,
  image_urls JSONB DEFAULT '[]',
  people_affected INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  resolved_at TIMESTAMPTZ
);

CREATE TABLE incident_updates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id UUID REFERENCES incidents(id) ON DELETE CASCADE,
  updated_by UUID REFERENCES users(id),
  status_from TEXT,
  status_to TEXT,
  note TEXT,
  image_urls JSONB DEFAULT '[]',
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_incidents_status ON incidents(status);
CREATE INDEX idx_incidents_assigned ON incidents(assigned_to);
CREATE INDEX idx_incidents_district ON incidents(district);
CREATE INDEX idx_incidents_priority ON incidents(priority DESC, created_at DESC);
```

## Offline Sync Strategy

```dart
// Local SQLite schema (drift/sqflite)
// Cache unsynced reports locally
// On connectivity restored: POST to API, delete local cache entry
Future<void> syncPendingIncidents() async {
  final pending = await localDb.getUnsynced();
  for (final incident in pending) {
    try {
      await apiService.createIncident(incident);
      await localDb.markSynced(incident.localId);
    } catch (e) {
      // Retry on next sync
    }
  }
}
```
