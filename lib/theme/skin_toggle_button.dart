// lib/theme/skin_toggle_button.dart
// Drop-in button that cycles between Deep-Space and Tactical-Ops skins.
// Usage in any ConsumerWidget:
//   const SkinToggleButton()

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_registry.dart';

class SkinToggleButton extends ConsumerWidget {
  const SkinToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ref.watch(appSkinProvider);
    final rc = ref.watch(themeRegistryProvider);

    final isDeepSpace = skin == AppSkin.deepSpace;

    return GestureDetector(
      onTap: () => ref.read(appSkinProvider.notifier).toggle(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: rc.accentDim,
          borderRadius: rc.chipRadius,
          border:
              Border.all(color: rc.accent.withValues(alpha: 0.45), width: 1),
          boxShadow: rc.accentGlow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isDeepSpace ? '\u2726' : '\u26A1',
              style: TextStyle(fontSize: 13, color: rc.accent),
            ),
            const SizedBox(width: 6),
            Text(
              rc.displayName,
              style: rc.labelSm.copyWith(color: rc.accent),
            ),
          ],
        ),
      ),
    );
  }
}
