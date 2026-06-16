// lib/widgets/alert_share_sheet.dart  v2
// Fixed: AlertShareService.shareViaWhatsApp() is static — call via class, not instance.
import 'package:flutter/material.dart';
import '../services/alert_engine.dart';
import '../services/alert_share_service.dart';
import '../theme/river_theme.dart';

class AlertShareSheet extends StatelessWidget {
  final FloodAlert alert;
  const AlertShareSheet({super.key, required this.alert});

  static void show(BuildContext context, FloodAlert alert) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AlertShareSheet(alert: alert),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: t.stroke,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'Share Alert',
            style: TextStyle(
                color: t.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          _ShareButton(
            icon:  Icons.chat_rounded,
            label: 'Share via WhatsApp',
            color: const Color(0xFF25D366),
            onTap: () async {
              Navigator.pop(context);
              // FIXED: static method called on class, not instance
              await AlertShareService.shareViaWhatsApp(alert);
            },
          ),
          const SizedBox(height: 10),
          _ShareButton(
            icon:  Icons.share_rounded,
            label: 'Share via Other App',
            color: t.accent,
            onTap: () async {
              Navigator.pop(context);
              final msg = AlertShareService.buildEnglishMessage(alert);
              await AlertShareService.shareGeneric(message: msg);
            },
          ),
          const SizedBox(height: 10),
          _ShareButton(
            icon:  Icons.copy_rounded,
            label: 'Copy to Clipboard',
            color: t.metricColor,
            onTap: () async {
              await AlertShareService.instance.copyToClipboard(alert);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback onTap;

  const _ShareButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
