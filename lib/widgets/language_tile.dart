import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/locale_constants.dart';
import '../providers/locale_provider.dart';
import '../theme/river_theme.dart';

/// Drop-in settings tile — shows current language and lets user pick EN / HI.
class LanguageTile extends ConsumerWidget {
  const LanguageTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider);
    final notifier = ref.read(localeProvider.notifier);
    final rc = RiverColors.of(context);

    return ListTile(
      leading: Icon(Icons.language, color: rc.accent),
      title: Text('Language', style: TextStyle(color: rc.textPrimary)),
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<Locale>(
          value: current,
          dropdownColor: rc.cardBgElevated,
          style: TextStyle(color: rc.accent, fontWeight: FontWeight.w700),
          items: kSupportedLocales
              .map(
                (l) => DropdownMenuItem(
                  value: l,
                  child: Text(
                    kLocaleLabels[l.languageCode] ?? l.languageCode,
                    style: TextStyle(color: rc.textPrimary),
                  ),
                ),
              )
              .toList(),
          onChanged: (l) {
            if (l != null) notifier.setLocale(l);
          },
        ),
      ),
    );
  }
}
