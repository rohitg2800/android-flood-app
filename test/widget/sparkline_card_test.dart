// test/widget/sparkline_card_test.dart  Step 6.1
// Widget tests for SparklineCard:
//   • shows loading spinner while history is loading
//   • shows 'No history yet' when cache is empty
//   • renders chart when data has >= 2 points
//   • toggle buttons switch range and rebuild
//
// fix(D): flood_app → equinox_flood package name (pubspec.yaml name:)
// fix(D): removed stale import of sparkline_card_test.mocks.dart (file
//         doesn't exist yet; build_runner will generate it from @GenerateMocks)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:equinox_flood/services/local_cache_service.dart';
import 'package:equinox_flood/widgets/sparkline_card.dart';
import 'package:equinox_flood/theme/river_theme.dart';

// NOTE: run `flutter pub run build_runner build` to regenerate mocks
// after any LocalCacheService API change.
@GenerateMocks([LocalCacheService])
void main() {
  late MockLocalCacheService mockCache;

  setUp(() {
    mockCache = MockLocalCacheService();
    // Inject mock into singleton slot for tests
    LocalCacheService.setInstanceForTesting(mockCache);
  });

  Widget _wrap(Widget w) => ProviderScope(
        child: RiverTheme(
          child: MaterialApp(home: Scaffold(body: w)),
        ),
      );

  // ── 1. Loading state
  testWidgets('shows CircularProgressIndicator while loading', (tester) async {
    // Never completes during test pump
    when(mockCache.loadGaugeHistory(any))
        .thenAnswer((_) => Future.delayed(const Duration(seconds: 60), () => []));

    await tester.pumpWidget(_wrap(
      const SparklineCard(
        stationId:   'GS001',
        dangerLevel: 10.0,
        accentColor: Colors.blue,
      ),
    ));

    // First frame — loading
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // ── 2. Empty state
  testWidgets('shows empty message when no history', (tester) async {
    when(mockCache.loadGaugeHistory(any))
        .thenAnswer((_) async => []);

    await tester.pumpWidget(_wrap(
      const SparklineCard(
        stationId:   'GS001',
        dangerLevel: 10.0,
        accentColor: Colors.blue,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('No history yet'), findsOneWidget);
  });

  // ── 3. Chart renders with data
  testWidgets('renders chart when >= 2 data points available', (tester) async {
    final now = DateTime.now();
    when(mockCache.loadGaugeHistory(any)).thenAnswer((_) async => [
      (now.subtract(const Duration(hours: 2)), 8.5),
      (now.subtract(const Duration(hours: 1)), 9.1),
      (now,                                   9.8),
    ]);

    await tester.pumpWidget(_wrap(
      const SparklineCard(
        stationId:   'GS001',
        dangerLevel: 10.0,
        accentColor: Colors.blue,
      ),
    ));
    await tester.pumpAndSettle();

    // Chart renders — no empty/loading widgets
    expect(find.textContaining('No history yet'),        findsNothing);
    expect(find.byType(CircularProgressIndicator),       findsNothing);
    // Danger legend is shown
    expect(find.textContaining('Danger:'),               findsOneWidget);
  });

  // ── 4. Toggle rebuilds widget
  testWidgets('72h toggle chip is tappable and updates state', (tester) async {
    final now = DateTime.now();
    when(mockCache.loadGaugeHistory(any)).thenAnswer((_) async => [
      (now.subtract(const Duration(hours: 50)), 7.0),
      (now.subtract(const Duration(hours: 25)), 8.0),
      (now,                                     9.0),
    ]);

    await tester.pumpWidget(_wrap(
      const SparklineCard(
        stationId:   'GS001',
        dangerLevel: 10.0,
        accentColor: Colors.blue,
      ),
    ));
    await tester.pumpAndSettle();

    // Tap 72h chip
    await tester.tap(find.text('72h'));
    await tester.pumpAndSettle();

    // Widget still shows chart (no crash)
    expect(find.textContaining('No history yet'), findsNothing);
  });

  // ── 5. stationId is passed to cache
  testWidgets('calls loadGaugeHistory with correct stationId', (tester) async {
    when(mockCache.loadGaugeHistory('GS_PATNA'))
        .thenAnswer((_) async => []);

    await tester.pumpWidget(_wrap(
      const SparklineCard(
        stationId:   'GS_PATNA',
        dangerLevel: 12.0,
        accentColor: Colors.red,
      ),
    ));
    await tester.pumpAndSettle();

    verify(mockCache.loadGaugeHistory('GS_PATNA')).called(1);
  });
}
