// lib/screens/cwc_station_detail_screen.dart  v4
// Emergency contacts card injected directly after Status section.
// Contacts are resolved from EmergencyContactService.getContactsForStation()
// using the station's site name → district mapping.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/befiqr_cwc_service.dart';
import '../services/emergency_contact_service.dart';
import '../services/kosi_birpur_service.dart';
import '../theme/river_theme.dart';
import '../widgets/ai_prediction_panel.dart';

class CwcStationDetailScreen extends StatelessWidget {
  final CwcStation station;

  /// Only non-null when station is Kosi @ Birpur.
  final KosiBirpurReading? birpurReading;

  const CwcStationDetailScreen({
    super.key,
    required this.station,
    this.birpurReading,
  });

  // ── helpers ──────────────────────────────────────────────────────────────

  bool get _isBirpur =>
      station.river.toLowerCase().contains('kosi') &&
      station.site.toLowerCase().contains('birpur');

  Color get _statusColor {
    if (station.isDanger)   return AppPalette.critical;
    if (station.isWarning)  return AppPalette.danger;
    if (station.isElevated) return AppPalette.amber;
    return AppPalette.safe;
  }

  double get _riskPct =>
      (station.currentLevel / station.dangerLevel).clamp(0.0, 1.0);

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;
    final bp    = birpurReading;
    final isStale = bp != null &&
        DateTime.now().difference(bp.observedAt).inHours >= 2;

    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      appBar: AppBar(
        backgroundColor: AppPalette.abyss0,
        foregroundColor: AppPalette.textWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              station.site,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.textWhite),
            ),
            Text(
              '${station.river}  ·  Bihar CWC',
              style: const TextStyle(
                  fontSize: 11, color: AppPalette.textGrey),
            ),
          ],
        ),
        actions: [
          if (_isBirpur && bp != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _SourceBadge(source: bp.source, isStale: isStale),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _StatusBadge(label: station.statusLabel, color: color),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Hero arc gauge ────────────────────────────────────────────
            Center(
              child: _HeroGauge(
                percent: _riskPct,
                color:   color,
                label:   station.statusLabel,
                level:   station.currentLevel,
                danger:  station.dangerLevel,
              ),
            ),
            const SizedBox(height: 20),

            // ── Level grid ────────────────────────────────────────────────
            _SectionTitle('Water Level'),
            _LevelGrid(station: station, color: color, bp: bp),
            const SizedBox(height: 16),

            // ── Risk bar ──────────────────────────────────────────────────
            _SectionTitle('Fill Progress'),
            _RiskBar(
              current: station.currentLevel,
              warning: station.dangerLevel * 0.97,
              danger:  station.dangerLevel,
              color:   color,
            ),
            const SizedBox(height: 20),

            // ── AI Prediction (auto-fed) ──────────────────────────────────
            _SectionTitle('AI Flood Prediction'),
            AiPredictionPanel(stationKey: station.site),
            const SizedBox(height: 16),

            // ── Birpur-specific live block ─────────────────────────────────
            if (_isBirpur && bp != null) ...[
              _SectionTitle('Live Birpur Telemetry'),
              _BirpurLiveCard(bp: bp, color: color, isStale: isStale),
              const SizedBox(height: 16),
            ],

            // ── Station meta ──────────────────────────────────────────────
            _SectionTitle('Station Info'),
            _MetaCard(station: station, color: color),
            const SizedBox(height: 16),

            // ── Status timeline ───────────────────────────────────────────
            _SectionTitle('Status'),
            _StatusTimeline(station: station, color: color),
            const SizedBox(height: 20),

            // ── Emergency Contacts ────────────────────────────────────────
            _SectionTitle('Emergency Contacts'),
            _EmergencyContactsCard(
              stationName: station.site,
              statusColor: color,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Emergency Contacts Card ────────────────────────────────────────────────────

class _EmergencyContactsCard extends StatefulWidget {
  final String stationName;
  final Color  statusColor;
  const _EmergencyContactsCard({
    required this.stationName,
    required this.statusColor,
  });

  @override
  State<_EmergencyContactsCard> createState() =>
      _EmergencyContactsCardState();
}

class _EmergencyContactsCardState
    extends State<_EmergencyContactsCard> {
  final _svc = EmergencyContactService();
  late Future<List<EmergencyContact>> _future;

  // Category → icon map
  static IconData _iconFor(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('ndrf'))   return Icons.shield_rounded;
    if (c.contains('sdrf'))   return Icons.local_police_rounded;
    if (c.contains('ndma'))   return Icons.crisis_alert_rounded;
    if (c.contains('cwc'))    return Icons.water_rounded;
    if (c.contains('dist'))   return Icons.account_balance_rounded;
    if (c.contains('barrage')) return Icons.water_damage_rounded;
    if (c.contains('medic'))  return Icons.local_hospital_rounded;
    if (c.contains('fire'))   return Icons.local_fire_department_rounded;
    return Icons.phone_in_talk_rounded;
  }

  // Category → accent colour
  Color _colorFor(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('ndrf'))   return AppPalette.cyan;
    if (c.contains('sdrf'))   return AppPalette.amber;
    if (c.contains('ndma'))   return AppPalette.critical;
    if (c.contains('cwc'))    return AppPalette.safe;
    if (c.contains('dist'))   return AppPalette.gold;
    if (c.contains('barrage')) return AppPalette.danger;
    if (c.contains('medic'))  return AppPalette.safe;
    return AppPalette.textGrey;
  }

  @override
  void initState() {
    super.initState();
    _future = _svc.getContactsForStation(widget.stationName);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EmergencyContact>>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(
            height: 80,
            decoration: BoxDecoration(
              color: AppPalette.abyss1,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppPalette.cyan),
              ),
            ),
          );
        }

        final contacts = snap.data ?? [];
        if (contacts.isEmpty) {
          return _emptyState();
        }

        // Sort: SOS first, then by category
        final sorted = [...contacts]
          ..sort((a, b) {
            if (a.isSOS && !b.isSOS) return -1;
            if (!a.isSOS && b.isSOS) return 1;
            return a.category.compareTo(b.category);
          });

        // Resolve district label for header
        final district = _svc.districtForStation(widget.stationName);
        final headerLabel = district != null
            ? '$district District'
            : 'All Bihar';

        return Container(
          decoration: BoxDecoration(
            color: AppPalette.abyss1,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.statusColor.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Row(children: [
                  Icon(Icons.location_on_rounded,
                      size: 13, color: widget.statusColor),
                  const SizedBox(width: 5),
                  Text(
                    headerLabel,
                    style: TextStyle(
                      color: widget.statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${sorted.length} contacts',
                    style: const TextStyle(
                      color: AppPalette.textGrey,
                      fontSize: 10,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              const Divider(
                  color: AppPalette.abyss2, height: 1, indent: 14, endIndent: 14),

              // Contact rows
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sorted.length,
                separatorBuilder: (_, __) => const Divider(
                    color: AppPalette.abyss2, height: 1,
                    indent: 14, endIndent: 14),
                itemBuilder: (_, i) {
                  final c = sorted[i];
                  final accent = _colorFor(c.category);
                  return _ContactRow(
                    contact: c,
                    accent: accent,
                    icon: _iconFor(c.category),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyState() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppPalette.abyss1,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(children: [
          Icon(Icons.info_outline_rounded,
              color: AppPalette.textGrey, size: 18),
          SizedBox(width: 10),
          Text('No contacts available for this station.',
              style: TextStyle(
                  color: AppPalette.textGrey, fontSize: 12)),
        ]),
      );
}

// ─── Single Contact Row ─────────────────────────────────────────────────────────

class _ContactRow extends StatelessWidget {
  final EmergencyContact contact;
  final Color            accent;
  final IconData         icon;
  const _ContactRow({
    required this.contact,
    required this.accent,
    required this.icon,
  });

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: contact.phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _copyNumber(BuildContext ctx) async {
    await Clipboard.setData(ClipboardData(text: contact.phone));
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text('${contact.phone} copied'),
          backgroundColor: AppPalette.abyss2,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _call,
      onLongPress: () => _copyNumber(context),
      borderRadius: BorderRadius.circular(0),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 11),
        child: Row(children: [
          // Category icon bubble
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                  color: accent.withValues(alpha: 0.30)),
            ),
            child: Icon(icon, color: accent, size: 16),
          ),
          const SizedBox(width: 12),

          // Name + category
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(
                      contact.name,
                      style: const TextStyle(
                        color: AppPalette.textWhite,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (contact.isSOS) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppPalette.critical
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: AppPalette.critical
                                .withValues(alpha: 0.35)),
                      ),
                      child: const Text('SOS',
                          style: TextStyle(
                            color: AppPalette.critical,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          )),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(
                  contact.category,
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (contact.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    contact.description!,
                    style: const TextStyle(
                      color: AppPalette.textGrey,
                      fontSize: 9,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Phone number + call button
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                contact.phone,
                style: TextStyle(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: accent.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.call_rounded,
                        color: accent, size: 10),
                    const SizedBox(width: 3),
                    Text('CALL',
                        style: TextStyle(
                          color: accent,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        )),
                  ],
                ),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}

// ─── Hero Gauge ─────────────────────────────────────────────────────────────────

class _HeroGauge extends StatelessWidget {
  final double percent, danger, level;
  final Color  color;
  final String label;
  const _HeroGauge({
    required this.percent,
    required this.color,
    required this.label,
    required this.level,
    required this.danger,
  });

  @override
  Widget build(BuildContext context) {
    const size = 180.0;
    return SizedBox(
      width: size, height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(size, size),
            painter: _ArcPainter(percent: percent, color: color),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(percent * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                    color: color,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    height: 1.0),
              ),
              const SizedBox(height: 2),
              const Text('of danger level',
                  style: TextStyle(
                      color: AppPalette.textGrey, fontSize: 10)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: color.withValues(alpha: 0.40)),
                ),
                child: Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double percent;
  final Color  color;
  static const _start = math.pi * 0.75;
  static const _sweep = math.pi * 1.5;
  const _ArcPainter({required this.percent, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r  = size.width / 2 - 12;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    canvas.drawArc(rect, _start, _sweep, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..color = AppPalette.abyss2);
    if (percent > 0) {
      canvas.drawArc(rect, _start, _sweep * percent.clamp(0, 1), false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 14
            ..strokeCap = StrokeCap.round
            ..shader = SweepGradient(
              startAngle: _start,
              endAngle:   _start + _sweep,
              colors: [color.withValues(alpha: 0.4), color],
            ).createShader(rect));
    }
    final wAngle = _start + _sweep * 0.97;
    canvas.drawLine(
      Offset(cx + (r - 14) * math.cos(wAngle),
             cy + (r - 14) * math.sin(wAngle)),
      Offset(cx + (r + 4)  * math.cos(wAngle),
             cy + (r + 4)  * math.sin(wAngle)),
      Paint()
        ..color = AppPalette.warning
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter o) =>
      o.percent != percent || o.color != color;
}

// ─── Level Grid ─────────────────────────────────────────────────────────────────

class _LevelGrid extends StatelessWidget {
  final CwcStation         station;
  final Color              color;
  final KosiBirpurReading? bp;
  const _LevelGrid(
      {required this.station, required this.color, required this.bp});

  @override
  Widget build(BuildContext context) {
    final gap = station.dangerLevel - station.currentLevel;
    final gapColor =
        station.isDanger ? AppPalette.critical : AppPalette.safe;

    return Column(children: [
      Row(children: [
        _Tile(label: 'Current Level',
            value: '${station.currentLevel.toStringAsFixed(2)} m',
            color: color, icon: Icons.height_rounded),
        const SizedBox(width: 8),
        _Tile(label: 'Danger Level',
            value: '${station.dangerLevel.toStringAsFixed(2)} m',
            color: AppPalette.danger, icon: Icons.warning_amber_rounded),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        _Tile(
            label: station.isDanger ? 'Above Danger' : 'Gap to Danger',
            value: '${gap.abs().toStringAsFixed(2)} m',
            color: gapColor,
            icon: station.isDanger
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded),
        const SizedBox(width: 8),
        bp?.dischargeCumecs != null
            ? _Tile(
                label: 'Discharge',
                value:
                    '${bp!.dischargeCumecs!.toStringAsFixed(0)} m³/s',
                color: AppPalette.cyan,
                icon: Icons.water_rounded)
            : _Tile(
                label: 'Risk Score',
                value:
                    '${BefiqrCwcService.riskScore(station).toStringAsFixed(1)}%',
                color: AppPalette.gold,
                icon: Icons.speed_rounded),
      ]),
      if (bp != null) ...[
        const SizedBox(height: 8),
        Row(children: [
          _Tile(
              label: 'Warning Level',
              value: '${bp!.warningLevel.toStringAsFixed(2)} m',
              color: AppPalette.amber,
              icon: Icons.notifications_active_outlined),
          const SizedBox(width: 8),
          _Tile(
              label: 'Danger Discharge',
              value:
                  '${kBirpurDangerDischarge.toStringAsFixed(0)} m³/s',
              color: AppPalette.danger,
              icon: Icons.stream_rounded),
        ]),
      ],
    ]);
  }
}

class _Tile extends StatelessWidget {
  final String   label, value;
  final Color    color;
  final IconData icon;
  const _Tile(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppPalette.abyss1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.1)),
                  Text(label,
                      style: const TextStyle(
                          color: AppPalette.textGrey,
                          fontSize: 9,
                          height: 1.3)),
                ],
              ),
            ),
          ]),
        ),
      );
}

// ─── Risk Bar ───────────────────────────────────────────────────────────────────

class _RiskBar extends StatelessWidget {
  final double current, warning, danger;
  final Color  color;
  const _RiskBar(
      {required this.current,
      required this.warning,
      required this.danger,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final pct  = danger > 0 ? (current / danger).clamp(0.0, 1.0) : 0.0;
    final wPct = danger > 0 ? (warning / danger).clamp(0.0, 1.0) : 0.65;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (_, box) {
          return Stack(clipBehavior: Clip.none, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 16,
                color: AppPalette.abyss2,
                child: FractionallySizedBox(
                  widthFactor: pct,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                          colors: [color.withValues(alpha: 0.5), color]),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: box.maxWidth * wPct - 1.5,
              top: -4,
              child: Container(
                width: 3, height: 24,
                decoration: BoxDecoration(
                  color: AppPalette.warning,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ]);
        }),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${current.toStringAsFixed(2)} m',
                style: TextStyle(
                    color: color, fontSize: 11,
                    fontWeight: FontWeight.w700)),
            Text('⚠ ${warning.toStringAsFixed(2)} m',
                style: TextStyle(
                    color: AppPalette.warning, fontSize: 11)),
            Text('🔴 ${danger.toStringAsFixed(2)} m',
                style: TextStyle(
                    color: AppPalette.danger, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}

// ─── Birpur Live Card ───────────────────────────────────────────────────────────

class _BirpurLiveCard extends StatelessWidget {
  final KosiBirpurReading bp;
  final Color color;
  final bool  isStale;
  const _BirpurLiveCard(
      {required this.bp, required this.color, required this.isStale});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.sensors_rounded, color: color, size: 15),
              const SizedBox(width: 6),
              Text('Live Kosi @ Birpur Barrage',
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              isStale
                  ? _pill('STALE', AppPalette.amber)
                  : _pill(
                      DateFormat('dd MMM · HH:mm').format(bp.observedAt),
                      AppPalette.safe),
            ]),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _LiveStat(icon: Icons.height_rounded,
                    label: 'Water Level',
                    value: '${bp.levelM.toStringAsFixed(2)} m',
                    color: color),
                if (bp.dischargeCumecs != null)
                  _LiveStat(icon: Icons.water_rounded,
                      label: 'Discharge',
                      value:
                          '${bp.dischargeCumecs!.toStringAsFixed(0)} m³/s',
                      color: AppPalette.cyan),
                _LiveStat(icon: Icons.trending_down_rounded,
                    label: 'Gap to Danger',
                    value: '${bp.gap.toStringAsFixed(2)} m',
                    color: bp.isDanger
                        ? AppPalette.critical
                        : AppPalette.safe),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppPalette.abyss1,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(children: [
                _ThreshRow('Source', bp.source, AppPalette.textGrey),
                const SizedBox(height: 6),
                _ThreshRow('Warning threshold',
                    '${bp.warningLevel.toStringAsFixed(2)} m',
                    AppPalette.amber),
                const SizedBox(height: 6),
                _ThreshRow('Danger threshold',
                    '${bp.dangerLevel.toStringAsFixed(2)} m',
                    AppPalette.danger),
                if (bp.dischargeCumecs != null) ...[
                  const SizedBox(height: 6),
                  _ThreshRow('Warning discharge',
                      '${kBirpurWarningDischarge.toStringAsFixed(0)} m³/s',
                      AppPalette.amber),
                  const SizedBox(height: 6),
                  _ThreshRow('Danger discharge',
                      '${kBirpurDangerDischarge.toStringAsFixed(0)} m³/s',
                      AppPalette.danger),
                ],
              ]),
            ),
          ],
        ),
      );

  Widget _pill(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withValues(alpha: 0.35)),
        ),
        child: Text(text,
            style: TextStyle(
                color: c,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3)),
      );
}

class _LiveStat extends StatelessWidget {
  final IconData icon;
  final String   label, value;
  final Color    color;
  const _LiveStat(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});
  @override
  Widget build(BuildContext context) => Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(
                color: AppPalette.textGrey, fontSize: 9)),
      ]);
}

class _ThreshRow extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _ThreshRow(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppPalette.textGrey, fontSize: 11)),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      );
}

// ─── Station Meta Card ──────────────────────────────────────────────────────────

class _MetaCard extends StatelessWidget {
  final CwcStation station;
  final Color      color;
  const _MetaCard({required this.station, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppPalette.abyss1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Column(children: [
          _Row(Icons.water_outlined, 'River', station.river, color),
          const Divider(color: AppPalette.abyss2, height: 14),
          _Row(Icons.map_outlined, 'State', 'Bihar', color),
          const Divider(color: AppPalette.abyss2, height: 14),
          _Row(Icons.business_outlined, 'Authority', 'CWC', color),
          const Divider(color: AppPalette.abyss2, height: 14),
          _Row(Icons.access_time_rounded, 'Data as of',
              DateFormat('dd MMM yyyy HH:mm').format(station.fetchedAt),
              color),
          if (station.source.isNotEmpty) ...[
            const Divider(color: AppPalette.abyss2, height: 14),
            _Row(Icons.cloud_download_outlined, 'Live source',
                station.source, color),
          ],
        ]),
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String   label, value;
  final Color    color;
  const _Row(this.icon, this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.75)),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                color: AppPalette.textGrey, fontSize: 11)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                color: AppPalette.textWhite,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ]);
}

// ─── Status Timeline ────────────────────────────────────────────────────────────

class _StatusTimeline extends StatelessWidget {
  final CwcStation station;
  final Color      color;
  const _StatusTimeline({required this.station, required this.color});

  @override
  Widget build(BuildContext context) {
    final items = [
      _TLItem('Normal',  AppPalette.safe,
          !station.isElevated && !station.isWarning && !station.isDanger),
      _TLItem('Watch',   AppPalette.amber,    station.isElevated),
      _TLItem('Warning', AppPalette.warning,  station.isWarning),
      _TLItem('Danger',  AppPalette.critical, station.isDanger),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.abyss1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
          children:
              items.map((i) => _TimelineRow(item: i)).toList()),
    );
  }
}

class _TLItem {
  final String label;
  final Color  color;
  final bool   active;
  const _TLItem(this.label, this.color, this.active);
}

class _TimelineRow extends StatelessWidget {
  final _TLItem item;
  const _TimelineRow({required this.item});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.active
                  ? item.color
                  : item.color.withValues(alpha: 0.20),
              border: item.active
                  ? Border.all(
                      color: item.color.withValues(alpha: 0.60),
                      width: 2)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Text(item.label,
              style: TextStyle(
                  color: item.active ? item.color : AppPalette.textGrey,
                  fontSize: 12,
                  fontWeight: item.active
                      ? FontWeight.w800
                      : FontWeight.w400)),
          if (item.active) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('CURRENT',
                  style: TextStyle(
                      color: item.color,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5)),
            ),
          ],
        ]),
      );
}

// ─── Shared tiny widgets ────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                color: AppPalette.textGrey,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2)),
      );
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color  color;
  const _StatusBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.40)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800)),
      );
}

class _SourceBadge extends StatelessWidget {
  final String source;
  final bool   isStale;
  const _SourceBadge({required this.source, required this.isStale});

  static Color _accentFor(String src) {
    final s = src.toLowerCase();
    if (s.contains('beams'))          return AppPalette.gold;
    if (s.contains('cwc') ||
        s.contains('ffs') ||
        s.contains('wris'))           return AppPalette.cyan;
    if (s.contains('befiqr'))         return AppPalette.safe;
    return AppPalette.textGrey;
  }

  @override
  Widget build(BuildContext context) {
    final Color c = isStale ? AppPalette.amber : _accentFor(source);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.40)),
      ),
      child: Text(
        isStale ? 'STALE · $source' : source,
        style: TextStyle(
            color: c,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3),
      ),
    );
  }
}
