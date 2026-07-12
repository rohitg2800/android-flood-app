// lib/screens/manual_predict_screen.dart  v2.0
// Manual flood prediction form — inputs + real-time risk computation
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';

class ManualPredictScreen extends StatefulWidget {
  static const route = '/manual-predict';
  const ManualPredictScreen({super.key});
  @override
  State<ManualPredictScreen> createState() => _ManualPredictScreenState();
}

class _ManualPredictScreenState extends State<ManualPredictScreen> {
  final _levelCtrl = TextEditingController();
  final _rainfallCtrl = TextEditingController();
  final _dischargeCtrl = TextEditingController();
  final _soilCtrl = TextEditingController();

  String _season = 'Monsoon';
  String? _result;
  Color _resultColor = Colors.transparent;
  double _riskScore = 0.0;

  static const _seasons = ['Pre-Monsoon', 'Monsoon', 'Post-Monsoon', 'Winter'];

  void _compute() {
    HapticFeedback.mediumImpact();
    final level = double.tryParse(_levelCtrl.text) ?? 0;
    final rainfall = double.tryParse(_rainfallCtrl.text) ?? 0;
    final discharge = double.tryParse(_dischargeCtrl.text) ?? 0;
    final soil = double.tryParse(_soilCtrl.text) ?? 0;

    // Simple weighted risk scoring (representative logic)
    double score = 0;
    score += (level / 50.0).clamp(0, 1) * 0.35;
    score += (rainfall / 200.0).clamp(0, 1) * 0.25;
    score += (discharge / 10000.0).clamp(0, 1) * 0.20;
    score += (soil / 100.0).clamp(0, 1) * 0.15;
    if (_season == 'Monsoon') score += 0.05;
    if (_season == 'Pre-Monsoon') score += 0.02;

    score = score.clamp(0.0, 1.0);

    String label;
    Color color;
    if (score > 0.85) {
      label = 'CRITICAL FLOOD RISK';
      color = const Color(0xFF7B1FA2);
    } else if (score > 0.70) {
      label = 'DANGER — Flood Likely';
      color = const Color(0xFFE53935);
    } else if (score > 0.55) {
      label = 'WARNING — Watch Closely';
      color = const Color(0xFFFF8F00);
    } else if (score > 0.40) {
      label = 'WATCH — Elevated';
      color = const Color(0xFFF9A825);
    } else {
      label = 'SAFE — No Immediate Risk';
      color = const Color(0xFF43A047);
    }

    setState(() {
      _result = label;
      _resultColor = color;
      _riskScore = score;
    });
  }

  @override
  void dispose() {
    _levelCtrl.dispose();
    _rainfallCtrl.dispose();
    _dischargeCtrl.dispose();
    _soilCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          Td3AppBar(
            title: 'Manual Prediction',
            subtitle: 'Enter field readings for risk estimate',
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 60),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Input form ────────────────────────────────────────────
                Td3Card(
                  elevation: Td3.elevMid,
                  accentColor: const Color(0xFF7E57C2),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('FIELD READINGS',
                            style: TextStyle(
                                color: const Color(0xFF7E57C2),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0)),
                        const SizedBox(height: 16),

                        _InputField(
                          t: t,
                          label: 'River Level (m)',
                          hint: 'e.g. 42.5',
                          icon: Icons.water,
                          color: const Color(0xFF1976D2),
                          ctrl: _levelCtrl,
                        ),
                        const SizedBox(height: 12),
                        _InputField(
                          t: t,
                          label: 'Upstream Rainfall — 72h (mm)',
                          hint: 'e.g. 150',
                          icon: Icons.grain_rounded,
                          color: const Color(0xFF0288D1),
                          ctrl: _rainfallCtrl,
                        ),
                        const SizedBox(height: 12),
                        _InputField(
                          t: t,
                          label: 'Discharge Rate (m³/s)',
                          hint: 'e.g. 4800',
                          icon: Icons.waves_rounded,
                          color: const Color(0xFF00897B),
                          ctrl: _dischargeCtrl,
                        ),
                        const SizedBox(height: 12),
                        _InputField(
                          t: t,
                          label: 'Soil Saturation Index (0–100)',
                          hint: 'e.g. 75',
                          icon: Icons.landscape_rounded,
                          color: const Color(0xFF6D4C41),
                          ctrl: _soilCtrl,
                        ),
                        const SizedBox(height: 16),

                        // Season selector
                        Text('Season',
                            style: TextStyle(
                                color: t.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: _seasons.map((s) {
                            final sel = s == _season;
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _season = s);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color:
                                      sel ? const Color(0xFF7E57C2) : t.cardBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: sel
                                          ? const Color(0xFF7E57C2)
                                          : t.stroke.withValues(alpha: 0.3)),
                                ),
                                child: Text(s,
                                    style: TextStyle(
                                        color: sel
                                            ? Colors.white
                                            : t.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        // Compute button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _compute,
                            icon: const Icon(Icons.calculate_rounded),
                            label: const Text('Compute Risk',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7E57C2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Result card ───────────────────────────────────────────
                if (_result != null)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      color: _resultColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: _resultColor.withValues(alpha: 0.4), width: 2),
                      boxShadow: [
                        BoxShadow(
                            color: _resultColor.withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.water_damage_rounded,
                            color: _resultColor, size: 36),
                        const SizedBox(height: 10),
                        Text(_result!,
                            style: TextStyle(
                                color: _resultColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w800),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: _riskScore,
                            minHeight: 8,
                            backgroundColor:
                                _resultColor.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation(_resultColor),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                            'Risk Score: ${(_riskScore * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                                color: _resultColor.withValues(alpha: 0.8),
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
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

class _InputField extends StatelessWidget {
  final RiverColors t;
  final String label, hint;
  final IconData icon;
  final Color color;
  final TextEditingController ctrl;
  const _InputField(
      {required this.t,
      required this.label,
      required this.hint,
      required this.icon,
      required this.color,
      required this.ctrl});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: t.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                  color: t.textSecondary.withValues(alpha: 0.4), fontSize: 13),
              prefixIcon: Icon(icon, color: color, size: 18),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: t.stroke.withValues(alpha: 0.4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: color, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ],
      );
}
