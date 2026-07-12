// lib/services/app_state_service.dart
// OpsFlood — AppStateService
// Lightweight singleton that tracks global app-level state flags.
library;

import 'package:flutter/foundation.dart';

class AppStateService extends ChangeNotifier {
  AppStateService._();
  static final AppStateService instance = AppStateService._();

  bool _isOnline = true;
  bool _isPolicyLocked = false;
  String? _lockReason;

  bool get isOnline => _isOnline;
  bool get isPolicyLocked => _isPolicyLocked;
  String? get lockReason => _lockReason;

  void setOnline(bool value) {
    if (_isOnline == value) return;
    _isOnline = value;
    notifyListeners();
  }

  void lockPolicy(String reason) {
    _isPolicyLocked = true;
    _lockReason = reason;
    notifyListeners();
  }

  void unlockPolicy() {
    _isPolicyLocked = false;
    _lockReason = null;
    notifyListeners();
  }
}
