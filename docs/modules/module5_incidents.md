# Module 5: Incident Reporting & Field Agent Tools

## GitHub Branch: `feature/incident-module`

## Flutter Implementation Steps
1. Create folder: `lib/features/incidents/`
   - `incident_model.dart`
   - `report_incident_screen.dart`
   - `incident_list_screen.dart`
   - `incident_detail_screen.dart`
   - `field_agent_dashboard.dart`
   - `incident_bloc.dart`
   - `incident_repository.dart`
2. Implement offline-first: cache to SQLite (`sqflite`), sync to Neon on reconnect
3. GPS auto-tagging with `geolocator` package
4. Photo upload: capture/pick image → upload to Firebase Storage → store URL in Neon
5. Field agent features:
   - View assigned incidents
   - Update status (`in_progress`, `resolved`)
   - Navigate to incident via Google Maps

## Neon DB Schema
```sql
CREATE TABLE IF NOT EXISTS incidents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reported_by UUID REFERENCES users(id) ON DELETE SET NULL,
  assigned_to UUID REFERENCES users(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  description TEXT,
  incident_type TEXT CHECK (incident_type IN ('flooding','rescue_needed','infrastructure_damage','medical_emergency','other')),
  status TEXT CHECK (status IN ('open','assigned','in_progress','resolved','closed')) DEFAULT 'open',
  priority TEXT CHECK (priority IN ('low','medium','high','critical')) DEFAULT 'medium',
  latitude DECIMAL(9,6),
  longitude DECIMAL(9,6),
  address TEXT,
  district TEXT,
  image_urls JSONB DEFAULT '[]',
  notes TEXT,
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_incidents_status ON incidents(status);
CREATE INDEX IF NOT EXISTS idx_incidents_assigned ON incidents(assigned_to);
CREATE INDEX IF NOT EXISTS idx_incidents_reported ON incidents(reported_by);
CREATE INDEX IF NOT EXISTS idx_incidents_priority ON incidents(priority);
CREATE INDEX IF NOT EXISTS idx_incidents_district ON incidents(district);

-- Incident status change history
CREATE TABLE IF NOT EXISTS incident_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id UUID REFERENCES incidents(id) ON DELETE CASCADE,
  changed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  old_status TEXT,
  new_status TEXT,
  note TEXT,
  changed_at TIMESTAMPTZ DEFAULT now()
);
```

## Offline Sync Strategy
```dart
// Local SQLite schema mirrors Neon schema
// Sync queue: store pending writes with timestamp
// On reconnect: flush queue to Neon API
// Conflict resolution: last-write-wins with server timestamp
```
