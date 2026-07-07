import 'package:flutter_bloc/flutter_bloc.dart';

// Auth Events
abstract class AuthEvent {}
class LoginRequested extends AuthEvent {
  final String email, password;
  LoginRequested(this.email, this.password);
}
class RegisterRequested extends AuthEvent {
  final String email, password, name, phone, role;
  RegisterRequested({required this.email, required this.password, required this.name, required this.phone, this.role = 'citizen'});
}
class LogoutRequested extends AuthEvent {}

// Auth States
abstract class AuthState {}
class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthAuthenticated extends AuthState {
  final String userId, role, name;
  AuthAuthenticated({required this.userId, required this.role, required this.name});
}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}
class AuthUnauthenticated extends AuthState {}

// Auth Bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(AuthInitial()) {
    on<LoginRequested>(_onLogin);
    on<RegisterRequested>(_onRegister);
    on<LogoutRequested>(_onLogout);
  }

  Future<void> _onLogin(LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      // TODO: Call Neon DB API for authentication
      // final user = await AuthRepository.login(event.email, event.password);
      emit(AuthAuthenticated(userId: 'temp-id', role: 'citizen', name: 'User'));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onRegister(RegisterRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      // TODO: Call Neon DB API for registration
      emit(AuthAuthenticated(userId: 'temp-id', role: event.role, name: event.name));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onLogout(LogoutRequested event, Emitter<AuthState> emit) async {
    emit(AuthUnauthenticated());
  }
}
