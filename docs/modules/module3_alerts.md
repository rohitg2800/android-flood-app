# Module 3: Flood Alert & Notification System

## GitHub Branch: `feature/alert-module`

## Flutter Implementation Steps
1. Create folder: `lib/features/alerts/`
   - `alert_model.dart`
   - `alert_list_screen.dart`
   - `alert_detail_screen.dart`
   - `alert_bloc.dart`
   - `alert_repository.dart`
2. Integrate Firebase Cloud Messaging (FCM) for push notifications
3. Severity levels with color coding:
   - `low` → Green
   - `medium` → Yellow
   - `high` → Orange
   - `critical` → Red
4. Real-time polling every 30s or WebSocket subscription
5. Write unit tests in `test/alerts/`

## Neon DB Schema
```sql
CREATE TABLE IF NOT EXISTS flood_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  severity TEXT CHECK (severity IN ('low','medium','high','critical')) NOT NULL,
  location_lat DECIMAL(9,6),
  location_lng DECIMAL(9,6),
  area_name TEXT,
  state TEXT DEFAULT 'Bihar',
  district TEXT,
  description TEXT,
  issued_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ,
  issued_by UUID REFERENCES users(id) ON DELETE SET NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_alerts_severity ON flood_alerts(severity);
CREATE INDEX IF NOT EXISTS idx_alerts_active ON flood_alerts(is_active);
CREATE INDEX IF NOT EXISTS idx_alerts_area ON flood_alerts(area_name);
CREATE INDEX IF NOT EXISTS idx_alerts_issued_at ON flood_alerts(issued_at DESC);

-- Alert subscriptions per user
CREATE TABLE IF NOT EXISTS alert_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  area_name TEXT,
  fcm_token TEXT,
  min_severity TEXT DEFAULT 'medium',
  created_at TIMESTAMPTZ DEFAULT now()
);
```

## FCM Notification Payload
```json
{
  "notification": {
    "title": "Flood Alert: Critical",
    "body": "Severe flooding in Patna district. Evacuate immediately."
  },
  "data": {
    "alert_id": "uuid",
    "severity": "critical",
    "area": "Patna"
  }
}
```
