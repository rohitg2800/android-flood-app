import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../theme/river_theme.dart';

// ─── Top-level helper called from settings_screen ─────────────────────────
void showPremiumThemeSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => Consumer(
      builder: (ctx, ref, __) => const PremiumThemeSheet(),
    ),
  );
}

// ─── Filter metadata ───────────────────────────────────────────────────
const _kFilters = [
  _FilterMeta(
    mode: AppThemeMode.system,
    label: 'Auto',
    subtitle: 'Follows device',
    icon: Icons.brightness_auto,
    gradient: [Color(0xFF2A3A5C), Color(0xFF3A5080)],
    isPremium: false,
    isRobotic: false,
  ),
  _FilterMeta(
    mode: AppThemeMode.dark,
    label: 'Night River',
    subtitle: 'Deep abyss',
    icon: Icons.nights_stay,
    gradient: [Color(0xFF010810), Color(0xFF071525)],
    isPremium: false,
    isRobotic: false,
  ),
  _FilterMeta(
    mode: AppThemeMode.sunset,
    label: 'Sunset Warm',
    subtitle: 'Warm & golden',
    icon: Icons.wb_twilight,
    gradient: [Color(0xFF3D1A00), Color(0xFF7A3800)],
    isPremium: true,
    isRobotic: false,
  ),
  _FilterMeta(
    mode: AppThemeMode.ocean,
    label: 'Deep Ocean',
    subtitle: 'Cool blue depths',
    icon: Icons.water,
    gradient: [Color(0xFF00280F), Color(0xFF003A5C)],
    isPremium: true,
    isRobotic: false,
  ),
  // ── Robotic themes ────────────────────────────────────────────────────
  _FilterMeta(
    mode: AppThemeMode.roboticDark,
    label: 'Tactical Dark',
    subtitle: 'Robotic · Night ops',
    icon: Icons.memory_rounded,
    gradient: [Color(0xFF0A0F0A), Color(0xFF0D1F0D)],
    isPremium: false,
    isRobotic: true,
  ),
];

// ─── Sheet widget ──────────────────────────────────────────────────────────────────
class PremiumThemeSheet extends ConsumerWidget {
  const PremiumThemeSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B2A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3A4A58),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'APPEARANCE',
            style: TextStyle(
              color: Color(0xFF00B4D8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(
            _kFilters.length,
            (i) => _FilterTile(
              meta: _kFilters[i],
              isActive: _kFilters[i].mode == current,
              onTap: () {
                ref.read(themeModeProvider.notifier).setMode(_kFilters[i].mode);
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tile ──────────────────────────────────────────────────────────────────────────
class _FilterTile extends StatelessWidget {
  final _FilterMeta meta;
  final bool isActive;
  final VoidCallback onTap;
  const _FilterTile(
      {required this.meta, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Robotic accent: neon green. Others: cyan.
    final activeColor =
        meta.isRobotic ? const Color(0xFF39FF14) : const Color(0xFF00B4D8);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: meta.gradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                isActive ? activeColor : Colors.white.withValues(alpha: 0.06),
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: isActive && meta.isRobotic
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(meta.icon,
                size: 18, color: isActive ? activeColor : Colors.white54),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        meta.label,
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (meta.isPremium) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFF9A825).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: const Color(0xFFF9A825)
                                    .withValues(alpha: 0.4)),
                          ),
                          child: const Text('PRO',
                              style: TextStyle(
                                  color: Color(0xFFF9A825),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8)),
                        ),
                      ],
                      if (meta.isRobotic) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF39FF14).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: const Color(0xFF39FF14)
                                    .withValues(alpha: 0.4)),
                          ),
                          child: const Text('TACTICAL',
                              style: TextStyle(
                                  color: Color(0xFF39FF14),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(meta.subtitle,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            if (isActive)
              Icon(Icons.check_circle_rounded, color: activeColor, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── Meta model ──────────────────────────────────────────────────────────────────────
class _FilterMeta {
  final AppThemeMode mode;
  final String label;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final bool isPremium;
  final bool isRobotic;
  const _FilterMeta({
    required this.mode,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.isPremium,
    required this.isRobotic,
  });
}
