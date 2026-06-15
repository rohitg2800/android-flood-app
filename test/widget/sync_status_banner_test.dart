// test/widget/sync_status_banner_test.dart  Step 6.1
// Widget tests for SyncStatusBanner:
//   • renders hidden (height 0) when status is WsStatus.connected (Live)
//   • shows Connecting banner when status is WsStatus.connecting
//   • shows Offline banner  when status is WsStatus.offline
//   • shows Polling banner  when status is WsStatus.fallback (Stale)
//
// fix(E): Rewrote to use WsStatus / wsStatusProvider (actual API).
//   The old test used SyncStatus/syncStatusProvider which never existed;
//   SyncStatusBanner internally watches wsStatusProvider (WsStatus enum).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:equinox_flood/widgets/sync_status_banner.dart';
import 'package:equinox_flood/services/ws_gauge_service.dart';
import 'package:equinox_flood/providers/ws_live_provider.dart';
import 'package:equinox_flood/theme/river_theme.dart';

void main() {
  Widget _wrap(WsStatus status) {
    return ProviderScope(
      overrides: [
        wsStatusProvider.overrideWith(
          (ref) => Stream.value(status).first
              .then((s) => AsyncValue.data(s))
              .then((_) => status),
        ),
      ],
      child: RiverTheme(
        child: const MaterialApp(
          home: Scaffold(body: SyncStatusBanner()),
        ),
      ),
    );
  }

  // ── 1. Connected → banner hidden (height=0)
  testWidgets('SyncStatusBanner is hidden when Connected', (tester) async {
    await tester.pumpWidget(_wrap(WsStatus.connected));
    await tester.pumpAndSettle();
    // LIVE state → AnimatedContainer height=0, no text visible
    expect(find.text('LIVE'), findsNothing);
  });

  // ── 2. Connecting → banner shown with 'Connecting…'
  testWidgets('SyncStatusBanner shows Connecting banner', (tester) async {
    await tester.pumpWidget(_wrap(WsStatus.connecting));
    await tester.pumpAndSettle();
    expect(find.textContaining('Connecting'), findsOneWidget);
  });

  // ── 3. Offline → banner shown with 'Offline' text + cloud_off icon
  testWidgets('SyncStatusBanner shows Offline banner', (tester) async {
    await tester.pumpWidget(_wrap(WsStatus.offline));
    await tester.pumpAndSettle();
    expect(find.textContaining('Offline'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
  });

  // ── 4. Fallback → banner shown with 'Polling' text
  testWidgets('SyncStatusBanner shows Polling banner for fallback', (tester) async {
    await tester.pumpWidget(_wrap(WsStatus.fallback));
    await tester.pumpAndSettle();
    expect(find.textContaining('Polling'), findsOneWidget);
  });
}
