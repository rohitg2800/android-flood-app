// lib/screens/sos_screen.dart  v2.1
//
// v2.1 (14 Jun 2026) — Riverpod 3.x compat
//   FIX: StateProvider<String?> removed in Riverpod 3.x.
//        Replaced with NotifierProvider + _DistrictNotifier.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sos_provider.dart';
import '../services/sos_service.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';

// ── Connectivity helper ───────────────────────────────────────────────────────
final _connectivityProvider = StreamProvider<bool>((_) =>
    Connectivity()
        .onConnectivityChanged
        .map((r) => !r.contains(ConnectivityResult.none)));

// ── Selected-district provider (Riverpod 3.x — NotifierProvider) ─────────────
class _DistrictNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? v) => state = v;
}

final _selectedDistrictProvider =
    NotifierProvider<_DistrictNotifier, String?>(_DistrictNotifier.new);

// ─────────────────────────────────────────────────────────────────────────────
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
  Timer? _holdTimer;
  static const _holdDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _holdArc = AnimationController(
      vsync: this,
      duration: _holdDuration,
    );
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _pulse.dispose();
    _holdArc.dispose();
    super.dispose();
  }

  void _onHoldStart() {
    final phase = ref.read(sosProvider).phase;
    if (phase != SosPhase.idle) return;
    HapticFeedback.mediumImpact();
    ref.read(sosProvider.notifier).startConfirming();
    _holdArc.forward(from: 0);
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
    await ref.read(sosProvider.notifier).confirm();
    _pulse.stop();
  }

  void _showDistrictPicker(BuildContext context, RiverColors t) {
    final districts = kDistrictContacts.keys.toList()..sort();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.navBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, sc) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Select District',
                        style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(_selectedDistrictProvider.notifier).set(null);
                      Navigator.pop(context);
                    },
                    child: Text('Clear', style: TextStyle(color: t.accent)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: sc,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                itemCount: districts.length,
                itemBuilder: (_, i) {
                  final d = districts[i];
                  final label = d
                      .split(' ')
                      .map((w) => w.isEmpty
                          ? ''
                          : '${w[0].toUpperCase()}${w.substring(1)}')
                      .join(' ');
                  return ListTile(
                    title: Text(label,
                        style: TextStyle(
                            color: t.textPrimary,
                            fontWeight: FontWeight.w600)),
                    trailing: Icon(Icons.chevron_right_rounded,
                        color: t.textSecondary),
                    onTap: () {
                      ref
                          .read(_selectedDistrictProvider.notifier)
                          .set(d);
                      Navigator.pop(context);
                    },
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
    final t       = RiverColors.of(context);
    final state   = ref.watch(sosProvider);
    final online  = ref.watch(_connectivityProvider).value ?? true;
    final selDist = ref.watch(_selectedDistrictProvider);

    final detectedDistrict = state.district ?? selDist;
    final districtContacts = detectedDistrict != null
        ? contactsForDistrict(detectedDistrict)
        : <EmergencyContact>[];

    final districtLabel = detectedDistrict != null
        ? detectedDistrict
              .split(' ')
              .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
              .join(' ')
        : null;

    if (state.phase == SosPhase.idle && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        title: Text('SOS Emergency',
            style: TextStyle(color: t.textPrimary)),
        backgroundColor: t.navBg,
        iconTheme: IconThemeData(color: t.riverDanger),
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
                _holdArc.reset();
                _pulse.repeat(reverse: true);
              },
              child: Text('Reset',
                  style: TextStyle(color: t.riverDanger)),
            ),
        ],
      ),
      body: Column(
        children: [
          if (!online)
            Material(
              color: Colors.orange.shade700,
              child: const Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No internet — SMS/call will still work over cellular.',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── SOS button ──────────────────────────────────────────
                  Center(
                    child: _SosButton(
                      pulse:       _pulse,
                      holdArc:     _holdArc,
                      phase:       state.phase,
                      onHoldStart: _onHoldStart,
                      onHoldEnd:   _onHoldEnd,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: AnimatedOpacity(
                      opacity:
                          state.phase == SosPhase.idle ? 1 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        'Hold for 3 seconds to send SOS',
                        style: TextStyle(
                            color: t.textSecondary, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _StatusCard(state: state),
                  if (state.phase == SosPhase.sent ||
                      state.phase == SosPhase.failed)
                    const SizedBox(height: 28),

                  // ── District contacts ───────────────────────────────────
                  if (districtContacts.isNotEmpty) ...[
                    _SectionHeader(
                      icon:  Icons.location_on_rounded,
                      color: t.riverDanger,
                      label: districtLabel != null
                          ? '$districtLabel District'
                          : 'Your District',
                    ),
                    ...districtContacts
                        .map((c) => _ContactCard(contact: c)),
                    const SizedBox(height: 4),
                  ],

                  // ── District selector prompt ─────────────────────────────
                  if (districtContacts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showDistrictPicker(context, t),
                        icon: Icon(Icons.location_city_rounded,
                            color: t.accent, size: 16),
                        label: Text(
                          'Select your district for local contacts',
                          style: TextStyle(
                              color: t.accent, fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: t.accent.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                        ),
                      ),
                    ),

                  // ── National contacts ────────────────────────────────────
                  _SectionHeader(
                    icon:  Icons.phone_in_talk_rounded,
                    color: t.accent,
                    label: 'National & State',
                  ),
                  ...kNationalContacts
                      .map((c) => _ContactCard(contact: c)),

                  const SizedBox(height: 24),
                  _InfoRow(
                    icon:  Icons.warning_amber_rounded,
                    color: t.riverDanger,
                    text:  'Tap & hold SOS only in genuine flood emergency.',
                  ),
                  _InfoRow(
                    icon:  Icons.location_on_outlined,
                    color: t.riverWarning,
                    text:  'Your GPS coordinates are sent with the alert.',
                  ),
                  _InfoRow(
                    icon:  Icons.info_rounded,
                    color: t.accent,
                    text:
                        'Tap the city icon in the toolbar to pick your district.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label;
  const _SectionHeader(
      {required this.icon,
      required this.color,
      required this.label});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ── Hold-to-confirm SOS button ────────────────────────────────────────────────
class _SosButton extends StatelessWidget {
  final AnimationController pulse;
  final AnimationController holdArc;
  final SosPhase            phase;
  final VoidCallback        onHoldStart;
  final VoidCallback        onHoldEnd;

  const _SosButton({
    required this.pulse,
    required this.holdArc,
    required this.phase,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  @override
  Widget build(BuildContext context) {
    final t        = RiverColors.of(context);
    final isActive =
        phase == SosPhase.idle || phase == SosPhase.confirming;

    return GestureDetector(
      onLongPressStart:  isActive ? (_) => onHoldStart() : null,
      onLongPressEnd:    isActive ? (_) => onHoldEnd()   : null,
      onLongPressCancel: isActive ? onHoldEnd            : null,
      child: SizedBox(
        width: 180,
        height: 180,
        child: AnimatedBuilder(
          animation: Listenable.merge([pulse, holdArc]),
          builder: (_, __) => CustomPaint(
            painter: _SosArcPainter(
              arcProgress: holdArc.value,
              dangerColor: t.riverDanger,
              phase:       phase,
            ),
            child: Container(
              margin: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  t.riverDanger.withValues(
                      alpha: phase == SosPhase.sent
                          ? 0.10
                          : 0.30 * pulse.value),
                  t.riverDanger.withValues(
                      alpha: phase == SosPhase.sent
                          ? 0.04
                          : 0.08 * pulse.value),
                ]),
                border: Border.all(
                    color:
                        t.riverDanger.withValues(alpha: 0.55),
                    width: 2),
              ),
              child: _ButtonContent(phase: phase, t: t),
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonContent extends StatelessWidget {
  final SosPhase    phase;
  final RiverColors t;
  const _ButtonContent({required this.phase, required this.t});

  @override
  Widget build(BuildContext context) {
    switch (phase) {
      case SosPhase.sending:
        return Center(
            child: CircularProgressIndicator(
                color: t.riverDanger, strokeWidth: 3));
      case SosPhase.sent:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded,
                color: t.riverNormal, size: 48),
            const SizedBox(height: 4),
            Text('SENT',
                style: TextStyle(
                    color: t.riverNormal,
                    fontWeight: FontWeight.w900,
                    fontSize: 13)),
          ],
        );
      case SosPhase.failed:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_rounded,
                color: t.riverDanger, size: 44),
            const SizedBox(height: 4),
            Text('FAILED',
                style: TextStyle(
                    color: t.riverDanger,
                    fontWeight: FontWeight.w900,
                    fontSize: 13)),
          ],
        );
      default:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sos_rounded, color: t.riverDanger, size: 52),
            const SizedBox(height: 6),
            Text(
              phase == SosPhase.confirming ? 'HOLD...' : 'SEND SOS',
              style: TextStyle(
                  color: t.riverDanger,
                  fontWeight: FontWeight.w900,
                  fontSize: 14),
            ),
          ],
        );
    }
  }
}

class _SosArcPainter extends CustomPainter {
  final double   arcProgress;
  final Color    dangerColor;
  final SosPhase phase;
  _SosArcPainter({
    required this.arcProgress,
    required this.dangerColor,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (arcProgress <= 0) return;
    final rect = Rect.fromLTWH(
        6, 6, size.width - 12, size.height - 12);
    final paint = Paint()
      ..color       = dangerColor
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap   = StrokeCap.round;
    canvas.drawArc(
        rect, -math.pi / 2, 2 * math.pi * arcProgress, false, paint);
  }

  @override
  bool shouldRepaint(_SosArcPainter old) =>
      old.arcProgress != arcProgress || old.phase != phase;
}

// ── Status card ───────────────────────────────────────────────────────────────
class _StatusCard extends ConsumerWidget {
  final SosState state;
  const _StatusCard({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = RiverColors.of(context);

    if (state.phase == SosPhase.sent) {
      final distLabel = state.district != null
          ? state.district!
                .split(' ')
                .map((w) =>
                    '${w[0].toUpperCase()}${w.substring(1)}')
                .join(' ')
          : null;
      return Td3Card(
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
              Text(
                state.lat != null
                    ? 'Location: ${state.lat!.toStringAsFixed(5)}, '
                        '${state.lng!.toStringAsFixed(5)}'
                        '${distLabel != null ? "\n$distLabel District, Bihar" : ""}'
                    : 'Emergency services notified. Location unavailable.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: t.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (state.phase == SosPhase.failed) {
      return Td3Card(
        elevation: Td3.elevMid,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.error_rounded,
                  color: t.riverDanger, size: 40),
              const SizedBox(height: 8),
              Text('SOS Failed',
                  style: TextStyle(
                      color: t.riverDanger,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                state.errorMessage ??
                    'Unknown error. Call NDRF: 011-24363260 directly.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: t.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

// ── Emergency contact card ────────────────────────────────────────────────────
class _ContactCard extends ConsumerWidget {
  final EmergencyContact contact;
  const _ContactCard({required this.contact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = RiverColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: t.riverDanger.withValues(alpha: 0.18), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.name,
                    style: TextStyle(
                        color: t.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text(contact.role,
                    style: TextStyle(
                        color: t.textSecondary, fontSize: 11)),
                Text(contact.phone,
                    style: TextStyle(
                        color: t.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () async {
              HapticFeedback.selectionClick();
              final ok = await ref
                  .read(sosProvider.notifier)
                  .callContact(contact);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Cannot open dialler. Dial ${contact.phone} manually.',
                      style:
                          const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.red.shade700,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            },
            icon: const Icon(Icons.phone, size: 16),
            label: const Text('Call'),
            style: FilledButton.styleFrom(
              backgroundColor: t.riverDanger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              textStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────
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
                    color: t.textSecondary, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
