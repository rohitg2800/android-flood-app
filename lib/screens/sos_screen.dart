// lib/screens/sos_screen.dart  v3.1 — stability + polish
//
// v3.1 polish:
// - simplify selected district state to StateProvider
// - use withValues consistently
// - make hold/reset animation more reliable after send/fail/reset
// - slightly tighten header/body spacing for better fit on smaller screens
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:equinox_flood/core/theme/river_theme.dart' as core_theme;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sos_provider.dart';
import '../services/sos_service.dart';
import '../theme/river_theme.dart';

final _connectivityProvider = StreamProvider<bool>((_) => Connectivity()
    .onConnectivityChanged
    .map((r) => !r.contains(ConnectivityResult.none)));

final _selectedDistrictProvider = StateProvider<String?>((_) => null);

class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});
  static const String route = '/sos';

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _holdArc;
  late final AnimationController _ripple;
  Timer? _holdTimer;
  static const _holdDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _holdArc = AnimationController(
      vsync: this,
      duration: _holdDuration,
    );
    _ripple = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _pulse.dispose();
    _holdArc.dispose();
    _ripple.dispose();
    super.dispose();
  }

  void _resetVisualState() {
    _holdTimer?.cancel();
    _holdArc.stop();
    _holdArc.reset();
    if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
    if (!_ripple.isAnimating) {
      _ripple.repeat();
    }
  }

  void _onHoldStart() {
    final phase = ref.read(sosProvider).phase;
    if (phase != SosPhase.idle) return;
    HapticFeedback.heavyImpact();
    ref.read(sosProvider.notifier).startConfirming();
    _holdArc.forward(from: 0);
    _holdTimer?.cancel();
    _holdTimer = Timer(_holdDuration, _onHoldComplete);
  }

  void _onHoldEnd() {
    if (ref.read(sosProvider).phase == SosPhase.confirming) {
      _holdTimer?.cancel();
      _holdArc.reverse();
      ref.read(sosProvider.notifier).cancelConfirm();
    }
  }

  Future<void> _onHoldComplete() async {
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    HapticFeedback.heavyImpact();
    await ref.read(sosProvider.notifier).confirm();
    _pulse.stop();
    _ripple.stop();
  }

  void _showDistrictPicker(BuildContext context, RiverColors t) {
    final districts = kDistrictContacts.keys.toList()..sort();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.navBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, sc) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.location_city_rounded, color: t.accent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Select District',
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(_selectedDistrictProvider.notifier).state = null;
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Clear',
                      style: TextStyle(color: t.riverDanger),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView.builder(
                controller: sc,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: districts.length,
                itemBuilder: (_, i) {
                  final d = districts[i];
                  final label = d
                      .split(' ')
                      .map((w) => w.isEmpty
                          ? ''
                          : '${w[0].toUpperCase()}${w.substring(1)}')
                      .join(' ');
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: t.cardBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      title: Text(
                        label,
                        style: TextStyle(
                          color: t.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded,
                          color: t.textSecondary),
                      onTap: () {
                        ref.read(_selectedDistrictProvider.notifier).state = d;
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final state = ref.watch(sosProvider);
    final online = ref.watch(_connectivityProvider).value ?? true;
    final selDist = ref.watch(_selectedDistrictProvider);

    final detectedDistrict = state.district ?? selDist;
    final districtContacts = detectedDistrict != null
        ? contactsForDistrict(detectedDistrict)
        : <EmergencyContact>[];

    final districtLabel = detectedDistrict
        ?.split(' ')
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');

    if (state.phase == SosPhase.idle && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
    if (state.phase == SosPhase.idle && !_ripple.isAnimating) {
      _ripple.repeat();
    }

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 244,
            pinned: true,
            stretch: true,
            backgroundColor: const Color(0xFF0D0608),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: Icon(Icons.location_city_rounded, color: t.accent),
                tooltip: 'Select District',
                onPressed: () => _showDistrictPicker(context, t),
              ),
              if (state.phase == SosPhase.sent ||
                  state.phase == SosPhase.failed)
                TextButton(
                  onPressed: () {
                    ref.read(sosProvider.notifier).reset();
                    _resetVisualState();
                  },
                  child: const Text(
                    'Reset',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0, 0.2),
                        radius: 1.0,
                        colors: [
                          Color(0xFF3A0808),
                          Color(0xFF1A0A0A),
                          Color(0xFF0D0D0D),
                        ],
                      ),
                    ),
                  ),
                  if (!online)
                    Positioned(
                      top: MediaQuery.of(context).padding.top,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.orange.shade800,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: const Row(
                          children: [
                            Icon(Icons.wifi_off, color: Colors.white, size: 14),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Offline — SMS/call still works over cellular',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 20,
                      ),
                      child: _SosButton(
                        pulse: _pulse,
                        holdArc: _holdArc,
                        ripple: _ripple,
                        phase: state.phase,
                        onHoldStart: _onHoldStart,
                        onHoldEnd: _onHoldEnd,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 18,
                    left: 0,
                    right: 0,
                    child: AnimatedOpacity(
                      opacity: state.phase == SosPhase.idle ? 1 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: const Text(
                        'Hold 3 seconds to send SOS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _StatusCard(state: state),
                if (state.phase == SosPhase.sent ||
                    state.phase == SosPhase.failed)
                  const SizedBox(height: 18),
                if (districtContacts.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.location_on_rounded,
                    color: t.riverDanger,
                    label: '${districtLabel ?? 'Your'} District',
                  ),
                  ...districtContacts.map((c) => _ContactCard(contact: c)),
                  const SizedBox(height: 8),
                ],
                if (districtContacts.isEmpty)
                  _DistrictPromptCard(
                    t: t,
                    onTap: () => _showDistrictPicker(context, t),
                  ),
                _SectionHeader(
                  icon: Icons.phone_in_talk_rounded,
                  color: t.accent,
                  label: 'National & State Helplines',
                ),
                ...kNationalContacts.map((c) => _ContactCard(contact: c)),
                const SizedBox(height: 18),
                _DisclaimerCard(t: t),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _DistrictPromptCard extends StatelessWidget {
  final RiverColors t;
  final VoidCallback onTap;
  const _DistrictPromptCard({required this.t, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: t.accent.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: t.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  Icon(Icons.location_city_rounded, color: t.accent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set Your District',
                    style: TextStyle(
                      color: t.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to get local emergency contacts',
                    style: TextStyle(color: t.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: t.accent),
          ],
        ),
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  final RiverColors t;
  const _DisclaimerCard({required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.warning_amber_rounded,
            color: t.riverDanger,
            text: 'Hold SOS only in genuine flood emergency.',
          ),
          _InfoRow(
            icon: Icons.location_on_outlined,
            color: t.riverWarning,
            text: 'GPS coordinates are sent with your alert.',
          ),
          _InfoRow(
            icon: Icons.info_rounded,
            color: t.accent,
            text: 'Tap the city icon in the toolbar to pick your district.',
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _SectionHeader(
      {required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SosButton extends StatelessWidget {
  final AnimationController pulse;
  final AnimationController holdArc;
  final AnimationController ripple;
  final SosPhase phase;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  const _SosButton({
    required this.pulse,
    required this.holdArc,
    required this.ripple,
    required this.phase,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = phase == SosPhase.idle || phase == SosPhase.confirming;

    return GestureDetector(
      onLongPressStart: isActive ? (_) => onHoldStart() : null,
      onLongPressEnd: isActive ? (_) => onHoldEnd() : null,
      onLongPressCancel: isActive ? onHoldEnd : null,
      child: SizedBox(
        width: 184,
        height: 184,
        child: AnimatedBuilder(
          animation: Listenable.merge([pulse, holdArc, ripple]),
          builder: (_, __) => CustomPaint(
            painter: _SosButtonPainter(
              arcProgress: holdArc.value,
              pulseValue: pulse.value,
              rippleValue: ripple.value,
              phase: phase,
            ),
            child: Center(
              child: Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: phase == SosPhase.sent
                        ? const [Color(0xFF1A3A1A), Color(0xFF0A1A0A)]
                        : [
                            Color.lerp(
                              const Color(0xFF5A1010),
                              const Color(0xFF8B1A1A),
                              pulse.value,
                            )!,
                            const Color(0xFF2A0808),
                          ],
                  ),
                  boxShadow: phase == SosPhase.sent
                      ? []
                      : [
                          BoxShadow(
                            color: const Color(0xFFFF3B30)
                                .withValues(alpha: 0.35 + 0.25 * pulse.value),
                            blurRadius: 28 + 14 * pulse.value,
                            spreadRadius: 4,
                          ),
                        ],
                ),
                child: _ButtonContent(phase: phase),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonContent extends StatelessWidget {
  final SosPhase phase;
  const _ButtonContent({required this.phase});

  @override
  Widget build(BuildContext context) {
    switch (phase) {
      case SosPhase.sending:
        return const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
        );
      case SosPhase.sent:
        return const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded,
                color: Color(0xFF4CAF50), size: 50),
            SizedBox(height: 4),
            Text(
              'SENT',
              style: TextStyle(
                color: Color(0xFF4CAF50),
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 2,
              ),
            ),
          ],
        );
      case SosPhase.failed:
        return const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_rounded, color: Color(0xFFFF3B30), size: 46),
            SizedBox(height: 4),
            Text(
              'FAILED',
              style: TextStyle(
                color: Color(0xFFFF3B30),
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
          ],
        );
      default:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sos_rounded, color: Colors.white, size: 54),
            const SizedBox(height: 4),
            Text(
              phase == SosPhase.confirming ? 'HOLD...' : 'SOS',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
                letterSpacing: 3,
              ),
            ),
          ],
        );
    }
  }
}

class _SosButtonPainter extends CustomPainter {
  final double arcProgress;
  final double pulseValue;
  final double rippleValue;
  final SosPhase phase;

  _SosButtonPainter({
    required this.arcProgress,
    required this.pulseValue,
    required this.rippleValue,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    if (phase == SosPhase.idle) {
      for (int i = 0; i < 2; i++) {
        final prog = (rippleValue - i * 0.5).clamp(0.0, 1.0);
        final radius = (size.width / 2 - 4) * (0.7 + 0.3 * prog);
        final alpha = (1.0 - prog) * 0.2;
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = const Color(0xFFFF3B30).withValues(alpha: alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }

    if (arcProgress > 0) {
      final rect = Rect.fromCenter(
        center: center,
        width: size.width - 10,
        height: size.height - 10,
      );
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * arcProgress,
        false,
        Paint()
          ..color = const Color(0xFFFF3B30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_SosButtonPainter old) =>
      old.arcProgress != arcProgress ||
      old.pulseValue != pulseValue ||
      old.rippleValue != rippleValue ||
      old.phase != phase;
}

class _StatusCard extends ConsumerWidget {
  final SosState state;
  const _StatusCard({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = RiverColors.of(context);

    if (state.phase == SosPhase.sent) {
      final distLabel = state.district
          ?.split(' ')
          .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D2B0D), Color(0xFF0A1A0A)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF4CAF50),
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SOS Alert Sent',
                    style: TextStyle(
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    state.lat != null
                        ? '${state.lat!.toStringAsFixed(5)}, ${state.lng!.toStringAsFixed(5)}${distLabel != null ? ' · $distLabel, Bihar' : ''}'
                        : 'Emergency services notified',
                    style: TextStyle(color: t.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (state.phase == SosPhase.failed) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2B0D0D), Color(0xFF1A0A0A)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFFF3B30).withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_rounded,
                  color: Color(0xFFFF3B30), size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SOS Failed',
                    style: TextStyle(
                      color: Color(0xFFFF3B30),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    state.errorMessage ?? 'Call NDRF directly: 011-24363260',
                    style: TextStyle(color: t.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _ContactCard extends ConsumerWidget {
  final EmergencyContact contact;
  const _ContactCard({required this.contact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = RiverColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: t.riverDanger.withValues(alpha: 0.15), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: t.riverDanger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.phone_in_talk_rounded,
                color: t.riverDanger, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: TextStyle(
                    color: t.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  contact.role,
                  style: TextStyle(color: t.textSecondary, fontSize: 11),
                ),
                Text(
                  contact.phone,
                  style: TextStyle(
                    color: t.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () async {
              HapticFeedback.selectionClick();
              final ok =
                  await ref.read(sosProvider.notifier).callContact(contact);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Cannot open dialler. Dial ${contact.phone} manually.',
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.red.shade700,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: t.riverDanger,
              foregroundColor: Colors.white,
              minimumSize: const Size(60, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
            child: const Text('Call'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
