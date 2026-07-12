# Module 7: Analytics Dashboard & Admin Panel

## GitHub Branch
`feature/admin-dashboard` → PR → `develop`

## Flutter Structure

```
lib/features/admin/
  models/
    analytics_model.dart
    audit_log_model.dart
  screens/
    admin_dashboard_screen.dart
    analytics_screen.dart
    user_management_screen.dart
    system_settings_screen.dart
    audit_log_screen.dart
  bloc/
    admin_bloc.dart
    admin_event.dart
    admin_state.dart
  repository/
    admin_repository.dart
  widgets/
    kpi_card.dart
    alert_chart.dart
    incident_heatmap.dart
    resource_utilization_chart.dart
test/admin/
```

## Implementation Steps

1. KPI Cards: active alerts, open incidents, camp occupancy %, water level stations in danger
2. Charts using `fl_chart`:
   - Alerts over time (line chart, 7/30/90 days)
   - Incidents by district (bar chart)
   - Resource utilization per camp (progress bars)
   - Water level trends per station
3. User management: view/activate/deactivate users, assign roles
4. System settings: alert thresholds, notification templates
5. Audit log: all admin actions with timestamp + user
6. Export: CSV/PDF report generation

## Neon DB Schema

```sql
-- Run on neon/dev branch
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID,
  old_value JSONB,
  new_value JSONB,
  ip_address TEXT,
  performed_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE system_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  setting_key TEXT UNIQUE NOT NULL,
  setting_value JSONB NOT NULL,
  description TEXT,
  updated_by UUID REFERENCES users(id),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE analytics_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_date DATE NOT NULL,
  total_alerts INTEGER DEFAULT 0,
  critical_alerts INTEGER DEFAULT 0,
  open_incidents INTEGER DEFAULT 0,
  resolved_incidents INTEGER DEFAULT 0,
  total_camp_capacity INTEGER DEFAULT 0,
  total_occupancy INTEGER DEFAULT 0,
  people_affected INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Useful analytics queries
-- Active alerts by severity
CREATE VIEW v_alert_summary AS
  SELECT severity, COUNT(*) as count, district
  FROM flood_alerts
  WHERE is_active = true
  GROUP BY severity, district
  ORDER BY district, severity;

-- Incident resolution rate by agent
CREATE VIEW v_agent_performance AS
  SELECT
    u.name,
    COUNT(i.id) as total_assigned,
    COUNT(CASE WHEN i.status = 'resolved' THEN 1 END) as resolved,
    AVG(EXTRACT(EPOCH FROM (i.resolved_at - i.created_at))/3600) as avg_resolution_hours
  FROM users u
  LEFT JOIN incidents i ON i.assigned_to = u.id
  WHERE u.role = 'field_agent'
  GROUP BY u.id, u.name;

CREATE INDEX idx_audit_user ON audit_logs(user_id);
CREATE INDEX idx_audit_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_time ON audit_logs(performed_at DESC);
CREATE INDEX idx_snapshots_date ON analytics_snapshots(snapshot_date DESC);
```

## Analytics Queries

```sql
-- Water stations in danger right now
SELECT s.station_name, r.level_meters, s.danger_level_m, r.trend
FROM water_level_stations s
JOIN LATERAL (
  SELECT * FROM water_level_readings
  WHERE station_id = s.id
  ORDER BY recorded_at DESC LIMIT 1
) r ON true
WHERE r.level_meters >= s.danger_level_m
ORDER BY (r.level_meters - s.danger_level_m) DESC;

-- Camp occupancy percentage
SELECT name, district,
  current_occupancy, capacity,
  ROUND((current_occupancy::decimal / capacity) * 100, 1) AS occupancy_pct
FROM relief_camps
WHERE is_active = true
ORDER BY occupancy_pct DESC;
```
