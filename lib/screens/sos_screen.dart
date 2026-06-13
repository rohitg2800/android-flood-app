// lib/screens/sos_screen.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';

class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  static const String route = '/sos';

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        title: Text('SOS Emergency',
            style: TextStyle(color: t.textPrimary)),
        backgroundColor: t.navBg,
        iconTheme: IconThemeData(color: t.riverDanger),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      t.riverDanger.withValues(alpha: 0.30 * _pulse.value),
                      t.riverDanger.withValues(alpha: 0.08 * _pulse.value),
                    ]),
                    border: Border.all(
                        color: t.riverDanger.withValues(alpha: 0.55),
                        width: 2),
                  ),
                  child: GestureDetector(
                    onTap: _onSosTap,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sos_rounded,
                            color: t.riverDanger, size: 52),
                        const SizedBox(height: 6),
                        Text('SEND SOS',
                            style: TextStyle(
                                color: t.riverDanger,
                                fontWeight: FontWeight.w900,
                                fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (_triggered)
                Td3Card(
                  elevation: Td3.elevMid,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: t.riverNormal, size: 40),
                        const SizedBox(height: 8),
                        Text('SOS Sent',
                            style: TextStyle(
                                color: t.riverNormal,
                                fontWeight: FontWeight.w700,
                                fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('Emergency services have been notified.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: t.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              _InfoRow(
                  icon: Icons.warning_amber_rounded,
                  color: t.riverDanger,
                  text: 'Tap SOS only in genuine flood emergency.'),
              _InfoRow(
                  icon: Icons.info_rounded,
                  color: t.riverWarning,
                  text: 'Authorities will be alerted with your location.'),
              _InfoRow(
                  icon: Icons.phone_rounded,
                  color: t.accent,
                  text: 'NDRF Helpline: 011-24363260'),
            ],
          ),
        ),
      ),
    );
  }

  void _onSosTap() {
    setState(() => _triggered = true);
    _pulse.stop();
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.color,
    required this.text,
  });
  final IconData icon;
  final Color    color;
  final String   text;

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: t.textSecondary, fontSize: 13))),
        ],
      ),
    );
  }
}
