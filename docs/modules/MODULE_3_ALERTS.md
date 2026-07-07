# Module 3: Flood Alert & Notification System

## GitHub Branch: `feature/alert-module`

## Implementation Steps
1. Build `lib/features/alerts/` with:
   - `alert_model.dart`
   - `alert_list_screen.dart`
   - `alert_detail_screen.dart`
   - `alert_bloc.dart`
2. Integrate Firebase Cloud Messaging (FCM) for push notifications
3. Implement severity levels with color coding:
   - 🟢 Low — `#4CAF50`
   - 🟡 Medium — `#FFC107`
   - 🔴 High — `#FF5722`
   - ⚫ Critical — `#B71C1C`
4. Write unit tests in `test/alerts/`

## Folder Structure
```
lib/
  features/
    alerts/
      screens/
        alert_list_screen.dart
        alert_detail_screen.dart
        create_alert_screen.dart
      bloc/
        alert_bloc.dart
        alert_event.dart
        alert_state.dart
      models/
        alert_model.dart
      widgets/
        alert_card.dart
        severity_badge.dart
      services/
        fcm_service.dart
        alert_repository.dart
```

## Neon DB Schema
```sql
CREATE TABLE flood_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  severity TEXT CHECK (severity IN ('low','medium','high','critical')),
  location_lat DECIMAL(9,6),
  location_lng DECIMAL(9,6),
  area_name TEXT,
  description TEXT,
  issued_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ,
  issued_by UUID REFERENCES users(id),
  is_active BOOLEAN DEFAULT true,
  affected_population INTEGER,
  source TEXT
);

CREATE TABLE alert_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  alert_id UUID REFERENCES flood_alerts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id),
  sent_at TIMESTAMPTZ DEFAULT now(),
  read_at TIMESTAMPTZ,
  delivery_status TEXT CHECK (delivery_status IN ('sent','delivered','failed'))
);

CREATE INDEX idx_alerts_severity ON flood_alerts(severity);
CREATE INDEX idx_alerts_active ON flood_alerts(is_active, issued_at DESC);
CREATE INDEX idx_alerts_location ON flood_alerts(location_lat, location_lng);
```

## FCM Integration
```dart
// services/fcm_service.dart
class FCMService {
  static Future<void> initialize() async {
    await Firebase.initializeApp();
    final fcm = FirebaseMessaging.instance;
    await fcm.requestPermission(alert: true, badge: true, sound: true);
    
    FirebaseMessaging.onMessage.listen((message) {
      // Handle foreground notification
    });
    
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      // Handle notification tap
    });
  }
}
```
