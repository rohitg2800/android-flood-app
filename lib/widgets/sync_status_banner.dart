// lib/widgets/sync_status_banner.dart  v1.0 — Step 2.4
// Slim 28-px banner showing live WS / polling / offline state.
// Tapping the offline banner triggers a manual HTTP refresh.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ws_live_provider.dart';
import '../services/ws_gauge_service.dart';
import '../theme/river_theme.dart';

class SyncStatusBanner extends ConsumerWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(wsStatusProvider);
    final syncAsync   = ref.watch(lastSyncProvider);
    final t           = RiverColors.of(context);

    final status = statusAsync.valueOrNull ?? WsStatus.connecting;
    final lastSync = syncAsync.valueOrNull;

    Color  bg;
    Color  fg;
    IconData icon;
    String label;
    bool   tappable = false;

    switch (status) {
      case WsStatus.connected:
        bg   = AppPalette.safe.withOpacity(0.15);
        fg   = AppPalette.safe;
        icon = Icons.circle;
        label = '● Live';
        break;
      case WsStatus.connecting:
        bg   = AppPalette.gold.withOpacity(0.12);
        fg   = AppPalette.gold;
        icon = Icons.sync_rounded;
        label = 'Connecting…';
        break;
      case WsStatus.polling:
        final ago = lastSync == null
            ? ''
            : _agoLabel(lastSync);
        bg   = AppPalette.gold.withOpacity(0.12);
        fg   = AppPalette.gold;
        icon = Icons.cloud_sync_outlined;
        label = 'Synced $ago';
        break;
      case WsStatus.offline:
        final at = lastSync == null
            ? '—'
            : '${lastSync.hour.toString().padLeft(2,'0')}:${lastSync.minute.toString().padLeft(2,'0')}';
        bg   = AppPalette.critical.withOpacity(0.12);
        fg   = AppPalette.critical;
        icon = Icons.cloud_off_outlined;
        label = 'Offline — last data $at  •  Tap to retry';
        tappable = true;
        break;
    }

    Widget child = Container(
      height: 28,
      color: bg,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );

    if (tappable) {
      child = GestureDetector(
        onTap: () => ref.read(wsGaugeServiceProvider).forceRefresh(),
        child: child,
      );
    }

    return child;
  }

  String _agoLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return 'just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
