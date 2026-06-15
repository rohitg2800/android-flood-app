// lib/screens/river_monitor_screen.dart  v2.0.1
//
// v2.0.1 (15 Jun 2026) — fix literal \n in spread operators

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/flood_data.dart';
import '../providers/flood_providers.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import '../app_router.dart';

class RiverMonitorScreen extends ConsumerStatefulWidget {
  const RiverMonitorScreen({super.key});
  static const String route = Routes.riverMonitor;

  @override
  ConsumerState<RiverMonitorScreen> createState() => _RiverMonitorScreenState();
}

class _RiverMonitorScreenState extends ConsumerState<RiverMonitorScreen>
    with TickerProviderStateMixin {
  String _query = '';
  final _searchCtrl = TextEditingController();
  late final AnimationController _headerAnim;
  late final AnimationController _rippleAnim;
  late final Animation<double>   _headerFade;
  late final Animation<double>   _headerSlide;

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
    _rippleAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat();
    _headerFade  = CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);
    _headerSlide = Tween<double>(begin: 32, end: 0)
        .animate(CurvedAnimation(parent: _headerAnim, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _headerAnim.dispose();
    _rippleAnim.dispose();
    super.dispose();
  }

  List<FloodData> _filtered(List<FloodData> all) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all.where((fd) =>
        fd.city.toLowerCase().contains(q) ||
        fd.state.toLowerCase().contains(q) ||
        fd.district.toLowerCase().contains(q) ||
        (fd.riverName?.toLowerCase().contains(q) ?? false)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rawAll    = ref.watch(liveLevelsProvider);
    final loading   = ref.watch(isLoadingProvider);
    final offline   = ref.watch(isOfflineProvider);
    final lastFetch = ref.watch(lastFetchTimeProvider);
    final t         = RiverColors.of(context);

    final all = [...rawAll]..sort((a, b) {
        final sa = (a.riskScore ?? 0).toDouble();
        final sb = (b.riskScore ?? 0).toDouble();
        return sb.compareTo(sa);
      });

    final levels = _filtered(all);

    int critCount = all.where((d) => d.riskLevel.toUpperCase() == 'CRITICAL').length;
    int sevCount  = all.where((d) => d.riskLevel.toUpperCase() == 'SEVERE').length;

    for (final d in all) {
      final ml = d.predictedSeverity?.toUpperCase();
      final rl = d.riskLevel.toUpperCase();
      if (ml == 'CRITICAL' && rl != 'CRITICAL') critCount++;
      if (ml == 'SEVERE'   && rl != 'SEVERE' && rl != 'CRITICAL') sevCount++;
    }

    final normCount   = all.length - critCount - sevCount;
    final breachCount = all.where((d) => d.willBreachDanger == true).length;

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _headerAnim,
              builder: (_, __) => Opacity(
                opacity: _headerFade.value,
                child: Transform.translate(
                  offset: Offset(0, _headerSlide.value),
                  child: _HeroHeader(
                    ripple:      _rippleAnim,
                    t:           t,
                    total:       all.length,
                    critCount:   critCount,
                    sevCount:    sevCount,
                    normCount:   normCount,
                    breachCount: breachCount,
                    offline:     offline,
                    lastFetch:   lastFetch,
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: _SearchBar(
                ctrl: _searchCtrl,
                query: _query,
                t: t,
                onChanged: (v) => setState(() => _query = v),
                onClear: () { _searchCtrl.clear(); setState(() => _query = ''); },
              ),
            ),
          ),

          if (all.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                child: _SummaryStrip(
                    t: t, total: all.length,
                    crit: critCount, sev: sevCount,
                    norm: normCount, breach: breachCount),
              ),
            ),

          if (offline)
            SliverToBoxAdapter(
              child: _StatusBanner(
                icon: Icons.wifi_off_rounded,
                color: AppPalette.warning,
                text: 'No internet — showing cached data',
                t: t,
              ),
            )
          else if (lastFetch != null)
            SliverToBoxAdapter(
              child: _StatusBanner(
                icon: Icons.check_circle_rounded,
                color: t.accent,
                text: 'Last updated ${DateFormat('HH:mm').format(lastFetch)}',
                t: t,
              ),
            ),

          if (loading && all.isEmpty)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (levels.isEmpty)
            SliverFillRemaining(
              child: _EmptyState(t: t, query: _query),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _AnimatedCard(
                    index: i,
                    child: _RiverCard(
                      data: levels[i],
                      t: t,
                      onTap: () => Navigator.of(ctx).pushNamed(
                        Routes.cityDetail,
                        arguments: levels[i].city,
                      ),
                    ),
                  ),
                  childCount: levels.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HeroHeader
// ─────────────────────────────────────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  final AnimationController ripple;
  final RiverColors t;
  final int total, critCount, sevCount, normCount, breachCount;
  final bool offline;
  final DateTime? lastFetch;
  const _HeroHeader({
    required this.ripple,
    required this.t,
    required this.total,
    required this.critCount,
    required this.sevCount,
    required this.normCount,
    required this.breachCount,
    required this.offline,
    required this.lastFetch,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 220,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [t.accent.withOpacity(0.22), t.scaffoldBg],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: ripple,
            builder: (_, __) => CustomPaint(
              painter: _RipplePainter(
                progress: ripple.value,
                color: critCount > 0 ? AppPalette.critical : t.accent,
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: t.accent.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: t.accent.withOpacity(0.4)),
                      ),
                      child: Icon(Icons.monitor_heart_outlined,
                          color: t.accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('River Monitor',
                            style: TextStyle(
                                color: t.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5)),
                        Text(
                          offline
                              ? '● Offline — cached data'
                              : lastFetch != null
                                  ? 'Live · ${DateFormat("HH:mm").format(lastFetch!)}'
                                  : 'Bihar Flood Operations',
                          style: TextStyle(
                              color: offline ? AppPalette.warning : t.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7B2FF7).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF7B2FF7).withOpacity(0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_graph, color: Color(0xFF7B2FF7), size: 12),
                          SizedBox(width: 4),
                          Text('ML Ranked',
                              style: TextStyle(
                                  color: Color(0xFF7B2FF7),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _StatTile(label: 'Total',    value: '$total',       color: t.accent,               icon: Icons.water_outlined),
                    const SizedBox(width: 8),
                    _StatTile(label: 'Critical', value: '$critCount',   color: AppPalette.critical,    icon: Icons.warning_amber_rounded),
                    const SizedBox(width: 8),
                    _StatTile(label: 'Severe',   value: '$sevCount',    color: AppPalette.danger,      icon: Icons.warning_rounded),
                    const SizedBox(width: 8),
                    _StatTile(label: 'Breach↑',  value: '$breachCount', color: const Color(0xFFFF1744), icon: Icons.crisis_alert_rounded),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.10),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
            Text(label,
                style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _RipplePainter extends CustomPainter {
  final double progress;
  final Color color;
  const _RipplePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.82;
    final cy = size.height * 0.3;
    for (int i = 0; i < 3; i++) {
      final phase   = (progress + i / 3) % 1.0;
      final radius  = 20 + phase * 100;
      final opacity = (1 - phase) * 0.18;
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..color = color.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.progress != progress || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final String query;
  final RiverColors t;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  const _SearchBar({
    required this.ctrl,
    required this.query,
    required this.t,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: t.accent.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
              color: t.accent.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 3)),
        ],
      ),
      child: TextField(
        controller: ctrl,
        style: TextStyle(color: t.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search city, district, state, river…',
          hintStyle: TextStyle(color: t.textSecondary, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded, color: t.accent, size: 20),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded,
                      color: t.textSecondary, size: 18),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _SummaryStrip extends StatelessWidget {
  final RiverColors t;
  final int total, crit, sev, norm, breach;
  const _SummaryStrip({
    required this.t,
    required this.total,
    required this.crit,
    required this.sev,
    required this.norm,
    required this.breach,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _chip(t.accent,                     Icons.water,                  '$total stations'),
        if (crit   > 0) _chip(AppPalette.critical,   Icons.warning_amber_rounded,  '$crit critical'),
        if (sev    > 0) _chip(AppPalette.danger,      Icons.warning_rounded,        '$sev severe'),
        if (norm   > 0) _chip(AppPalette.safe,        Icons.check_circle_outline,   '$norm normal'),
        if (breach > 0) _chip(const Color(0xFFFF1744), Icons.crisis_alert_rounded,  '$breach breach↑'),
      ],
    );
  }

  Widget _chip(Color c, IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: c.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: c),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: c,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final RiverColors t;
  const _StatusBanner({
    required this.icon,
    required this.color,
    required this.text,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 8),
            Text(text,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedCard extends StatefulWidget {
  final int index;
  final Widget child;
  const _AnimatedCard({required this.index, required this.child});

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double>   _fade;
  late final Animation<double>   _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + widget.index * 40))
      ..forward();
    _fade  = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _slide = Tween<double>(begin: 30, end: 0)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _ac,
        builder: (_, ch) => Opacity(
          opacity: _fade.value,
          child: Transform.translate(
            offset: Offset(0, _slide.value),
            child: ch,
          ),
        ),
        child: widget.child,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// _RiverCard
// ─────────────────────────────────────────────────────────────────────────────
class _RiverCard extends StatefulWidget {
  final FloodData data;
  final RiverColors t;
  final VoidCallback onTap;
  const _RiverCard({
    required this.data,
    required this.t,
    required this.onTap,
  });

  @override
  State<_RiverCard> createState() => _RiverCardState();
}

class _RiverCardState extends State<_RiverCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fillAnim;
  late final Animation<double>   _fillTween;

  @override
  void initState() {
    super.initState();
    _fillAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward();
    final target = (widget.data.fillPercent ?? 0.0) / 100.0;
    _fillTween = Tween<double>(begin: 0, end: target.clamp(0.0, 1.0))
        .animate(CurvedAnimation(parent: _fillAnim, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() { _fillAnim.dispose(); super.dispose(); }

  Color _riskColor(String risk) {
    switch (risk.toUpperCase()) {
      case 'CRITICAL': return AppPalette.critical;
      case 'SEVERE':   return AppPalette.danger;
      case 'WARNING':  return AppPalette.warning;
      case 'SAFE':     return AppPalette.safe;
      default:         return widget.t.accent;
    }
  }

  Color _mlColor(String? sev) {
    switch (sev?.toUpperCase()) {
      case 'CRITICAL': return const Color(0xFFFF1744);
      case 'SEVERE':   return const Color(0xFFFF5500);
      case 'MODERATE': return const Color(0xFF10E88A);
      default:         return const Color(0xFF10E88A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d        = widget.data;
    final t        = widget.t;
    final rc       = _riskColor(d.riskLevel);
    final fillPct  = d.fillPercent ?? 0.0;

    final mlSev      = d.predictedSeverity;
    final mlColor    = _mlColor(mlSev);
    final riskScore  = d.riskScore;
    final confidence = d.confidencePercent;
    final willBreach = d.willBreachDanger ?? false;
    final peak       = d.peakLevel72h;

    return GestureDetector(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AnimatedBuilder(
          animation: _fillTween,
          builder: (_, __) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [t.cardBg, rc.withOpacity(0.04)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: rc.withOpacity(0.35), width: 1.2),
              boxShadow: [
                BoxShadow(
                    color: rc.withOpacity(0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 6)),
                BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      height: 120 * _fillTween.value,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [rc.withOpacity(0.0), rc.withOpacity(0.08)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: (120 * _fillTween.value) - 8,
                    left: 0, right: 0,
                    child: CustomPaint(
                      size: const Size(double.infinity, 16),
                      painter: _WavePainter(color: rc, opacity: 0.30),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // Breach banner
                        if (willBreach)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF1744).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFFFF1744).withOpacity(0.5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.crisis_alert_rounded,
                                    color: Color(0xFFFF1744), size: 13),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    peak != null
                                        ? 'BREACH PREDICTED within 72h  ·  Peak ${peak.toStringAsFixed(2)} m'
                                        : 'DANGER LEVEL BREACH PREDICTED within 72h',
                                    style: const TextStyle(
                                        color: Color(0xFFFF1744),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Row 1: cylinder + title + ML chip + risk badge
                        Row(
                          children: [
                            _Cylinder3D(
                              fill: _fillTween.value,
                              color: rc,
                              width: 18,
                              height: 52,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(d.city,
                                      style: TextStyle(
                                          color: t.textPrimary,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          letterSpacing: -0.3)),
                                  if ((d.riverName ?? '').isNotEmpty)
                                    Text(d.riverName!,
                                        style: TextStyle(
                                            color: t.textSecondary,
                                            fontSize: 12)),
                                  Text(d.district,
                                      style: TextStyle(
                                          color: t.textSecondary,
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                            if (mlSev != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: mlColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: mlColor.withOpacity(0.5)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.auto_graph,
                                        color: Color(0xFF7B2FF7), size: 10),
                                    const SizedBox(width: 3),
                                    Text(mlSev.toUpperCase(),
                                        style: TextStyle(
                                            color: mlColor,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: rc.withOpacity(0.16),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: rc.withOpacity(0.5), width: 1),
                              ),
                              child: Text(
                                d.riskLevel.toUpperCase(),
                                style: TextStyle(
                                    color: rc,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Row 2: stat chips
                        Row(
                          children: [
                            if (d.currentLevel != null)
                              _Chip(
                                  t: t,
                                  icon: Icons.water_drop_outlined,
                                  label: 'Level',
                                  value: '${d.currentLevel!.toStringAsFixed(2)} m',
                                  color: rc),
                            if (d.dangerLevel != null) ...[
                              const SizedBox(width: 12),
                              _Chip(
                                  t: t,
                                  icon: Icons.emergency_outlined,
                                  label: 'Danger',
                                  value: '${d.dangerLevel!.toStringAsFixed(2)} m',
                                  color: t.textSecondary),
                            ],
                            if (peak != null) ...[
                              const SizedBox(width: 12),
                              _Chip(
                                  t: t,
                                  icon: Icons.trending_up_rounded,
                                  label: 'Peak 72h',
                                  value: '${peak.toStringAsFixed(2)} m',
                                  color: const Color(0xFFFF1744)),
                            ],
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Row 3: fill bar
                        Row(
                          children: [
                            Text('Fill',
                                style: TextStyle(
                                    color: t.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                            const Spacer(),
                            Text(
                              '${fillPct.toStringAsFixed(1)}%',
                              style: TextStyle(
                                  color: rc,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Stack(
                            children: [
                              Container(
                                  height: 7,
                                  color: t.divider.withOpacity(0.3)),
                              FractionallySizedBox(
                                widthFactor: _fillTween.value,
                                child: Container(
                                  height: 7,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [rc, rc.withOpacity(0.6)],
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Row 4: ML risk score bar
                        if (riskScore != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.query_stats_rounded,
                                  color: Color(0xFF7B2FF7), size: 11),
                              const SizedBox(width: 4),
                              Text('ML Risk: $riskScore / 100',
                                  style: const TextStyle(
                                      color: Color(0xFF7B2FF7),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                              const Spacer(),
                              if (confidence != null)
                                Text('Conf ${confidence.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                        color: t.textSecondary, fontSize: 9)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (riskScore / 100.0).clamp(0.0, 1.0),
                              minHeight: 4,
                              backgroundColor:
                                  const Color(0xFF7B2FF7).withOpacity(0.12),
                              valueColor: AlwaysStoppedAnimation(
                                riskScore >= 80
                                    ? const Color(0xFFFF1744)
                                    : riskScore >= 60
                                        ? const Color(0xFFFF6D00)
                                        : const Color(0xFF7B2FF7),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 8),

                        // Row 5: tap cue
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('Tap for details',
                                style: TextStyle(
                                    color: rc.withOpacity(0.7),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(width: 3),
                            Icon(Icons.chevron_right_rounded,
                                color: rc.withOpacity(0.7), size: 14),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _Cylinder3D extends StatelessWidget {
  final double fill;
  final Color  color;
  final double width, height;
  const _Cylinder3D({
    required this.fill,
    required this.color,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width, height: height,
        child: CustomPaint(
          painter: _CylinderPainter(fill: fill, color: color),
        ),
      );
}

class _CylinderPainter extends CustomPainter {
  final double fill;
  final Color color;
  const _CylinderPainter({required this.fill, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w  = size.width;
    final h  = size.height;
    final rx = w / 2;
    final ry = rx * 0.35;

    final bodyPath = Path()
      ..moveTo(0, ry)
      ..lineTo(0, h - ry)
      ..addArc(Rect.fromLTWH(0, h - ry * 2, w, ry * 2), 0, math.pi)
      ..lineTo(w, ry)
      ..addArc(Rect.fromLTWH(0, 0, w, ry * 2), 0, -math.pi)
      ..close();

    canvas.drawPath(bodyPath,
        Paint()..color = color.withOpacity(0.12)..style = PaintingStyle.fill);

    if (fill > 0) {
      final fillTop = h - ry - (h - ry * 2) * fill.clamp(0.0, 1.0);
      final fillPath = Path()
        ..moveTo(0, fillTop + ry)
        ..lineTo(0, h - ry)
        ..addArc(Rect.fromLTWH(0, h - ry * 2, w, ry * 2), 0, math.pi)
        ..lineTo(w, fillTop + ry)
        ..addArc(Rect.fromLTWH(0, fillTop, w, ry * 2), 0, -math.pi)
        ..close();

      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            colors: [color, color.withOpacity(0.6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(0, fillTop, w, h - fillTop))
          ..style = PaintingStyle.fill,
      );

      canvas.drawOval(
        Rect.fromLTWH(0, fillTop, w, ry * 2),
        Paint()..color = color.withOpacity(0.85)..style = PaintingStyle.fill,
      );
    }

    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = color.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    canvas.drawOval(
      Rect.fromLTWH(0, 0, w, ry * 2),
      Paint()
        ..color = color.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_CylinderPainter old) =>
      old.fill != fill || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
class _WavePainter extends CustomPainter {
  final Color  color;
  final double opacity;
  const _WavePainter({required this.color, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 20) {
      path.quadraticBezierTo(x + 10, 0, x + 20, size.height);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.color != color || old.opacity != opacity;
}

// ─────────────────────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final RiverColors t;
  final IconData icon;
  final String label, value;
  final Color color;
  const _Chip({
    required this.t,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 9,
                    letterSpacing: 0.4)),
          ],
        ),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final RiverColors t;
  final String query;
  const _EmptyState({required this.t, required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.water_outlined, size: 64,
                color: t.accent.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              query.isNotEmpty
                  ? 'No results for "$query"'
                  : 'No river data available',
              style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              query.isNotEmpty
                  ? 'Try a different search term'
                  : 'Pull down to refresh',
              style: TextStyle(color: t.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
