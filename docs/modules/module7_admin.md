# Module 7: Analytics Dashboard & Admin Panel

## GitHub Branch: `feature/admin-dashboard`

## Flutter Implementation Steps
1. Create folder: `lib/features/admin/`
   - `admin_dashboard_screen.dart`
   - `analytics_screen.dart`
   - `user_management_screen.dart`
   - `alert_management_screen.dart`
   - `reports_screen.dart`
   - `admin_bloc.dart`
2. Add `fl_chart: ^0.69.0` for in-app graphs
3. Key analytics widgets:
   - Active alerts count by severity (bar chart)
   - Incidents by district (pie chart)
   - Water level trends over 7 days (line chart)
   - Relief camp occupancy rates (progress bars)
4. Export reports: CSV via `csv` package, PDF via `pdf` package
5. Role guard: wrap all admin screens with `AdminGuard` widget

## Neon DB Schema
```sql
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL, -- 'alert', 'incident', 'camp', 'user'
  entity_id UUID,
  old_value JSONB,
  new_value JSONB,
  ip_address INET,
  performed_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_performed ON audit_logs(performed_at DESC);

-- Analytics Views
CREATE OR REPLACE VIEW v_active_alerts_by_severity AS
  SELECT severity, COUNT(*) as count
  FROM flood_alerts
  WHERE is_active = true
  GROUP BY severity
  ORDER BY CASE severity
    WHEN 'critical' THEN 1
    WHEN 'high' THEN 2
    WHEN 'medium' THEN 3
    WHEN 'low' THEN 4
  END;

CREATE OR REPLACE VIEW v_incidents_by_district AS
  SELECT district, status, COUNT(*) as count
  FROM incidents
  WHERE created_at >= NOW() - INTERVAL '30 days'
  GROUP BY district, status
  ORDER BY count DESC;

CREATE OR REPLACE VIEW v_camp_occupancy AS
  SELECT
    name,
    district,
    capacity,
    current_occupancy,
    available_capacity,
    ROUND((current_occupancy::DECIMAL / NULLIF(capacity, 0)) * 100, 1) AS occupancy_pct
  FROM relief_camps
  WHERE is_active = true
  ORDER BY occupancy_pct DESC;
```

## Key Analytics Queries
```sql
-- Total summary for dashboard KPIs
SELECT
  (SELECT COUNT(*) FROM flood_alerts WHERE is_active = true) AS active_alerts,
  (SELECT COUNT(*) FROM incidents WHERE status NOT IN ('resolved','closed')) AS open_incidents,
  (SELECT COUNT(*) FROM relief_camps WHERE is_active = true) AS active_camps,
  (SELECT SUM(current_occupancy) FROM relief_camps WHERE is_active = true) AS total_displaced,
  (SELECT COUNT(*) FROM water_level_readings WHERE is_above_danger = true AND recorded_at >= NOW() - INTERVAL '1 hour') AS stations_above_danger;
```
