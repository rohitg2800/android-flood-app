import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth/auth_user.dart';
import '../services/auth_service.dart';

// ---------------------------------------------------------------------------
// Auth State
// ---------------------------------------------------------------------------

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final AuthUser? currentUser;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.currentUser,
    this.errorMessage,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? currentUser,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      currentUser: currentUser ?? this.currentUser,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// ---------------------------------------------------------------------------
// AuthNotifier
// ---------------------------------------------------------------------------

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  /// Called on app start from SplashScreen to check stored token.
  Future<void> checkAuthStatus() async {
    state = state.copyWith(status: AuthStatus.loading);
    final hasToken = await AuthService.hasValidToken();
    if (hasToken) {
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          currentUser: user,
        );
      } else {
        await AuthService.deleteToken();
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    final result = await AuthService.signIn(email: email, password: password);
    if (result.isSuccess) {
      state = AuthState(
        status: AuthStatus.authenticated,
        currentUser: result.user,
      );
      return true;
    } else {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: result.errorMessage,
      );
      return false;
    }
  }

  Future<bool> signUp(String name, String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    final result = await AuthService.signUp(
      name: name,
      email: email,
      password: password,
    );
    if (result.isSuccess) {
      state = AuthState(
        status: AuthStatus.authenticated,
        currentUser: result.user,
      );
      return true;
    } else {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: result.errorMessage,
      );
      return false;
    }
  }

  Future<void> logout() async {
    await AuthService.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() {
    state = state.copyWith(
      status: state.isAuthenticated
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
      errorMessage: null,
    );
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());

/// Convenience provider: true when user is authenticated.
final isAuthenticatedProvider =
    Provider<bool>((ref) => ref.watch(authProvider).isAuthenticated);

/// Convenience provider: current user (nullable).
final currentUserProvider =
    Provider<AuthUser?>((ref) => ref.watch(authProvider).currentUser);
