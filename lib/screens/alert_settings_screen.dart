// lib/screens/alert_settings_screen.dart  v1.0 — Step 3.4
// Per-station alert settings: watch toggle, threshold slider, radius picker.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/alert_subscription.dart';
import '../providers/subscription_provider.dart';
import '../theme/river_theme.dart';

class AlertSettingsScreen extends ConsumerStatefulWidget {
  final String stationId;
  final String cityName;
  final double dangerLevel;
  final double warningLevel;

  const AlertSettingsScreen({
    super.key,
    required this.stationId,
    required this.cityName,
    required this.dangerLevel,
    required this.warningLevel,
  });

  @override
  ConsumerState<AlertSettingsScreen> createState() =>
      _AlertSettingsScreenState();
}

class _AlertSettingsScreenState
    extends ConsumerState<AlertSettingsScreen> {
  late bool   _watching;
  late double _threshold;
  late bool   _breachOnly;
  late double _radiusKm;

  static const _radii = [10.0, 25.0, 50.0, 100.0, 0.0];
  static const _radiiLabels = ['10 km', '25 km', '50 km', '100 km', 'Always'];

  @override
  void initState() {
    super.initState();
    final sub = ref.read(subscriptionProvider.notifier)
        .getSubscription(widget.stationId);
    _watching   = sub != null;
    _threshold  = sub?.customThresholdLevel ?? widget.warningLevel;
    _breachOnly = sub?.notifyOnBreachOnly ?? false;
    _radiusKm   = sub?.radiusKm ?? 50.0;
  }

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        title: Text('Alert Settings — ${widget.cityName}'),
        backgroundColor: t.navBg,
        foregroundColor: t.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ─ Watch toggle
          _Card(
            t: t,
            child: SwitchListTile(
              value: _watching,
              onChanged: (v) => setState(() => _watching = v),
              title: Text('Watch this station',
                  style: TextStyle(
                      color: t.textPrimary, fontWeight: FontWeight.w700)),
              subtitle: Text(
                  'Receive alerts when flood levels rise',
                  style: TextStyle(color: t.textSecondary, fontSize: 12)),
              activeColor: t.accent,
            ),
          ),
          const SizedBox(height: 16),

          AnimatedOpacity(
            opacity: _watching ? 1.0 : 0.35,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_watching,
              child: Column(
                children: [
                  // ─ Threshold slider
                  _Card(
                    t: t,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                          child: Row(
                            children: [
                              Text('Alert threshold',
                                  style: TextStyle(
                                      color: t.textPrimary,
                                      fontWeight: FontWeight.w700)),
                              const Spacer(),
                              Text(
                                '${_threshold.toStringAsFixed(2)} m',
                                style: TextStyle(
                                    color: t.accent,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                        Slider(
                          value: _threshold.clamp(
                              widget.warningLevel - 2, widget.dangerLevel + 2),
                          min:   widget.warningLevel - 2,
                          max:   widget.dangerLevel + 2,
                          divisions: 40,
                          activeColor: t.accent,
                          onChanged: (v) => setState(() => _threshold = v),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Warning: ${widget.warningLevel.toStringAsFixed(1)} m',
                                  style: TextStyle(
                                      color: AppPalette.warning, fontSize: 11)),
                              Text('Danger: ${widget.dangerLevel.toStringAsFixed(1)} m',
                                  style: TextStyle(
                                      color: AppPalette.danger, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─ Breach-only toggle
                  _Card(
                    t: t,
                    child: SwitchListTile(
                      value: _breachOnly,
                      onChanged: (v) => setState(() => _breachOnly = v),
                      title: Text('ML breach alerts only',
                          style: TextStyle(
                              color: t.textPrimary,
                              fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          'Only alert when ML model predicts danger breach',
                          style:
                              TextStyle(color: t.textSecondary, fontSize: 12)),
                      activeColor: AppPalette.danger,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─ Radius picker
                  _Card(
                    t: t,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                          child: Text('Notification radius',
                              style: TextStyle(
                                  color: t.textPrimary,
                                  fontWeight: FontWeight.w700)),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(_radii.length, (i) {
                            final selected = _radiusKm == _radii[i];
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _radiusKm = _radii[i]),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? t.accent.withOpacity(0.18)
                                      : t.cardBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: selected
                                          ? t.accent
                                          : t.divider.withOpacity(0.4)),
                                ),
                                child: Text(_radiiLabels[i],
                                    style: TextStyle(
                                        color:
                                            selected ? t.accent : t.textSecondary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ─ Save / Remove buttons
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: t.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _watching ? _save : _remove,
            child: Text(_watching ? 'Save Alert Settings' : 'Remove Watch',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final notifier = ref.read(subscriptionProvider.notifier);
    await notifier.subscribe(AlertSubscription(
      stationId:            widget.stationId,
      cityName:             widget.cityName,
      customThresholdLevel: _threshold,
      notifyOnBreachOnly:   _breachOnly,
      radiusKm:             _radiusKm,
      createdAt:            DateTime.now(),
    ));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    await ref.read(subscriptionProvider.notifier)
        .unsubscribe(widget.stationId);
    if (mounted) Navigator.of(context).pop();
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final RiverColors t;
  const _Card({required this.child, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.divider.withOpacity(0.3)),
      ),
      child: child,
    );
  }
}
