// lib/screens/notification_settings_screen.dart
// OpsFlood — Module 7: Push Notifications & FCM Topics
// v1.1 M5 fix: SwitchListTile does not have a `leading` param in Flutter 3.x.
//              Move the emoji into the title Row instead.
//
// FIX 1: _card() and _SeverityRow previously used Container(color:…) wrapping
// SwitchListTile/ListTile. Flutter asserts ink splashes must paint on a
// Material ancestor — a Container with color creates a DecoratedBox that hides
// them. Fix: replace Container with Material(color:…, shape:…, clipBehavior:…).
//
// FIX 2: _card() and _SeverityRow had BOTH borderRadius AND shape set on
// Material — Flutter asserts !(shape != null && borderRadius != null) at
// material.dart line 209. Removed top-level borderRadius param; radius now
// lives only inside shape: RoundedRectangleBorder.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/fcm_topic_manager.dart';
import '../services/notification_service.dart';
import '../services/notification_channel_service.dart';
import '../theme/river_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  static const String route = '/notification_settings';

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsState();
}

class _NotificationSettingsState
    extends State<NotificationSettingsScreen> {
  final _sevEnabled = <String, bool>{
    'emergency': true,
    'critical':  true,
    'warning':   true,
    'info':      true,
  };

  bool      _quietEnabled = false;
  TimeOfDay _quietStart   = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd     = const TimeOfDay(hour:  7, minute: 0);

  final Set<String> _selDistricts = {};
  final Set<String> _selRivers    = {};

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final mgr   = FcmTopicManager.instance;
    setState(() {
      for (final sev in _sevEnabled.keys) {
        _sevEnabled[sev] = prefs.getBool('notif_sev_$sev') ?? true;
      }
      _quietEnabled = prefs.getBool('quiet_hours_enabled') ?? false;
      _quietStart   = TimeOfDay(
        hour:   prefs.getInt('quiet_start_hour') ?? 22,
        minute: prefs.getInt('quiet_start_min')  ?? 0,
      );
      _quietEnd = TimeOfDay(
        hour:   prefs.getInt('quiet_end_hour') ?? 7,
        minute: prefs.getInt('quiet_end_min')  ?? 0,
      );
      _selDistricts
        ..clear()
        ..addAll(mgr.subscribedDistricts);
      _selRivers
        ..clear()
        ..addAll(mgr.subscribedRivers);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    if (_loading) {
      return Scaffold(
        backgroundColor: t.bgBase,
        body: Center(child: CircularProgressIndicator(color: t.accent)),
      );
    }
    return Scaffold(
      backgroundColor: t.bgBase,
      appBar: AppBar(
        backgroundColor: t.navBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: t.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Notification Settings',
            style: TextStyle(color: t.textPrimary,
                fontWeight: FontWeight.w900, fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header(t, Icons.notifications_active_rounded, 'Alert Severity'),
          const SizedBox(height: 8),
          ..._sevEnabled.entries.map((e) => _SeverityRow(
                t:       t,
                sev:     e.key,
                enabled: e.value,
                onChanged: (v) async {
                  setState(() => _sevEnabled[e.key] = v);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('notif_sev_${e.key}', v);
                  final topic = 'flood_${e.key}';
                  if (v) {
                    await FcmTopicManager.instance.subscribeTo(topic);
                  } else {
                    await FcmTopicManager.instance.unsubscribeFrom(topic);
                  }
                },
              )),
          const SizedBox(height: 20),
          _header(t, Icons.bedtime_rounded, 'Quiet Hours'),
          const SizedBox(height: 8),
          _card(t, [
            SwitchListTile(
              activeColor: t.accent,
              value: _quietEnabled,
              title: Text('Enable quiet hours',
                  style: TextStyle(color: t.textPrimary, fontSize: 14)),
              subtitle: Text(
                'No push during quiet window even for warnings',
                style: TextStyle(color: t.textSecondary, fontSize: 11),
              ),
              onChanged: (v) async {
                setState(() => _quietEnabled = v);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('quiet_hours_enabled', v);
              },
            ),
            if (_quietEnabled) ...[
              _TimeTile(
                t: t, label: 'Quiet from', time: _quietStart,
                onPick: (picked) async {
                  setState(() => _quietStart = picked);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('quiet_start_hour', picked.hour);
                  await prefs.setInt('quiet_start_min',  picked.minute);
                },
              ),
              _TimeTile(
                t: t, label: 'Quiet until', time: _quietEnd,
                onPick: (picked) async {
                  setState(() => _quietEnd = picked);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('quiet_end_hour', picked.hour);
                  await prefs.setInt('quiet_end_min',  picked.minute);
                },
              ),
            ],
          ]),
          const SizedBox(height: 20),
          _header(t, Icons.map_rounded, 'District Alerts'),
          const SizedBox(height: 4),
          Text('Receive alerts for specific Bihar districts.',
              style: TextStyle(color: t.textSecondary, fontSize: 11)),
          const SizedBox(height: 8),
          _ChipGrid(
            t: t,
            items: FcmTopics.biharDistricts,
            selected: _selDistricts,
            format: (s) => s
                .replaceAll('_', ' ')
                .split(' ')
                .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
                .join(' '),
            onToggle: (slug, selected) async {
              setState(() {
                if (selected) _selDistricts.add(slug);
                else          _selDistricts.remove(slug);
              });
              await FcmTopicManager.instance
                  .setDistrictSubscriptions(_selDistricts.toList());
            },
          ),
          const SizedBox(height: 20),
          _header(t, Icons.water_rounded, 'River Alerts'),
          const SizedBox(height: 8),
          _ChipGrid(
            t: t,
            items: FcmTopics.biharRivers,
            selected: _selRivers,
            format: (s) => s
                .replaceAll('_', ' ')
                .split(' ')
                .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
                .join(' '),
            onToggle: (slug, selected) async {
              setState(() {
                if (selected) _selRivers.add(slug);
                else          _selRivers.remove(slug);
              });
              await FcmTopicManager.instance
                  .setRiverSubscriptions(_selRivers.toList());
            },
          ),
          const SizedBox(height: 20),
          _header(t, Icons.science_rounded, 'Test Notifications'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              _TestButton(t: t, label: '🚨 Emergency',
                  color: const Color(0xFFFF1744), channelId: 'flood_emergency',
                  title: '🚨 EMERGENCY TEST',
                  body: 'Simulated HFL breach at Birpur, Kosi river'),
              _TestButton(t: t, label: '🔴 Critical',
                  color: const Color(0xFFFF6D00), channelId: 'flood_critical',
                  title: '🔴 CRITICAL TEST',
                  body: 'Level above danger at Baltara, Gandak'),
              _TestButton(t: t, label: '⚠️ Warning',
                  color: const Color(0xFFFFD600), channelId: 'flood_warning',
                  title: '⚠️ Warning TEST',
                  body: 'Rapid rise detected at Rosera, Bagmati'),
              _TestButton(t: t, label: 'ℹ️ Info',
                  color: const Color(0xFF00E5FF), channelId: 'flood_info',
                  title: 'ℹ️ Advisory TEST',
                  body: 'Heavy rainfall (78 mm) near Darbhanga'),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _header(RiverColors t, IconData icon, String label) =>
      Row(children: [
        Icon(icon, color: t.accent, size: 16),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(color: t.textPrimary,
                fontWeight: FontWeight.w900, fontSize: 14)),
      ]);

  /// FIX: Material must NOT have both [borderRadius] and [shape] set.
  /// Flutter asserts !(shape != null && borderRadius != null) at material.dart:209.
  /// Radius lives only inside shape: RoundedRectangleBorder — no top-level borderRadius.
  Widget _card(RiverColors t, List<Widget> children) => Material(
        color: t.cardBg,
        // ❌ borderRadius: BorderRadius.circular(14),  ← removed; causes crash
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: t.stroke),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );
}

// ── Severity row ─────────────────────────────────────────────────────────────

const _sevMeta = {
  'emergency': ('🚨', 'Emergency', Color(0xFFFF1744)),
  'critical':  ('🔴', 'Critical',  Color(0xFFFF6D00)),
  'warning':   ('⚠️', 'Warning',   Color(0xFFFFD600)),
  'info':      ('ℹ️', 'Advisory',  Color(0xFF00E5FF)),
};

class _SeverityRow extends StatelessWidget {
  final RiverColors t;
  final String  sev;
  final bool    enabled;
  final ValueChanged<bool> onChanged;
  const _SeverityRow({
    required this.t,
    required this.sev,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final meta = _sevMeta[sev]!;
    // FIX: shape only, no borderRadius param — they are mutually exclusive on Material.
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: t.cardBg,
        // ❌ borderRadius: BorderRadius.circular(12),  ← removed; causes crash
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: t.stroke),
        ),
        clipBehavior: Clip.antiAlias,
        child: SwitchListTile(
          activeColor: meta.$3,
          value: enabled,
          title: Row(children: [
            Text(meta.$1, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text(
              meta.$2,
              style: TextStyle(color: t.textPrimary,
                  fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ]),
          subtitle: Text(_subtitle(sev),
              style: TextStyle(color: t.textSecondary, fontSize: 10)),
          onChanged: onChanged,
        ),
      ),
    );
  }

  static String _subtitle(String sev) {
    switch (sev) {
      case 'emergency': return 'HFL breach, embankment collapse';
      case 'critical':  return 'Above danger level';
      case 'warning':   return 'Above warning level, rapid rise';
      case 'info':      return 'Heavy rainfall, advisories';
      default:          return '';
    }
  }
}

// ── Time picker tile ──────────────────────────────────────────────────────────

class _TimeTile extends StatelessWidget {
  final RiverColors t;
  final String     label;
  final TimeOfDay  time;
  final ValueChanged<TimeOfDay> onPick;
  const _TimeTile({
    required this.t,
    required this.label,
    required this.time,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(label,
            style: TextStyle(color: t.textPrimary, fontSize: 13)),
        trailing: GestureDetector(
          onTap: () async {
            HapticFeedback.lightImpact();
            final picked = await showTimePicker(
              context: context,
              initialTime: time,
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: t.accent,
                    onPrimary: Colors.black,
                    surface: t.cardBg,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) onPick(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: t.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: t.accent.withValues(alpha: 0.4)),
            ),
            child: Text(time.format(context),
                style: TextStyle(color: t.accent,
                    fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ),
      );
}

// ── Chip grid ─────────────────────────────────────────────────────────────────

class _ChipGrid extends StatelessWidget {
  final RiverColors       t;
  final List<String>      items;
  final Set<String>       selected;
  final String Function(String) format;
  final void Function(String slug, bool selected) onToggle;
  const _ChipGrid({
    required this.t,
    required this.items,
    required this.selected,
    required this.format,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6, runSpacing: 6,
        children: items.map((slug) {
          final active = selected.contains(slug);
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onToggle(slug, !active);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: active
                    ? t.accent.withValues(alpha: 0.18)
                    : t.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: active
                        ? t.accent.withValues(alpha: 0.7)
                        : t.stroke),
              ),
              child: Text(format(slug),
                  style: TextStyle(
                      color: active ? t.accent : t.textSecondary,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 10)),
            ),
          );
        }).toList(),
      );
}

// ── Test notification button ───────────────────────────────────────────────────

class _TestButton extends StatelessWidget {
  final RiverColors t;
  final String      label;
  final Color       color;
  final String      channelId;
  final String      title;
  final String      body;
  const _TestButton({
    required this.t,
    required this.label,
    required this.color,
    required this.channelId,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.15),
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () async {
          HapticFeedback.mediumImpact();
          await NotificationService.instance.showFloodAlert(
            id:        DateTime.now().millisecondsSinceEpoch & 0xFFFF,
            title:     title,
            body:      body,
            channelId: channelId,
            payload:   'test_$channelId',
          );
        },
        child: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 12)),
      );
}
