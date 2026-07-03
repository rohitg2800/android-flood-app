import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../theme/river_theme.dart';
import 'premium_theme_sheet.dart';

/// AppBar icon that long-press → full premium sheet, tap → quick cycle.
class ThemeCycleButton extends ConsumerWidget {
  const ThemeCycleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appMode = ref.watch(themeModeProvider);
    final notifier = ref.read(themeModeProvider.notifier);
    final rc = RiverColors.of(context);

    final IconData icon;
    switch (appMode) {
      case AppThemeMode.system:
        icon = Icons.brightness_auto;
        break;
      case AppThemeMode.dark:
        icon = Icons.nights_stay;
        break;
      case AppThemeMode.sunset:
        icon = Icons.wb_twilight;
        break;
      case AppThemeMode.ocean:
        icon = Icons.water;
        break;
      case AppThemeMode.roboticDark:
        icon = Icons.memory;
        break;
    }

    return Tooltip(
      message: 'Hold for theme picker',
      child: GestureDetector(
        onTap: () => notifier.cycle(),
        onLongPress: () => showPremiumThemeSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Icon(icon, color: rc.accent, size: 24),
        ),
      ),
    );
  }
}
