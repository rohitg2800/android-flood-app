import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../app_routes.dart';

/// AuthGuard wraps any widget that requires authentication.
/// If the user is not authenticated, redirects to the login screen.
class AuthGuard extends ConsumerWidget {
  final Widget child;
  const AuthGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    switch (authState.status) {
      case AuthStatus.initial:
      case AuthStatus.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AuthStatus.authenticated:
        return child;
      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        // Redirect after frame to avoid router conflicts
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go(AppRoutes.login);
        });
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
    }
  }
}
