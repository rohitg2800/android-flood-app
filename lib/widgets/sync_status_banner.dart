// lib/widgets/sync_status_banner.dart  Step 2.4
// Slim 28px banner shown below the AppBar on Dashboard + RiverMonitor.
// Shows live/fallback/offline state with last-sync timestamp.

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
    final lastSync    = ref.watch(wsLastSyncProvider);
    // ignore: unused_local_variable
    final t = RiverColors.of(context);

    final status = statusAsync.when(
      data:    (s) => s,
      loading: ()  => WsStatus.connecting,
      error:   (_, __) => WsStatus.offline,
    );

    final cfg = _BannerConfig.from(status, lastSync);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      height:   cfg.visible ? 28 : 0,
      color:    cfg.bgColor.withOpacity(0.92),
      child: cfg.visible
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pulsing dot for live state
                if (status == WsStatus.connected)
                  _PulseDot(color: cfg.dotColor)
                else
                  Icon(cfg.icon, size: 12, color: cfg.dotColor),
                const SizedBox(width: 6),
                Text(
                  cfg.label,
                  style: TextStyle(
                    color:      cfg.textColor,
                    fontSize:   11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}

// ── Pulse animation for the live dot ──────────────────────────────────────

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: widget.color.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Banner config helper ───────────────────────────────────────────────────

class _BannerConfig {
  final bool    visible;
  final Color   bgColor, dotColor, textColor;
  final IconData icon;
  final String  label;

  const _BannerConfig({
    required this.visible,
    required this.bgColor,
    required this.dotColor,
    required this.textColor,
    required this.icon,
    required this.label,
  });

  static _BannerConfig from(WsStatus status, DateTime? lastSync) {
    switch (status) {
      case WsStatus.connected:
        return _BannerConfig(
          visible:   false,   // Live = no banner needed (data flows silently)
          bgColor:   AppPalette.safe.withOpacity(0.15),
          dotColor:  AppPalette.safe,
          textColor: AppPalette.safe,
          icon:      Icons.circle,
          label:     'LIVE',
        );

      case WsStatus.connecting:
        return _BannerConfig(
          visible:   true,
          bgColor:   AppPalette.gold.withOpacity(0.12),
          dotColor:  AppPalette.gold,
          textColor: AppPalette.gold,
          icon:      Icons.sync_rounded,
          label:     'Connecting…',
        );

      case WsStatus.fallback:
        final ago = lastSync != null
            ? _timeAgo(lastSync)
            : 'recently';
        return _BannerConfig(
          visible:   true,
          bgColor:   AppPalette.warning.withOpacity(0.12),
          dotColor:  AppPalette.warning,
          textColor: AppPalette.warning,
          icon:      Icons.wifi_off_rounded,
          label:     'Polling — synced $ago',
        );

      case WsStatus.offline:
        final ago = lastSync != null
            ? 'Last data ${_timeAgo(lastSync)}'
            : 'No data yet';
        return _BannerConfig(
          visible:   true,
          bgColor:   AppPalette.critical.withOpacity(0.12),
          dotColor:  AppPalette.critical,
          textColor: AppPalette.critical,
          icon:      Icons.cloud_off_rounded,
          label:     'Offline — $ago',
        );
    }
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60)  return '${diff.inMinutes} min ago';
    return '${diff.inHours}h ago';
  }
}
