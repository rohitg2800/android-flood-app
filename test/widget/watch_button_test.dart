// test/widget/watch_button_test.dart  Step 6.1
// Widget tests for WatchButton:
//   • renders bookmark_border icon when NOT watching
//   • renders bookmark icon when watching
//   • tapping calls watchStation / unwatchStation on provider

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flood_app/widgets/watch_button.dart';
import 'package:flood_app/providers/subscription_provider.dart';
import 'package:flood_app/theme/river_theme.dart';

import 'watch_button_test.mocks.dart';

@GenerateMocks([SubscriptionNotifier])
void main() {
  // Helper: builds a ProviderScope overriding subscriptionProvider
  Widget _wrap({
    required bool isWatching,
    required MockSubscriptionNotifier mockNotifier,
  }) {
    return ProviderScope(
      overrides: [
        subscriptionProvider.overrideWith((ref) => mockNotifier),
        isWatchingProvider('GS001').overrideWith((_) => isWatching),
      ],
      child: RiverTheme(
        child: MaterialApp(
          home: Scaffold(
            body: WatchButton(
              stationId: 'GS001',
              cityName:  'Patna',
              riverName: 'Ganga',
            ),
          ),
        ),
      ),
    );
  }

  // ── 1. Unwatch state
  testWidgets('shows bookmark_border when not watching', (tester) async {
    final mockN = MockSubscriptionNotifier();
    await tester.pumpWidget(_wrap(isWatching: false, mockNotifier: mockN));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_rounded),        findsNothing);
  });

  // ── 2. Watch state
  testWidgets('shows bookmark when watching', (tester) async {
    final mockN = MockSubscriptionNotifier();
    await tester.pumpWidget(_wrap(isWatching: true, mockNotifier: mockN));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark_rounded),        findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border_rounded), findsNothing);
  });

  // ── 3. Tap when not watching → calls watchStation
  testWidgets('tap when unwatch calls watchStation', (tester) async {
    final mockN = MockSubscriptionNotifier();
    when(mockN.watchStation(any, cityName: anyNamed('cityName'),
            riverName: anyNamed('riverName')))
        .thenReturn(null);

    await tester.pumpWidget(_wrap(isWatching: false, mockNotifier: mockN));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    verify(mockN.watchStation('GS001',
            cityName: 'Patna', riverName: 'Ganga'))
        .called(1);
  });

  // ── 4. Tap when watching → calls unwatchStation
  testWidgets('tap when watching calls unwatchStation', (tester) async {
    final mockN = MockSubscriptionNotifier();
    when(mockN.unwatchStation(any)).thenReturn(null);

    await tester.pumpWidget(_wrap(isWatching: true, mockNotifier: mockN));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    verify(mockN.unwatchStation('GS001')).called(1);
  });
}
