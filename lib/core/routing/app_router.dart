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

}
