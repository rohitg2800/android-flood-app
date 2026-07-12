// lib/widgets/premium_stat_card.dart
// OpsFlood — PremiumStatCard v3  (Abyss Ops)
// Minimal KPI chip: icon  |  large number  |  label  |  optional delta badge
library;

import 'package:flutter/material.dart';
import 'app_icon_box.dart';
import '../theme/river_theme.dart';

class PremiumStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final String? delta; // e.g. "+2" or "-1"
  final bool isAlert; // pulse border when true

  const PremiumStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.delta,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppPalette.abyss2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              isAlert ? color.withValues(alpha: 0.60) : AppPalette.abyssStroke,
          width: isAlert ? 1.5 : 1,
        ),
        boxShadow: isAlert ? AppPalette.glowShadow(color, blur: 18) : const [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // icon + optional delta
          Row(
            children: [
              AppIconBox.small(icon: icon, color: color),
              const Spacer(),
              if (delta != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    delta!,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // large metric
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppPalette.textGrey,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
