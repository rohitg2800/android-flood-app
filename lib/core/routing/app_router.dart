import 'package:flutter/material.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      default:
        return _fade(const Scaffold(
          body: Center(child: Text('Route not found')),
        ));
    }
  }

  static PageRoute<T> _fade<T>(Widget child) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => child,
      transitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
        child: child,
      ),
    );
  }

  static PageRoute<T> _slideUp<T>(Widget child) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => child,
      transitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (_, animation, __, child) {
        final offset = Tween(begin: const Offset(0, 0.08), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic))
            .animate(animation);
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
          child: SlideTransition(position: offset, child: child),
        );
      },
    );
  }
}
