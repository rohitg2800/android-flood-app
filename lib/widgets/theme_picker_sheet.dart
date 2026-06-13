// lib/widgets/theme_picker_sheet.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../theme/river_theme.dart';

class ThemePickerSheet extends ConsumerWidget {
  const ThemePickerSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppPalette.abyss2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ThemePickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);
    final col     = RiverColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: col.stroke,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'App Theme',
            style: TextStyle(
              color: col.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: AppThemeMode.values.map((mode) {
              final isSelected = mode == current;
              final modeLabel = switch (mode) {
                AppThemeMode.system       => 'Auto',
                AppThemeMode.light        => 'Day River',
                AppThemeMode.dark         => 'Night River',
                AppThemeMode.sunset       => 'Sunset Warm',
                AppThemeMode.ocean        => 'Deep Ocean',
                AppThemeMode.roboticDark  => 'Tactical Dark',
                AppThemeMode.roboticLight => 'Tactical Light',
              };
              return GestureDetector(
                onTap: () {
                  ref.read(themeModeProvider.notifier).setMode(mode);
                  Navigator.pop(context);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppPalette.gold.withValues(alpha: 0.15)
                        : col.chipBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppPalette.gold : col.stroke,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _iconFor(mode),
                        size: 16,
                        color: isSelected
                            ? AppPalette.gold
                            : col.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        modeLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? AppPalette.gold
                              : col.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:       return Icons.brightness_auto_outlined;
      case AppThemeMode.light:        return Icons.light_mode_outlined;
      case AppThemeMode.dark:         return Icons.dark_mode_outlined;
      case AppThemeMode.sunset:       return Icons.wb_twilight_outlined;
      case AppThemeMode.ocean:        return Icons.water_outlined;
      case AppThemeMode.roboticDark:  return Icons.memory_outlined;
      case AppThemeMode.roboticLight: return Icons.developer_board_outlined;
    }
  }
}
