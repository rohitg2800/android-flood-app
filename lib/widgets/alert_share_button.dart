// lib/widgets/alert_share_button.dart
// Bottom-sheet share button for a FloodAlert.

import 'package:flutter/material.dart';
import '../services/alert_engine.dart';
import '../services/alert_share_service.dart';

class AlertShareButton extends StatelessWidget {
  final FloodAlert alert;
  final String? district; // optional — city_detail_screen passes district:
  final String? riverName; // optional — city_detail_screen passes riverName:
  const AlertShareButton({
    super.key,
    required this.alert,
    this.district,
    this.riverName,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.share_outlined),
      tooltip: 'Share alert',
      onPressed: () => _showSheet(context),
    );
  }

  void _showSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _ShareSheet(alert: alert),
    );
  }
}

class _ShareSheet extends StatefulWidget {
  final FloodAlert alert;
  const _ShareSheet({required this.alert});

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  late final String englishMsg;
  late final String hindiMsg;

  @override
  void initState() {
    super.initState();
    englishMsg = AlertShareService.buildEnglishMessage(widget.alert);
    hindiMsg = AlertShareService.buildHindiMessage(widget.alert);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Share Alert',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.message),
              label: const Text('Share via WhatsApp (English)'),
              onPressed: () {
                AlertShareService.shareViaWhatsApp(widget.alert);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.message),
              label: const Text('Share via WhatsApp (Hindi)'),
              onPressed: () {
                AlertShareService.shareViaWhatsApp(widget.alert);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('Share (English)'),
              onPressed: () {
                AlertShareService.shareGeneric(message: englishMsg);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('Share (Hindi)'),
              onPressed: () {
                AlertShareService.shareGeneric(message: hindiMsg);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
