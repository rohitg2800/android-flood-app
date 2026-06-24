// lib/screens/alert_settings_screen.dart  Step 3.4
// Lets users manage their station watch-list:
//   • See all subscribed stations
//   • Remove a subscription
//   • Edit radius and custom threshold per subscription
// Also wired as destination from CityDetailScreen / _StationSheet via Routes.alertSettings

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/alert_subscription.dart';
import '../providers/subscription_provider.dart';
import '../theme/river_theme.dart';

class AlertSettingsScreen extends ConsumerWidget {
  final String? stationId;
  final String? cityName;
  final double? dangerLevel;
  final double? warningLevel;

  const AlertSettingsScreen({
    super.key,
    this.stationId,
    this.cityName,
    this.dangerLevel,
    this.warningLevel,
  });
  static const String route = '/alert-settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t    = RiverColors.of(context);
    final subs = ref.watch(subscriptionProvider);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        title: const Text('My Alerts'),
        backgroundColor: t.navBg,
        foregroundColor: t.textPrimary,
        elevation: 0,
        actions: [
          if (subs.isNotEmpty)
            TextButton.icon(
              icon: Icon(Icons.delete_sweep_outlined, color: AppPalette.critical, size: 18),
              label: Text('Clear all',
                  style: TextStyle(color: AppPalette.critical, fontSize: 12)),
              onPressed: () => _confirmClearAll(context, ref, subs),
            ),
        ],
      ),
      body: subs.isEmpty
          ? _EmptyState(t: t)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount:    subs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _SubCard(
                sub: subs[i],
                t:   t,
                onRemove: () => ref
                    .read(subscriptionProvider.notifier)
                    .unsubscribe(subs[i].stationId),
                onEdit: () => _showEditSheet(context, ref, subs[i], t),
              ),
            ),
    );
  }

  // ── Confirm clear all dialog ────────────────────────────────────────────────
  void _confirmClearAll(
      BuildContext context, WidgetRef ref, List<AlertSubscription> subs) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all alerts?'),
        content: Text('This will remove all ${subs.length} station subscriptions.'),
        actions: [
          TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context)),
          TextButton(
            child: Text('Clear all',
                style: TextStyle(color: AppPalette.critical)),
            onPressed: () {
              for (final s in subs) {
                ref.read(subscriptionProvider.notifier).unsubscribe(s.stationId);
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  // ── Edit bottom sheet ──────────────────────────────────────────────────────
  void _showEditSheet(
      BuildContext context, WidgetRef ref, AlertSubscription sub, RiverColors t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: t.cardBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (_) => _EditSheet(sub: sub, t: t, ref: ref),
    );
  }
}

// ── Subscription card ────────────────────────────────────────────────────────────

class _SubCard extends StatelessWidget {
  final AlertSubscription sub;
  final RiverColors       t;
  final VoidCallback      onRemove;
  final VoidCallback      onEdit;
  const _SubCard({
    required this.sub, required this.t,
    required this.onRemove, required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.accent.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          // Bell icon
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: t.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_active_rounded,
                color: t.accent, size: 20),
          ),
          const SizedBox(width: 12),
          // Info column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sub.cityName,
                  style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '${sub.riverName} • ${sub.notifyRadiusKm.toInt()} km radius',
                  style: TextStyle(
                      color: t.textSecondary, fontSize: 11),
                ),
                if (sub.customThresholdMetres != null)
                  Text(
                    'Custom threshold: ${sub.customThresholdMetres!.toStringAsFixed(2)} m',
                    style: TextStyle(
                        color: AppPalette.gold, fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                if (sub.breachOnlyMode)
                  Text(
                    'Breach-only mode',
                    style: TextStyle(
                        color: AppPalette.warning, fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ),
          // Edit + Remove
          IconButton(
            icon: Icon(Icons.tune_rounded,
                color: t.accent, size: 20),
            tooltip: 'Edit',
            onPressed: onEdit,
          ),
          IconButton(
            icon: Icon(Icons.notifications_off_outlined,
                color: AppPalette.critical, size: 20),
            tooltip: 'Remove',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

// ── Edit bottom sheet content ─────────────────────────────────────────────────────

class _EditSheet extends StatefulWidget {
  final AlertSubscription sub;
  final RiverColors       t;
  final WidgetRef         ref;
  const _EditSheet({required this.sub, required this.t, required this.ref});
  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late double _radius;
  late bool   _breachOnly;
  late bool   _useCustom;
  late double _customLevel;

  @override
  void initState() {
    super.initState();
    _radius      = widget.sub.notifyRadiusKm;
    _breachOnly  = widget.sub.breachOnlyMode;
    _useCustom   = widget.sub.customThresholdMetres != null;
    _customLevel = widget.sub.customThresholdMetres ?? 5.0;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: t.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Edit: ${widget.sub.cityName}',
              style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),

            // Radius slider
            _SheetLabel('Notification radius: ${_radius.toInt()} km', t),
            Slider(
              value:    _radius,
              min:      10, max: 200, divisions: 19,
              label:    '${_radius.toInt()} km',
              activeColor: t.accent,
              onChanged: (v) => setState(() => _radius = v),
            ),
            const SizedBox(height: 4),

            // Breach-only toggle
            SwitchListTile(
              value:           _breachOnly,
              onChanged:       (v) => setState(() => _breachOnly = v),
              title:           Text('Breach-only alerts',
                  style: TextStyle(color: t.textPrimary, fontSize: 13)),
              subtitle:        Text('Notify only when predicted level will breach danger',
                  style: TextStyle(color: t.textSecondary, fontSize: 11)),
              activeColor:     t.accent,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 4),

            // Custom threshold
            SwitchListTile(
              value:           _useCustom,
              onChanged:       (v) => setState(() => _useCustom = v),
              title:           Text('Custom threshold',
                  style: TextStyle(color: t.textPrimary, fontSize: 13)),
              subtitle:        Text('Override station danger level',
                  style: TextStyle(color: t.textSecondary, fontSize: 11)),
              activeColor:     t.accent,
              contentPadding: EdgeInsets.zero,
            ),
            if (_useCustom) ...[
              _SheetLabel('Alert when level ≥ ${_customLevel.toStringAsFixed(2)} m', t),
              Slider(
                value:    _customLevel,
                min:      1.0, max: 20.0, divisions: 190,
                label:    '${_customLevel.toStringAsFixed(2)} m',
                activeColor: AppPalette.warning,
                onChanged: (v) => setState(() => _customLevel = v),
              ),
            ],
            const SizedBox(height: 16),

            // Save
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: t.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                onPressed: _save,
                child: const Text('Save changes',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _save() {
    final updated = widget.sub.copyWith(
      notifyRadiusKm:        _radius,
      breachOnlyMode:        _breachOnly,
      customThresholdMetres: _useCustom ? _customLevel : null,
    );
    widget.ref.read(subscriptionProvider.notifier).update(updated);
    Navigator.pop(context);
  }
}

class _SheetLabel extends StatelessWidget {
  final String      text;
  final RiverColors t;
  const _SheetLabel(this.text, this.t);
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            color: t.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600));
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final RiverColors t;
  const _EmptyState({required this.t});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_outlined,
                size: 64, color: t.textSecondary),
            const SizedBox(height: 16),
            Text(
              'No station alerts yet',
              style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the 🔔 bell icon on any city or station to start watching it.',
              textAlign: TextAlign.center,
              style: TextStyle(color: t.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
