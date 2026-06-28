// lib/providers/auth_provider.dart
// Auth state for router guards.
//
// NOTE: This app previously had no authentication UI/state. This provider
// adds a minimal ChangeNotifier + Riverpod provider that can be wired into
// navigation guards.
//
// Replace the mock signIn/signOut implementations with FirebaseAuth calls
// when ready.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod ChangeNotifier provider that exposes `isLoggedIn`.
class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  /// Minimal init hook so router guards can wait for the first read.
  Future<void> init() async {
    // TODO: wire to FirebaseAuth.instance.currentUser or stream.
    // Keeping false by default.
  }

  Future<void> signIn({String? email}) async {
    _isLoggedIn = true;
    notifyListeners();
  }

  Future<void> register({String? email}) async {
    _isLoggedIn = true;
    notifyListeners();
  }

  Future<void> signOut() async {
    _isLoggedIn = false;
    notifyListeners();
  }
}

final authProvider = ChangeNotifierProvider<AuthProvider>((ref) {
  final notifier = AuthProvider();
  // Fire-and-forget init.
  notifier.init();
  return notifier;
});
