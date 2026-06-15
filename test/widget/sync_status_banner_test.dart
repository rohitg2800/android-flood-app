// test/widget/sync_status_banner_test.dart  Step 6.1
// Widget tests for SyncStatusBanner:
//   • renders nothing (zero height) when status is Live
//   • shows orange banner when status is Connecting
//   • shows red banner when status is Offline
//   • shows amber banner when status is Stale (> 5 min old)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flood_app/widgets/sync_status_banner.dart';
import 'package:flood_app/providers/flood_providers.dart';
import 'package:flood_app/theme/river_theme.dart';

void main() {
  Widget _wrap(SyncStatus status) {
    return ProviderScope(
      overrides: [
        syncStatusProvider.overrideWith((_) => status),
      ],
      child: RiverTheme(
        child: const MaterialApp(
          home: Scaffold(body: SyncStatusBanner()),
        ),
      ),
    );
  }

  // ── 1. Live → hidden
  testWidgets('SyncStatusBanner is invisible when Live', (tester) async {
    await tester.pumpWidget(_wrap(SyncStatus.live));
    await tester.pumpAndSettle();

    // SizedBox.shrink renders as 0-size
    final sized = tester.widget<SizedBox>(find.byType(SizedBox).first);
    expect(sized.height, isNull); // SizedBox.shrink has no height set
    // Alternatively: no text visible
    expect(find.text('LIVE'), findsNothing);
  });

  // ── 2. Connecting → orange chip
  testWidgets('SyncStatusBanner shows Connecting chip', (tester) async {
    await tester.pumpWidget(_wrap(SyncStatus.connecting));
    await tester.pumpAndSettle();

    expect(find.textContaining('Connecting'), findsOneWidget);
  });

  // ── 3. Offline → red chip with icon
  testWidgets('SyncStatusBanner shows Offline chip', (tester) async {
    await tester.pumpWidget(_wrap(SyncStatus.offline));
    await tester.pumpAndSettle();

    expect(find.textContaining('Offline'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
  });

  // ── 4. Stale → amber chip
  testWidgets('SyncStatusBanner shows Stale chip', (tester) async {
    await tester.pumpWidget(_wrap(SyncStatus.stale));
    await tester.pumpAndSettle();

    expect(find.textContaining('Stale'), findsOneWidget);
  });
}
