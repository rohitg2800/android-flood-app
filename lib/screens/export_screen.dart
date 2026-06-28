// lib/screens/export_screen.dart  v2 — explicit back button
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../widgets/app_back_button.dart';

enum _ExportFormat { csv, json, pdf }

final _formatProvider  = StateProvider<_ExportFormat>((_) => _ExportFormat.csv);
final _exportingProvider = StateProvider<bool>((_) => false);

class ExportScreen extends ConsumerWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t         = RiverColors.of(context);
    final format    = ref.watch(_formatProvider);
    final exporting = ref.watch(_exportingProvider);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.navBg,
        foregroundColor: t.textPrimary,
        leading: const AppBackButton(),
        title: Text(
          'Export Data',
          style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          Text(
            'Choose Format',
            style: TextStyle(
                color: t.accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1),
          ),
          const SizedBox(height: 10),
          for (final fmt in _ExportFormat.values)
            _FormatTile(
              t: t,
              label: fmt.name.toUpperCase(),
              icon: fmt == _ExportFormat.pdf
                  ? Icons.picture_as_pdf_rounded
                  : Icons.table_chart_rounded,
              selected: format == fmt,
              onTap: () => ref.read(_formatProvider.notifier).state = fmt,
            ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: exporting
                ? null
                : () async {
                    ref.read(_exportingProvider.notifier).state = true;
                    await Future.delayed(const Duration(seconds: 2));
                    ref.read(_exportingProvider.notifier).state = false;
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Export as ${format.name.toUpperCase()} complete'),
                          backgroundColor: t.accent,
                        ),
                      );
                    }
                  },
            icon: exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.download_rounded),
            label: Text(exporting ? 'Exporting…' : 'Export'),
            style: FilledButton.styleFrom(
              backgroundColor: t.accent,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatTile extends StatelessWidget {
  const _FormatTile({
    required this.t,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final RiverColors t;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? t.accent.withValues(alpha: 0.12)
              : t.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? t.accent.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? t.accent : t.textSecondary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? t.accent : t.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: t.accent, size: 20),
          ],
        ),
      ),
    );
  }
}
