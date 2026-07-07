// Module 2: Authentication BLoC
// flutter pub add flutter_bloc firebase_auth

import 'package:flutter_bloc/flutter_bloc.dart';

// Events
abstract class AuthEvent {}
class LoginRequested extends AuthEvent {
  final String email;
  final String password;
  LoginRequested({required this.email, required this.password});
}
class LogoutRequested extends AuthEvent {}
class RegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String name;
  final String role;
  RegisterRequested({required this.email, required this.password, required this.name, required this.role});
}

// States
abstract class AuthState {}
class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthAuthenticated extends AuthState {
  final String userId;
  final String role;
  AuthAuthenticated({required this.userId, required this.role});
}
class AuthUnauthenticated extends AuthState {}
class AuthError extends AuthState {
  final String message;
  AuthError({required this.message});
}

// BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(AuthInitial()) {
    on<LoginRequested>(_onLogin);
    on<LogoutRequested>(_onLogout);
    on<RegisterRequested>(_onRegister);
  }

  Future<void> _onLogin(LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      // TODO: Implement Firebase Auth or JWT login
      // final user = await authRepository.login(event.email, event.password);
      // emit(AuthAuthenticated(userId: user.id, role: user.role));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onLogout(LogoutRequested event, Emitter<AuthState> emit) async {
    // TODO: Clear session
    emit(AuthUnauthenticated());
  }

  Future<void> _onRegister(RegisterRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      // TODO: Implement registration
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }
}
