# Module 7: Analytics Dashboard & Admin Panel

## GitHub Branch: `feature/admin-dashboard`

## Implementation Steps
1. Build Admin-only screens in `lib/features/admin/`
2. Analytics metrics:
   - Active alerts by severity
   - Incidents by area/district
   - Relief camp occupancy rates
   - Resource utilization charts
   - Water level trends (last 7 days)
3. Use `fl_chart` Flutter package for in-app graphs
4. Export reports as CSV using Neon aggregate queries
5. Audit log viewer for all admin actions

## Folder Structure
```
lib/
  features/
    admin/
      screens/
        admin_dashboard_screen.dart
        analytics_screen.dart
        user_management_screen.dart
        audit_log_screen.dart
        report_export_screen.dart
      widgets/
        kpi_card.dart
        alert_trend_chart.dart
        incident_heatmap.dart
        camp_occupancy_chart.dart
      services/
        analytics_repository.dart
        export_service.dart
```

## Neon DB Schema
```sql
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  action TEXT NOT NULL,
  entity_type TEXT CHECK (entity_type IN ('alert','incident','user','camp','resource')),
  entity_id UUID,
  metadata JSONB DEFAULT '{}',
  ip_address TEXT,
  performed_at TIMESTAMPTZ DEFAULT now()
);

-- Analytics view: daily alert counts by severity
CREATE VIEW daily_alert_stats AS
SELECT
  DATE_TRUNC('day', issued_at) AS day,
  severity,
  COUNT(*) AS alert_count
FROM flood_alerts
GROUP BY 1, 2
ORDER BY 1 DESC, 2;

-- Analytics view: incident resolution time
CREATE VIEW incident_resolution_stats AS
SELECT
  category,
  COUNT(*) AS total,
  COUNT(*) FILTER (WHERE status = 'resolved') AS resolved,
  AVG(EXTRACT(EPOCH FROM (resolved_at - created_at))/3600) AS avg_hours_to_resolve
FROM incidents
GROUP BY category;

CREATE INDEX idx_audit_logs_user ON audit_logs(user_id, performed_at DESC);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
```

## Key KPI Queries
```sql
-- Active alerts summary
SELECT severity, COUNT(*) as count
FROM flood_alerts
WHERE is_active = true
GROUP BY severity;

-- Open incidents by district
SELECT address, COUNT(*) as open_count
FROM incidents
WHERE status NOT IN ('resolved','closed')
GROUP BY address
ORDER BY open_count DESC
LIMIT 10;

-- Camp occupancy overview
SELECT name, capacity, current_occupancy,
  ROUND((current_occupancy::DECIMAL / capacity) * 100, 1) AS occupancy_pct
FROM relief_camps
WHERE is_active = true
ORDER BY occupancy_pct DESC;
```

## fl_chart Integration
```yaml
# pubspec.yaml
dependencies:
  fl_chart: ^0.68.0
```

```dart
// Alert trend line chart
LineChartData buildAlertTrendChart(List<DailyAlertStat> stats) {
  return LineChartData(
    lineBarsData: [
      LineChartBarData(
        spots: stats.map((s) =>
          FlSpot(s.dayIndex.toDouble(), s.count.toDouble())
        ).toList(),
        isCurved: true,
        color: const Color(0xFF2196F3),
        barWidth: 2,
        dotData: const FlDotData(show: false),
      ),
    ],
  );
}
```
