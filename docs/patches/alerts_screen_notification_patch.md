# alerts_screen_notification_patch

> **Moved from `lib/screens/` on 15 Jun 2026.**
> Patch notes for `lib/screens/alerts_screen.dart` — notification tap-routing fix.

## Problem
Tapping a FCM notification while the app was in background navigated to the
root route instead of the specific alert detail screen.

## Fix applied
- `notification_handler.dart`: check `RemoteMessage.data['alertId']` and push
  `Routes.criticalAlert` with the payload before the Navigator resolves the
  shell route.
- `alerts_screen.dart`: guard duplicate pushes with `ModalRoute.isCurrent`
  check on the top-level navigator.

## Files touched
- `lib/services/notification_handler.dart`
- `lib/screens/alerts_screen.dart`
- `lib/screens/critical_alert_screen.dart`
