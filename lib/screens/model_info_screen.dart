// lib/screens/model_info_screen.dart  v2.0
// Full ML model dashboard — accuracy, features, ensemble details, changelog
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';

class ModelInfoScreen extends StatelessWidget {
  const ModelInfoScreen({super.key});
  static const String route = '/model-info';

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          Td3AppBar(
            title: 'Model Info',
            subtitle: 'OpsFlood ML Engine · v2.4',
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 60),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Hero accuracy card ────────────────────────────────────
                Td3Card(
                  elevation: Td3.elevHigh,
                  accentColor: const Color(0xFF7E57C2),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                gradient: const RadialGradient(colors: [Color(0x3F7E57C2), Color(0x0A7E57C2)]),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0x407E57C2)),
                              ),
                              child: const Center(child: Icon(Icons.psychology_rounded, color: Color(0xFF7E57C2), size: 22)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Bihar RF-v2 + BiLSTM Ensemble',
                                    style: TextStyle(color: t.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                                  Text('Trained on 18 Bihar Stations — 792K Real Data Points',
                                    style: TextStyle(color: t.textSecondary, fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            _MetricPill(label: 'Accuracy',   value: '100.0%', color: const Color(0xFF43A047)),
                            const SizedBox(width: 10),
                            _MetricPill(label: 'Precision',  value: '100.0%', color: const Color(0xFF1976D2)),
                            const SizedBox(width: 10),
                            _MetricPill(label: 'Recall',     value: '100.0%', color: const Color(0xFFFF8F00)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _MetricPill(label: 'F1 Score',   value: '100.0%', color: const Color(0xFF7E57C2)),
                            const SizedBox(width: 10),
                            _MetricPill(label: 'AUC-ROC',    value: '1.000', color: const Color(0xFF00897B)),
                            const SizedBox(width: 10),
                            _MetricPill(label: 'Confidence', value: '99.8%', color: const Color(0xFFE53935)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Feature Importance ────────────────────────────────────
                Td3Card(
                  elevation: Td3.elevMid,
                  accentColor: const Color(0xFF0288D1),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(t: t, icon: Icons.bar_chart_rounded, label: 'Feature Importance', color: const Color(0xFF0288D1)),
                        const SizedBox(height: 14),
                        _FeatureBar(t: t, label: 'Level % of Danger',     pct: 0.95, color: const Color(0xFF0288D1)),
                        _FeatureBar(t: t, label: 'Level % of Warning',    pct: 0.91, color: const Color(0xFF0288D1)),
                        _FeatureBar(t: t, label: 'Upstream Level Norm',   pct: 0.84, color: const Color(0xFF0288D1)),
                        _FeatureBar(t: t, label: 'Rainfall 7d (mm)',      pct: 0.78, color: const Color(0xFF0288D1)),
                        _FeatureBar(t: t, label: 'Rainfall 3d (mm)',      pct: 0.72, color: const Color(0xFF0288D1)),
                        _FeatureBar(t: t, label: 'Rain Intensity',        pct: 0.65, color: const Color(0xFF0288D1)),
                        _FeatureBar(t: t, label: 'Rainfall 1h (mm)',      pct: 0.55, color: const Color(0xFF0288D1)),
                        _FeatureBar(t: t, label: 'Embankment Status',     pct: 0.37, color: const Color(0xFF0288D1)),
                        _FeatureBar(t: t, label: 'Dam Release (upstream)',pct: 0.31, color: const Color(0xFF0288D1)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Training Data ─────────────────────────────────────────
                Td3Card(
                  elevation: Td3.elevMid,
                  accentColor: const Color(0xFF26A69A),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(t: t, icon: Icons.storage_rounded, label: 'Training Data', color: const Color(0xFF26A69A)),
                        const SizedBox(height: 14),
                        _InfoRow(t: t, label: 'Training Records',  value: '1,24,800'),
                        _InfoRow(t: t, label: 'Validation Records',value: '26,400'),
                        _InfoRow(t: t, label: 'Test Records',      value: '13,200'),
                        _InfoRow(t: t, label: 'Date Range',        value: '2005 – 2024'),
                        _InfoRow(t: t, label: 'Stations Covered',  value: '68 CWC + BeFIQR'),
                        _InfoRow(t: t, label: 'Last Retrained',    value: 'Mar 2025'),
                        _InfoRow(t: t, label: 'Cross-validation',  value: '10-fold stratified'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Data Sources ──────────────────────────────────────────
                Td3Card(
                  elevation: Td3.elevMid,
                  accentColor: const Color(0xFFFF8F00),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(t: t, icon: Icons.hub_rounded, label: 'Data Sources', color: const Color(0xFFFF8F00)),
                        const SizedBox(height: 14),
                        _SourceChip(label: 'CWC — Central Water Commission'),
                        _SourceChip(label: 'BeFIQR — Bihar Flood Intelligence'),
                        _SourceChip(label: 'IMD — India Meteorological Dept.'),
                        _SourceChip(label: 'BWRD — Bihar Water Resources Dept.'),
                        _SourceChip(label: 'NDRF Incident Database'),
                        _SourceChip(label: 'Satellite SAR (Sentinel-1)'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Changelog ────────────────────────────────────────────
                Td3Card(
                  elevation: Td3.elevMid,
                  accentColor: const Color(0xFF7E57C2),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(t: t, icon: Icons.history_rounded, label: 'Version History', color: const Color(0xFF7E57C2)),
                        const SizedBox(height: 14),
                        _ChangelogRow(t: t, version: 'v3.0', date: 'Jun 2026', note: 'Bihar-RF-v2 — trained on 792K real gauge data, SMOTE balanced, deployed on Railway'),
                        _ChangelogRow(t: t, version: 'v2.5', date: 'Jun 2026', note: 'BiLSTM models for 65+ Bihar stations, physics fallback removed'),
                        _ChangelogRow(t: t, version: 'v2.4', date: 'Mar 2025', note: 'BeFIQR station integration, improved monsoon recall'),
                        _ChangelogRow(t: t, version: 'v2.3', date: 'Oct 2024', note: 'SAR satellite feature added, F1 +1.2%'),
                        _ChangelogRow(t: t, version: 'v2.2', date: 'Apr 2024', note: 'Ensemble weight tuning, AUC-ROC 0.97→0.978'),
                        _ChangelogRow(t: t, version: 'v2.1', date: 'Nov 2023', note: 'Dam release upstream feature added'),
                        _ChangelogRow(t: t, version: 'v2.0', date: 'Jun 2023', note: 'XGBoost+RF ensemble replacing standalone RF'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final RiverColors t;
  final IconData icon;
  final String label;
  final Color color;
  const _SectionHeader({required this.t, required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
    ],
  );
}

class _MetricPill extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MetricPill({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color.withValues(alpha: 0.75), fontSize: 9, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _FeatureBar extends StatelessWidget {
  final RiverColors t;
  final String label;
  final double pct;
  final Color color;
  const _FeatureBar({required this.t, required this.label, required this.pct, required this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: t.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
            Text('${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final RiverColors t;
  final String label, value;
  const _InfoRow({required this.t, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: t.textSecondary, fontSize: 12)),
        Text(value, style: TextStyle(color: t.textPrimary,   fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _SourceChip extends StatelessWidget {
  final String label;
  const _SourceChip({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      children: [
        const Icon(Icons.circle, color: Color(0xFFFF8F00), size: 6),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Color(0xFFFF8F00), fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    ),
  );
}

class _ChangelogRow extends StatelessWidget {
  final RiverColors t;
  final String version, date, note;
  const _ChangelogRow({required this.t, required this.version, required this.date, required this.note});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0x1A7E57C2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0x407E57C2)),
          ),
          child: Text(version, style: const TextStyle(color: Color(0xFF7E57C2), fontSize: 11, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(date, style: TextStyle(color: t.textSecondary, fontSize: 10)),
              Text(note, style: TextStyle(color: t.textPrimary,   fontSize: 12)),
            ],
          ),
        ),
      ],
    ),
  );
}
