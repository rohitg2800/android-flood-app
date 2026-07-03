// test/widget/sparkline_card_test.dart  v6
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:equinox_flood/services/local_cache_service.dart';
import 'package:equinox_flood/widgets/sparkline_card.dart';
import 'package:equinox_flood/theme/river_theme.dart';

class _FakeCache extends LocalCacheService {
  _FakeCache() : super.forTesting();
  Future<List<(DateTime, double)>> Function(String)? onLoad;

  @override
  Future<void> init() async {}

  @override
  Future<List<(DateTime, double)>> loadGaugeHistory(String id) async {
    if (onLoad != null) return onLoad!(id);
    return <(DateTime, double)>[];
  }
}

Widget _wrap(Widget w) => ProviderScope(
      child: RiverTheme(
        child: MaterialApp(home: Scaffold(body: w)),
      ),
    );

void main() {
  late _FakeCache fake;
  setUp(() {
    fake = _FakeCache();
    LocalCacheService.setInstanceForTesting(fake);
  });

  testWidgets('shows spinner while loading', (tester) async {
    final completer = Completer<List<(DateTime, double)>>();
    fake.onLoad = (_) => completer.future;
    await tester.pumpWidget(_wrap(const SparklineCard(
      stationId: 'GS001',
      dangerLevel: 10.0,
      accentColor: Colors.blue,
    )));
    await tester.pump(); // one frame — still loading
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete([]); // clean up
    await tester.pumpAndSettle();
  });

  testWidgets('shows empty message when no history', (tester) async {
    fake.onLoad = (_) async => <(DateTime, double)>[];
    await tester.pumpWidget(_wrap(const SparklineCard(
      stationId: 'GS001',
      dangerLevel: 10.0,
      accentColor: Colors.blue,
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('No history yet'), findsOneWidget);
  });

  testWidgets('renders chart when >= 2 points', (tester) async {
    final now = DateTime.now();
    fake.onLoad = (_) async => <(DateTime, double)>[
          (now.subtract(const Duration(hours: 2)), 8.5),
          (now.subtract(const Duration(hours: 1)), 9.1),
          (now, 9.8),
        ];
    await tester.pumpWidget(_wrap(const SparklineCard(
      stationId: 'GS001',
      dangerLevel: 10.0,
      accentColor: Colors.blue,
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('No history yet'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Danger:'), findsOneWidget);
  });

  testWidgets('72h toggle chip is tappable', (tester) async {
    final now = DateTime.now();
    fake.onLoad = (_) async => <(DateTime, double)>[
          (now.subtract(const Duration(hours: 50)), 7.0),
          (now.subtract(const Duration(hours: 25)), 8.0),
          (now, 9.0),
        ];
    await tester.pumpWidget(_wrap(const SparklineCard(
      stationId: 'GS001',
      dangerLevel: 10.0,
      accentColor: Colors.blue,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('72h'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No history yet'), findsNothing);
  });

  testWidgets('passes correct stationId to cache', (tester) async {
    String? got;
    fake.onLoad = (id) async {
      got = id;
      return <(DateTime, double)>[];
    };
    await tester.pumpWidget(_wrap(const SparklineCard(
      stationId: 'GS_PATNA',
      dangerLevel: 12.0,
      accentColor: Colors.red,
    )));
    await tester.pumpAndSettle();
    expect(got, 'GS_PATNA');
  });
}
