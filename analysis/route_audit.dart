// analysis/route_audit.dart
// Run: dart run analysis/route_audit.dart
import 'dart:io';
import 'package:path/path.dart' as p;

final RegExp _goRoutePathStr = RegExp(r"GoRoute\([^)]*path:\s*'([^']*)'");
final RegExp _goRoutePathConst = RegExp(r"GoRoute\([^)]*path:\s*(Routes\.[a-zA-Z_][a-zA-Z0-9_]*)");
final RegExp _screenRouteConst = RegExp(r"static\s+const\s+String\s+route\s*=\s*'([^']*)'");
final RegExp _navPushNamedSq = RegExp(r"(?:Navigator|navigatorKey\.currentState\?)\.(pushNamed|pushReplacementNamed)\((?:[^)]*,\s*)?'([^']*)'");
final RegExp _navPushNamedDq = RegExp(r'(?:Navigator|navigatorKey\.currentState\?)\.(pushNamed|pushReplacementNamed)\((?:[^)]*,\s*)?"([^"]*)"');
final RegExp _navPushNamedVar = RegExp(r"(?:Navigator|navigatorKey\.currentState\?)\.(pushNamed|pushReplacementNamed)\((?:[^)]*,\s*)?(?:[A-Za-z_][A-Za-z0-9_.]*\.)?route");
final RegExp _navContextGoSq = RegExp(r"context\.go\('([^']*)'\)");
final RegExp _navContextGoDq = RegExp(r'context\.go\("([^"]*)"\)');
final RegExp _navContextPushSq = RegExp(r"context\.(push|goNamed)\(context,\s*'([^']*)'\)");
final RegExp _navContextPushDq = RegExp(r'context\.(push|goNamed)\(context,\s*"([^"]*)"\)');
final RegExp _routerGoSq = RegExp(r"AppRouter\.router\.go\('([^']*)'\)");
final RegExp _routerGoDq = RegExp(r'AppRouter\.router\.go\("([^"]*)"\)');

void main() {
  final routerFile = File('lib/app_router.dart');
  final libDir = Directory('lib');

  if (!routerFile.existsSync()) {
    stderr.writeln('ERROR: lib/app_router.dart not found');
    exit(1);
  }

  // Parse router constants from Routes class in app_router.dart
  final routerContent = routerFile.readAsStringSync();
  final routeConstants = <String, String>{};
  for (final m in RegExp(r"static\s+const\s+(?:String\s+)?(\w+)\s*=\s*'([^']*)'").allMatches(routerContent)) {
    routeConstants['Routes.${m.group(1)}'] = m.group(2)!;
  }
  for (final m in RegExp(r"static\s+const\s+(?:String\s+)?(\w+)\s*=\s*Routes\.(\w+)").allMatches(routerContent)) {
    final key = 'Routes.${m.group(1)}';
    final ref = 'Routes.${m.group(2)}';
    routeConstants[key] = routeConstants[ref] ?? ref;
  }

  final definedRoutes = <String>{};
  for (final m in _goRoutePathStr.allMatches(routerContent)) {
    definedRoutes.add(m.group(1)!);
  }
  for (final m in _goRoutePathConst.allMatches(routerContent)) {
    final constName = m.group(1)!;
    final path = routeConstants[constName];
    if (path != null) definedRoutes.add(path);
  }

  final screenRoutes = <String, String>{};
  for (final f in _dartFiles(libDir)) {
    final content = f.readAsStringSync();
    final rel = p.relative(f.path, from: Directory.current.path);
    for (final m in _screenRouteConst.allMatches(content)) {
      final route = m.group(1)!;
      final className = _className(rel);
      screenRoutes[className] = route;
    }
  }

  final navCalls = <Map<String, String>>[];
  for (final f in _dartFiles(libDir)) {
    final content = f.readAsStringSync();
    final rel = p.relative(f.path, from: Directory.current.path);
    for (final m in _navPushNamedSq.allMatches(content)) {
      navCalls.add({'file': rel, 'type': 'Navigator.${m.group(1)}', 'route': m.group(2)!});
    }
    for (final m in _navPushNamedDq.allMatches(content)) {
      navCalls.add({'file': rel, 'type': 'Navigator.${m.group(1)}', 'route': m.group(2)!});
    }
    for (final m in _navPushNamedVar.allMatches(content)) {
      navCalls.add({'file': rel, 'type': 'Navigator.${m.group(1)} (dynamic)', 'route': '(dynamic .route variable)'});
    }
    for (final m in _navContextGoSq.allMatches(content)) {
      navCalls.add({'file': rel, 'type': 'context.go', 'route': m.group(1)!});
    }
    for (final m in _navContextGoDq.allMatches(content)) {
      navCalls.add({'file': rel, 'type': 'context.go', 'route': m.group(1)!});
    }
    for (final m in _navContextPushSq.allMatches(content)) {
      navCalls.add({'file': rel, 'type': 'context.${m.group(1)}', 'route': m.group(2)!});
    }
    for (final m in _navContextPushDq.allMatches(content)) {
      navCalls.add({'file': rel, 'type': 'context.${m.group(1)}', 'route': m.group(2)!});
    }
    for (final m in _routerGoSq.allMatches(content)) {
      navCalls.add({'file': rel, 'type': 'AppRouter.router.go', 'route': m.group(1)!});
    }
    for (final m in _routerGoDq.allMatches(content)) {
      navCalls.add({'file': rel, 'type': 'AppRouter.router.go', 'route': m.group(1)!});
    }
  }

  print('=== DEFINED GOROUTER PATHS (${definedRoutes.length}) ===');
  for (final r in definedRoutes.toList()..sort()) print('  $r');

  print('\n=== SCREEN ROUTE CONSTANTS (${screenRoutes.length}) ===');
  final mismatched = <String>[];
  for (final entry in screenRoutes.entries.toList()..sort((a,b)=>a.key.compareTo(b.key))) {
    final matched = definedRoutes.contains(entry.value);
    if (!matched) mismatched.add('${entry.key} => "${entry.value}"');
    print('  ${matched ? "✓" : "✗"} ${entry.key} => "${entry.value}"');
  }
  if (mismatched.isNotEmpty) {
    print('\n  ⚠ Screen route constants NOT in GoRouter:');
    for (final m in mismatched) print('    - $m');
  }

  print('\n=== NAVIGATION CALLS (${navCalls.length}) ===');
  final undefined = <String>[];
  for (final call in navCalls) {
    final route = call['route']!;
    final normalized = _closest(route, definedRoutes);
    if (normalized != null && !definedRoutes.contains(normalized)) {
      undefined.add(normalized);
      print('  ✗ [${call['type']}] ${call['file']} => "$route"  (no matching GoRouter path)');
    } else {
      print('  ✓ [${call['type']}] ${call['file']} => "$route"');
    }
  }

  if (undefined.isEmpty) print('  All navigation targets are defined in GoRouter.');

  print('\n=== UNUSED ROUTER PATHS (no nav call references) ===');
  final usedRoutes = <String>{};
  for (final call in navCalls) {
    final route = call['route']!;
    final normalized = _closest(route, definedRoutes);
    if (normalized != null) usedRoutes.add(normalized);
  }
  final unused = definedRoutes.where((r) => !usedRoutes.contains(r) && r != '*').toList()..sort();
  if (unused.isEmpty) {
    print('  None — every router path is referenced by at least one navigation call.');
  } else {
    for (final r in unused) print('  $r');
  }
}

Iterable<File> _dartFiles(Directory dir) sync* {
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File && p.extension(entity.path) == '.dart') yield entity;
  }
}

String? _closest(String route, Set<String> defined) {
  if (defined.contains(route)) return route;
  final parts = route.split('/');
  for (var i = parts.length; i > 1; i--) {
    final candidate = parts.sublist(0, i).join('/') + '/*';
    if (defined.contains(candidate)) return candidate;
  }
  for (final r in defined) {
    if (r != '*' && route.startsWith(r)) return r;
  }
  return null;
}

String _className(String relPath) {
  final name = p.basenameWithoutExtension(relPath);
  return name.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join('');
}
