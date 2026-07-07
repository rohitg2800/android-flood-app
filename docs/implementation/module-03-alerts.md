# Module 3: Flood Alert & Notification System

## GitHub Branch
`feature/alert-module` → PR → `develop`

## Flutter Structure

```
lib/features/alerts/
  models/
    alert_model.dart
    notification_model.dart
  screens/
    alert_list_screen.dart
    alert_detail_screen.dart
    alert_map_screen.dart
  bloc/
    alert_bloc.dart
    alert_event.dart
    alert_state.dart
  repository/
    alert_repository.dart
  widgets/
    alert_card.dart
    severity_badge.dart
    alert_filter_bar.dart
test/alerts/
```

## Implementation Steps

1. Fetch alerts from Neon DB via REST API with pagination
2. Integrate FCM (Firebase Cloud Messaging) for push notifications
3. Implement severity levels with color coding:
   - 🟢 Low → green
   - 🟡 Medium → yellow
   - 🟠 High → orange
   - 🔴 Critical → red
4. Local notification for offline alerts using `flutter_local_notifications`
5. Alert subscription by district/zone
6. Sound + vibration for Critical alerts

## Neon DB Schema

```sql
-- Run on neon/dev branch
CREATE TABLE flood_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  severity TEXT CHECK (severity IN ('low', 'medium', 'high', 'critical')) NOT NULL,
  location_lat DECIMAL(9,6),
  location_lng DECIMAL(9,6),
  area_name TEXT NOT NULL,
  district TEXT,
  state TEXT DEFAULT 'Bihar',
  description TEXT,
  instructions TEXT,
  affected_population INTEGER,
  issued_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ,
  issued_by UUID REFERENCES users(id),
  is_active BOOLEAN DEFAULT true,
  source TEXT DEFAULT 'manual'
);

CREATE TABLE alert_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  district TEXT NOT NULL,
  min_severity TEXT DEFAULT 'low',
  fcm_token TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE notification_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  alert_id UUID REFERENCES flood_alerts(id),
  user_id UUID REFERENCES users(id),
  sent_at TIMESTAMPTZ DEFAULT now(),
  delivered BOOLEAN DEFAULT false,
  channel TEXT CHECK (channel IN ('push', 'sms', 'email'))
);

CREATE INDEX idx_alerts_severity ON flood_alerts(severity);
CREATE INDEX idx_alerts_district ON flood_alerts(district);
CREATE INDEX idx_alerts_active ON flood_alerts(is_active, issued_at DESC);
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/alerts` | List active alerts (paginated) |
| GET | `/alerts/:id` | Get alert details |
| POST | `/alerts` | Create new alert (admin only) |
| PUT | `/alerts/:id` | Update alert |
| DELETE | `/alerts/:id/deactivate` | Deactivate alert |
| POST | `/alerts/subscribe` | Subscribe to district alerts |
