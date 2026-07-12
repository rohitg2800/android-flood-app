import 'package:flutter/material.dart';

class ProbabilityBarWidget extends StatelessWidget {
  final Map<String, double> probabilities; // label -> 0..100
  final String topSeverity;

  const ProbabilityBarWidget({
    super.key,
    required this.probabilities,
    required this.topSeverity,
  });

  static const _colors = {
    'LOW': Color(0xFF2ECC71),
    'MODERATE': Color(0xFFF39C12),
    'SEVERE': Color(0xFFE67E22),
    'CRITICAL': Color(0xFFE74C3C),
  };

  @override
  Widget build(BuildContext context) {
    final labels = ['LOW', 'MODERATE', 'SEVERE', 'CRITICAL'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CLASS PROBABILITIES',
          style: TextStyle(
            color: Color(0xFF00B4D8),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        for (final label in labels) ...[
          _ProbRow(
            label: label,
            pct: probabilities[label] ?? 0,
            color: _colors[label]!,
            isTop: label == topSeverity,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ProbRow extends StatefulWidget {
  final String label;
  final double pct;
  final Color color;
  final bool isTop;

  const _ProbRow({
    required this.label,
    required this.pct,
    required this.color,
    required this.isTop,
  });

  @override
  State<_ProbRow> createState() => _ProbRowState();
}

class _ProbRowState extends State<_ProbRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Row(
            children: [
              if (widget.isTop)
                const Icon(Icons.arrow_right,
                    color: Color(0xFF00B4D8), size: 14)
              else
                const SizedBox(width: 14),
              Flexible(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color:
                        widget.isTop ? Colors.white : const Color(0xFF7B8FA6),
                    fontSize: 11,
                    fontWeight:
                        widget.isTop ? FontWeight.w700 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2035),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: (_anim.value * widget.pct / 100).clamp(0.0, 1.0),
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: widget.isTop
                          ? [
                              BoxShadow(
                                color: widget.color.withValues(alpha: 0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 0),
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            '${widget.pct.toStringAsFixed(1)}%',
            style: TextStyle(
              color: widget.isTop ? widget.color : const Color(0xFF4A5568),
              fontSize: 11,
              fontWeight: widget.isTop ? FontWeight.w700 : FontWeight.normal,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
