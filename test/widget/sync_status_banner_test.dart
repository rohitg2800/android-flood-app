// test/widget/sync_status_banner_test.dart  Step 6.1 (fixed)
// Widget tests for SyncStatusBanner.
//
// FIX: wsStatusProvider is a StreamProvider<WsStatus>.
//   The overrideWith callback must return a Stream<WsStatus>, NOT a Future chain.
//   Using Stream.value(status) directly fixes the type error:
//   "A value of type Future<WsStatus> can't be returned from a function
//    with return type Stream<WsStatus>."

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
        // wsStatusProvider is StreamProvider<WsStatus> → override must return Stream<WsStatus>
        wsStatusProvider.overrideWith(
          (ref) => Stream.value(status),
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
