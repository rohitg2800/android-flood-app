// test/widget/watch_button_test.dart  Step 6.1 (fixed)
// Widget tests for WatchButton:
//   • renders bookmark_border icon when NOT watching
//   • renders bookmark icon when watching
//   • tapping calls watchStation / unwatchStation on provider
//
// FIX: package name flood_app → equinox_flood

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:equinox_flood/widgets/watch_button.dart';
import 'package:equinox_flood/providers/subscription_provider.dart';
import 'package:equinox_flood/theme/river_theme.dart';

import 'watch_button_test.mocks.dart';

@GenerateMocks([SubscriptionNotifier])
void main() {
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

  testWidgets('shows bookmark_border when not watching', (tester) async {
    final mockN = MockSubscriptionNotifier();
    await tester.pumpWidget(_wrap(isWatching: false, mockNotifier: mockN));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_rounded),        findsNothing);
  });

  testWidgets('shows bookmark when watching', (tester) async {
    final mockN = MockSubscriptionNotifier();
    await tester.pumpWidget(_wrap(isWatching: true, mockNotifier: mockN));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark_rounded),        findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border_rounded), findsNothing);
  });

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
