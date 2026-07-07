// Auth BLoC
// Handles login, register, logout events
// Roles: admin | field_agent | citizen

abstract class AuthEvent {}
class LoginEvent extends AuthEvent {
  final String email;
  final String password;
  LoginEvent(this.email, this.password);
}
class LogoutEvent extends AuthEvent {}

abstract class AuthState {}
class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthAuthenticated extends AuthState {
  final String role;
  AuthAuthenticated(this.role);
}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}
