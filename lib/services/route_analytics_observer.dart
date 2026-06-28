import 'dart:async';

import 'package:flutter/widgets.dart';

/// Minimal abstraction to avoid tight coupling to Firebase/other SDKs.
abstract class AnalyticsLogger {
  Future<void> logScreen(String name);
}

/// Logs screen names on navigation.
///
/// - On every [didPush]: logs the pushed route's `RouteSettings.name`
/// - On every [didPop]: logs the previous/new top route's `RouteSettings.name`
class RouteAnalyticsObserver extends NavigatorObserver {
  RouteAnalyticsObserver({required this.logger});

  final AnalyticsLogger logger;

  String? _routeName(Route<dynamic>? route) {
    final settings = route?.settings;
    return routeNameFromRouteSettings(settings ?? const RouteSettings());
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = _routeName(route);
    if (name != null) {
      unawaited(logger.logScreen(name));
    }
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // After popping, previousRoute is typically the new top route.
    final name = _routeName(previousRoute);
    if (name != null) {
      unawaited(logger.logScreen(name));
    }
    super.didPop(route, previousRoute);
  }
}

/// Extracts a route name from [RouteSettings].
///
/// Example: if you navigate using named routes with `Navigator.pushNamed('/alerts')`,
/// the `settings.name` should be `'/alerts'`.
String? routeNameFromRouteSettings(RouteSettings settings) {
  final name = settings.name;
  if (name == null || name.isEmpty) return null;
  return name;
}
