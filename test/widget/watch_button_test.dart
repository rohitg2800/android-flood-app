// test/widget/watch_button_test.dart  v9
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:equinox_flood/widgets/watch_button.dart';
import 'package:equinox_flood/providers/subscription_provider.dart';
import 'package:equinox_flood/models/alert_subscription.dart';
import 'package:equinox_flood/theme/river_theme.dart';

class _FakeNotifier extends SubscriptionNotifier {
  _FakeNotifier(super.seed) : super.forTesting();
  final List<String> calls = [];

  @override
  Future<void> subscribe(AlertSubscription sub) async {
    calls.add('subscribe:${sub.stationId}');
    state = [...state, sub];
  }

  @override
  Future<void> unsubscribe(String stationId) async {
    calls.add('unsubscribe:$stationId');
    state = state.where((s) => s.stationId != stationId).toList();
  }
}

AlertSubscription _sub() => AlertSubscription(
      stationId: 'GS001',
      cityName: 'Patna',
      riverName: 'Ganga',
      createdAt: DateTime(2026),
    );

Widget _wrap(_FakeNotifier n) => ProviderScope(
      overrides: [subscriptionProvider.overrideWith((_) => n)],
      child: RiverTheme(
        child: MaterialApp(
          home: Scaffold(
            body: WatchButton(
                stationId: 'GS001', cityName: 'Patna', riverName: 'Ganga'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('shows notifications_none when not watching', (tester) async {
    await tester.pumpWidget(_wrap(_FakeNotifier([])));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(find.byIcon(Icons.notifications_active_rounded), findsNothing);
  });

  testWidgets('shows notifications_active when watching', (tester) async {
    await tester.pumpWidget(_wrap(_FakeNotifier([_sub()])));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.notifications_active_rounded), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
  });

  testWidgets('tap when not watching calls subscribe', (tester) async {
    final n = _FakeNotifier([]);
    await tester.pumpWidget(_wrap(n));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(n.calls, contains('subscribe:GS001'));
  });

  testWidgets('tap when watching calls unsubscribe', (tester) async {
    final n = _FakeNotifier([_sub()]);
    await tester.pumpWidget(_wrap(n));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(n.calls, contains('unsubscribe:GS001'));
  });
}
