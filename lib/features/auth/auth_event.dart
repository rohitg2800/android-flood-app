abstract class AuthEvent {}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;
  LoginRequested(this.email, this.password);
}

class RegisterRequested extends AuthEvent {
  final String name;
  final String email;
  final String password;
  final String role; // 'admin' | 'field_agent' | 'citizen'
  RegisterRequested(this.name, this.email, this.password, this.role);
}

class LogoutRequested extends AuthEvent {}
