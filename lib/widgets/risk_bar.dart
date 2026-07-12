// lib/widgets/risk_bar.dart
// OpsFlood — RiskBar widget v1 (replaces circular gauge)
// A horizontal animated progress bar with zone markers.
import 'package:flutter/material.dart';
import '../theme/river_theme.dart';

class RiskBar extends StatefulWidget {
  final double value; // 0–100
  final double warning; // threshold line position 0–100
  final double danger; // threshold line position 0–100
  final Color barColor;
  final String label;
  final bool showLabel;
  final double height;

  const RiskBar({
    super.key,
    required this.value,
    this.warning = 60,
    this.danger = 80,
    this.barColor = AppPalette.cyan,
    this.label = '',
    this.showLabel = true,
    this.height = 10,
  });

  @override
  State<RiskBar> createState() => _RiskBarState();
}

class _RiskBarState extends State<RiskBar> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(RiskBar old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _resolveColor() {
    if (widget.value >= widget.danger) return AppPalette.critical;
    if (widget.value >= widget.warning) return AppPalette.warning;
    return widget.barColor;
  }

  @override
  Widget build(BuildContext context) {
    final color = _resolveColor();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showLabel && widget.label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppPalette.textGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${widget.value.toStringAsFixed(0)} / 100',
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        AnimatedBuilder(
          animation: _anim,
          builder: (_, __) {
            final pct = (widget.value / 100 * _anim.value).clamp(0.0, 1.0);
            return LayoutBuilder(
              builder: (_, constraints) {
                final w = constraints.maxWidth;
                return Stack(
                  children: [
                    // Track
                    Container(
                      height: widget.height,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(widget.height),
                      ),
                    ),
                    // Fill
                    FractionallySizedBox(
                      widthFactor: pct,
                      child: Container(
                        height: widget.height,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color.withValues(alpha: 0.6),
                              color,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(widget.height),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.45),
                              blurRadius: 10,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Warning marker
                    if (widget.warning > 0)
                      Positioned(
                        left: w * (widget.warning / 100) - 0.75,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 1.5,
                          decoration: BoxDecoration(
                            color: AppPalette.amber.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    // Danger marker
                    if (widget.danger > 0 && widget.danger < 100)
                      Positioned(
                        left: w * (widget.danger / 100) - 0.75,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 1.5,
                          decoration: BoxDecoration(
                            color: AppPalette.critical.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}
