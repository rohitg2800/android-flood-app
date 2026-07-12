# Module 5: Incident Reporting & Field Agent Tools

## GitHub Branch: `feature/incident-module`

## Implementation Steps
1. Create `lib/features/incidents/` with:
   - Report form with photo upload + GPS tagging
   - Offline-first with local SQLite cache
   - Sync to Neon when connectivity restored
2. Build Field Agent dashboard:
   - Assigned incidents list
   - Status update flow
   - Navigation to incident location
3. Image upload to Firebase Storage → store URL in Neon
4. Background sync service for offline reports

## Folder Structure
```
lib/
  features/
    incidents/
      screens/
        incident_list_screen.dart
        incident_detail_screen.dart
        report_incident_screen.dart
        field_agent_dashboard.dart
      bloc/
        incident_bloc.dart
        incident_event.dart
        incident_state.dart
      models/
        incident_model.dart
      services/
        incident_repository.dart
        image_upload_service.dart
        offline_sync_service.dart
      widgets/
        incident_card.dart
        status_stepper.dart
        photo_picker_widget.dart
```

## Neon DB Schema
```sql
CREATE TABLE incidents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reported_by UUID REFERENCES users(id),
  assigned_to UUID REFERENCES users(id),
  title TEXT NOT NULL,
  description TEXT,
  category TEXT CHECK (category IN ('flood','landslide','infrastructure','medical','rescue')),
  status TEXT CHECK (status IN ('open','assigned','in_progress','resolved','closed')),
  priority TEXT CHECK (priority IN ('low','medium','high','critical')) DEFAULT 'medium',
  latitude DECIMAL(9,6),
  longitude DECIMAL(9,6),
  address TEXT,
  image_urls JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  resolved_at TIMESTAMPTZ
);

CREATE TABLE incident_updates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id UUID REFERENCES incidents(id) ON DELETE CASCADE,
  updated_by UUID REFERENCES users(id),
  old_status TEXT,
  new_status TEXT,
  note TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_incidents_status ON incidents(status, created_at DESC);
CREATE INDEX idx_incidents_assigned ON incidents(assigned_to, status);
CREATE INDEX idx_incidents_location ON incidents(latitude, longitude);
```

## Offline Sync Strategy
```dart
// Connectivity-aware sync
class OfflineSyncService {
  // 1. Store reports in local SQLite when offline
  // 2. Monitor connectivity using connectivity_plus package
  // 3. On reconnect, push queued reports to Neon API
  // 4. Resolve conflicts: server wins for existing records
  // 5. Mark synced records in local DB
}
```
