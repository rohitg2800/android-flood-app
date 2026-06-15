// test/widget/sync_status_banner_test.dart  Step 6.1 (fixed v2)
// Widget tests for SyncStatusBanner.
//
// FIX v2 — "A Timer is still pending even after the widget tree was disposed"
//
// Root cause:
//   SyncStatusBanner watches wsStatusProvider AND wsLastSyncProvider.
//   wsLastSyncProvider (ws_live_provider.dart:32) watches wsLiveProvider.
//   wsLiveProvider calls WsGaugeService.instance.start() which creates:
//     • a 20-second periodic ping timer
//     • a 30-second one-shot fallback timer
//   These timers are registered with FakeAsync and are still pending when
//   the widget tree is torn down, triggering the `!timersPending` assertion.
//
// Fix: override ALL three providers in the test ProviderScope so that
//   WsGaugeService.start() is never called during tests.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:equinox_flood/widgets/sync_status_banner.dart';
import 'package:equinox_flood/services/ws_gauge_service.dart';
import 'package:equinox_flood/providers/ws_live_provider.dart';
import 'package:equinox_flood/models/flood_data.dart';
import 'package:equinox_flood/theme/river_theme.dart';

void main() {
  /// Build a fully-isolated widget tree.
  /// All three providers that touch WsGaugeService are overridden:
  ///   wsStatusProvider   — StreamProvider<WsStatus>
  ///   wsLastSyncProvider — Provider<DateTime?>
  ///   wsLiveProvider     — StreamProvider<List<FloodData>>
  Widget _wrap(WsStatus status) {
    return ProviderScope(
      overrides: [
        // 1. Status stream — the one the banner actually displays.
        wsStatusProvider.overrideWith(
          (ref) => Stream.value(status),
        ),
        // 2. Last-sync time — null is fine; banner shows 'No data yet'.
        wsLastSyncProvider.overrideWith(
          (ref) => null,
        ),
        // 3. Live data stream — stub so wsLiveProvider never calls start().
        wsLiveProvider.overrideWith(
          (ref) => Stream<List<FloodData>>.empty(),
        ),
      ],
      child: RiverTheme(
        child: const MaterialApp(
          home: Scaffold(body: SyncStatusBanner()),
        ),
      ),
    );
  }

  testWidgets('SyncStatusBanner is hidden when Connected', (tester) async {
    await tester.pumpWidget(_wrap(WsStatus.connected));
    await tester.pumpAndSettle();
    expect(find.text('LIVE'), findsNothing);
  });

  testWidgets('SyncStatusBanner shows Connecting banner', (tester) async {
    await tester.pumpWidget(_wrap(WsStatus.connecting));
    await tester.pumpAndSettle();
    expect(find.textContaining('Connecting'), findsOneWidget);
  });

  testWidgets('SyncStatusBanner shows Offline banner', (tester) async {
    await tester.pumpWidget(_wrap(WsStatus.offline));
    await tester.pumpAndSettle();
    expect(find.textContaining('Offline'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
  });

  testWidgets('SyncStatusBanner shows Polling banner for fallback', (tester) async {
    await tester.pumpWidget(_wrap(WsStatus.fallback));
    await tester.pumpAndSettle();
    expect(find.textContaining('Polling'), findsOneWidget);
  });
}
