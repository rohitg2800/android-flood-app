// lib/screens/incident_report_screen.dart
// OpsFlood — Incident Report Screen (Phase 7 full implementation)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:equinox_flood/core/theme/river_theme.dart' as core_theme;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

enum IncidentType {
  flood,
  embankmentBreach,
  landslide,
  roadBlock,
  reliefCamp,
  rescueNeeded,
  casualty,
  propertyDamage,
  other,
}

extension IncidentTypeExt on IncidentType {
  String get label {
    switch (this) {
      case IncidentType.flood:            return 'Flood / Waterlogging';
      case IncidentType.embankmentBreach: return 'Embankment Breach';
      case IncidentType.landslide:        return 'Landslide';
      case IncidentType.roadBlock:        return 'Road Blocked';
      case IncidentType.reliefCamp:       return 'Relief Camp Needed';
      case IncidentType.rescueNeeded:     return 'Rescue Needed';
      case IncidentType.casualty:         return 'Casualty / Fatality';
      case IncidentType.propertyDamage:   return 'Property Damage';
      case IncidentType.other:            return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case IncidentType.flood:            return Icons.water;
      case IncidentType.embankmentBreach: return Icons.broken_image;
      case IncidentType.landslide:        return Icons.landscape;
      case IncidentType.roadBlock:        return Icons.block;
      case IncidentType.reliefCamp:       return Icons.medical_services;
      case IncidentType.rescueNeeded:     return Icons.sos;
      case IncidentType.casualty:         return Icons.personal_injury;
      case IncidentType.propertyDamage:   return Icons.home_work;
      case IncidentType.other:            return Icons.report_problem;
    }
  }

  Color get color {
    switch (this) {
      case IncidentType.flood:            return Colors.blue;
      case IncidentType.embankmentBreach: return Colors.deepOrange;
      case IncidentType.landslide:        return Colors.brown;
      case IncidentType.roadBlock:        return Colors.amber;
      case IncidentType.reliefCamp:       return Colors.green;
      case IncidentType.rescueNeeded:     return Colors.red;
      case IncidentType.casualty:         return const Color(0xFFB71C1C);
      case IncidentType.propertyDamage:   return Colors.orange;
      case IncidentType.other:            return Colors.grey;
    }
  }
}

enum Severity { critical, high, medium, low }

extension SeverityExt on Severity {
  String get label {
    switch (this) {
      case Severity.critical: return 'Critical';
      case Severity.high:     return 'High';
      case Severity.medium:   return 'Medium';
      case Severity.low:      return 'Low';
    }
  }

  Color get color {
    switch (this) {
      case Severity.critical: return Colors.red;
      case Severity.high:     return Colors.deepOrange;
      case Severity.medium:   return Colors.amber;
      case Severity.low:      return Colors.green;
    }
  }

  IconData get icon {
    switch (this) {
      case Severity.critical: return Icons.crisis_alert;
      case Severity.high:     return Icons.warning_amber;
      case Severity.medium:   return Icons.info_outline;
      case Severity.low:      return Icons.check_circle_outline;
    }
  }
}

class IncidentDraft {
  // Explicit default constructor — required because we also declare a factory.
  IncidentDraft();

  IncidentType? type;
  Severity severity = Severity.high;
  String district = '';
  String block = '';
  String village = '';
  double? lat;
  double? lng;
  String description = '';
  String reporterName = '';
  String reporterPhone = '';
  int photoCount = 0;
  DateTime createdAt = DateTime.now();

  Map<String, dynamic> toJson() => {
    'type': type?.name,
    'severity': severity.name,
    'district': district,
    'block': block,
    'village': village,
    'lat': lat,
    'lng': lng,
    'description': description,
    'reporterName': reporterName,
    'reporterPhone': reporterPhone,
    'photoCount': photoCount,
    'createdAt': createdAt.toIso8601String(),
  };

  factory IncidentDraft.fromJson(Map<String, dynamic> j) {
    final d = IncidentDraft()
      ..severity = Severity.values.firstWhere(
          (s) => s.name == (j['severity'] ?? 'high'),
          orElse: () => Severity.high)
      ..district = j['district'] ?? ''
      ..block = j['block'] ?? ''
      ..village = j['village'] ?? ''
      ..lat = j['lat'] as double?
      ..lng = j['lng'] as double?
      ..description = j['description'] ?? ''
      ..reporterName = j['reporterName'] ?? ''
      ..reporterPhone = j['reporterPhone'] ?? ''
      ..photoCount = j['photoCount'] ?? 0
      ..createdAt = DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now();
    if (j['type'] != null) {
      d.type = IncidentType.values.firstWhere(
        (t) => t.name == j['type'],
        orElse: () => IncidentType.other,
      );
    }
    return d;
  }

  String get shareText =>
      '🚨 Flood Incident Report\n'
      'Type: ${type?.label ?? "—"}\n'
      'Severity: ${severity.label}\n'
      'Location: $district${block.isNotEmpty ? " > $block" : ""}${village.isNotEmpty ? " > $village" : ""}\n'
      '${lat != null ? "GPS: $lat, $lng\n" : ""}'
      'Description: $description\n'
      'Reporter: ${reporterName.isNotEmpty ? reporterName : "Anonymous"} ${reporterPhone.isNotEmpty ? "($reporterPhone)" : ""}\n'
      'Reported at: ${createdAt.toLocal()}\n\n'
      'OpsFlood — Bihar Flood Monitoring App';
}

const List<String> _biharDistricts = [
  'Araria', 'Arwal', 'Aurangabad', 'Banka', 'Begusarai', 'Bhagalpur',
  'Bhojpur', 'Buxar', 'Darbhanga', 'East Champaran', 'Gaya', 'Gopalganj',
  'Jamui', 'Jehanabad', 'Kaimur', 'Katihar', 'Khagaria', 'Kishanganj',
  'Lakhisarai', 'Madhepura', 'Madhubani', 'Munger', 'Muzaffarpur', 'Nalanda',
  'Nawada', 'Patna', 'Purnia', 'Rohtas', 'Saharsa', 'Samastipur', 'Saran',
  'Sheikhpura', 'Sheohar', 'Sitamarhi', 'Siwan', 'Supaul', 'Vaishali',
  'West Champaran',
];

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class IncidentReportScreen extends StatefulWidget {
  static const String route = '/incident-report';
  const IncidentReportScreen({super.key});

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  final PageController _page = PageController();
  int _step = 0;
  bool _submitting = false;
  bool _submitted = false;

  final IncidentDraft _draft = IncidentDraft();

  final _blockCtrl   = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _nameCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();

  static const String _draftKey = 'incident_draft_v1';

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  @override
  void dispose() {
    _page.dispose();
    _blockCtrl.dispose();
    _villageCtrl.dispose();
    _descCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw != null) {
        final loaded = IncidentDraft.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
        setState(() {
          _draft
            ..type = loaded.type
            ..severity = loaded.severity
            ..district = loaded.district
            ..block = loaded.block
            ..village = loaded.village
            ..lat = loaded.lat
            ..lng = loaded.lng
            ..description = loaded.description
            ..reporterName = loaded.reporterName
            ..reporterPhone = loaded.reporterPhone;
          _blockCtrl.text   = loaded.block;
          _villageCtrl.text = loaded.village;
          _descCtrl.text    = loaded.description;
          _nameCtrl.text    = loaded.reporterName;
          _phoneCtrl.text   = loaded.reporterPhone;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _syncControllers();
      await prefs.setString(_draftKey, jsonEncode(_draft.toJson()));
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (_) {}
  }

  void _syncControllers() {
    _draft
      ..block         = _blockCtrl.text.trim()
      ..village       = _villageCtrl.text.trim()
      ..description   = _descCtrl.text.trim()
      ..reporterName  = _nameCtrl.text.trim()
      ..reporterPhone = _phoneCtrl.text.trim();
  }

  void _goToStep(int s) {
    _saveDraft();
    setState(() => _step = s);
    _page.animateToPage(s,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut);
  }

  bool get _step1Valid => _draft.type != null;
  bool get _step2Valid => _draft.district.isNotEmpty;
  bool get _step3Valid => _descCtrl.text.trim().length >= 10;

  Future<void> _tryGetLocation() async {
    setState(() { _draft.lat = 25.5941; _draft.lng = 85.1376; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('📍 GPS location captured (Patna — demo)'),
        duration: Duration(seconds: 2),
      ));
    }
  }

  Future<void> _submit() async {
    _syncControllers();
    if (!_step1Valid || !_step2Valid || !_step3Valid) return;
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList('incident_queue_v1') ?? [];
      queue.add(jsonEncode(_draft.toJson()));
      await prefs.setStringList('incident_queue_v1', queue);
    } catch (_) {}
    await _clearDraft();
    if (mounted) setState(() { _submitting = false; _submitted = true; });
  }

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    if (_submitted) return _buildSuccess(t);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.navBg,
        foregroundColor: t.textPrimary,
        title: const Row(
          children: [
            Icon(Icons.report_problem, color: Colors.deepOrange, size: 20),
            SizedBox(width: 8),
            Text('Incident Report'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _saveDraft,
            child: Text('Save Draft',
                style: TextStyle(color: t.accent, fontSize: 12)),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStepper(t),
          Expanded(
            child: PageView(
              controller: _page,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(t),
                _buildStep2(t),
                _buildStep3(t),
                _buildStep4(t),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildNavBar(t),
    );
  }

  Widget _buildStepper(RiverColors t) {
    return Container(
      color: t.navBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: List.generate(4, (i) {
          final done   = i < _step;
          final active = i == _step;
          return Expanded(
            child: Row(
              children: [
                _StepDot(index: i + 1, done: done, active: active, theme: t),
                if (i < 3)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: done ? t.accent : t.divider.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep1(RiverColors t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Td3SectionHeader('Incident Type', accentColor: Colors.deepOrange),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.05,
            children: IncidentType.values.map((type) {
              final selected = _draft.type == type;
              return GestureDetector(
                onTap: () => setState(() => _draft.type = type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: selected ? type.color.withValues(alpha: 0.18) : t.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? type.color : t.divider.withValues(alpha: 0.5),
                      width: selected ? 2.0 : 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(type.icon,
                          color: selected ? type.color : t.textSecondary,
                          size: 26),
                      const SizedBox(height: 6),
                      Text(
                        type.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? type.color : t.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Td3SectionHeader('Severity Level', accentColor: Colors.red),
          const SizedBox(height: 10),
          Row(
            children: Severity.values.map((s) {
              final sel = _draft.severity == s;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _draft.severity = s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? s.color.withValues(alpha: 0.18) : t.cardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel ? s.color : t.divider.withValues(alpha: 0.4),
                          width: sel ? 2.0 : 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(s.icon,
                              color: sel ? s.color : t.textSecondary,
                              size: 18),
                          const SizedBox(height: 4),
                          Text(s.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                color: sel ? s.color : t.textSecondary,
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2(RiverColors t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Td3SectionHeader('District *', accentColor: t.accent),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _draft.district.isEmpty ? null : _draft.district,
            dropdownColor: t.navBg,
            style: TextStyle(color: t.textPrimary, fontSize: 14),
            hint: Text('Select district',
                style: TextStyle(color: t.textSecondary)),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: t.divider.withValues(alpha: 0.5)),
              ),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: t.cardBg,
            ),
            items: _biharDistricts
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: (v) => setState(() => _draft.district = v ?? ''),
          ),
          const SizedBox(height: 16),
          Td3InputField(
            label: 'Block / Tehsil',
            hint: 'e.g. Hajipur',
            icon: Icons.location_on_outlined,
            controller: _blockCtrl,
            onChanged: (v) => _draft.block = v,
          ),
          const SizedBox(height: 12),
          Td3InputField(
            label: 'Village / Ward',
            hint: 'e.g. Rampur Tola',
            icon: Icons.holiday_village_outlined,
            controller: _villageCtrl,
            onChanged: (v) => _draft.village = v,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.my_location, size: 16),
                  label: Text(
                    _draft.lat != null
                        ? '${_draft.lat?.toStringAsFixed(4) ?? '--'}, ${_draft.lng?.toStringAsFixed(4) ?? '--'}'
                        : 'Auto-detect GPS',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        _draft.lat != null ? Colors.green : t.accent,
                    side: BorderSide(
                      color: _draft.lat != null
                          ? Colors.green
                          : t.accent.withValues(alpha: 0.6),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _tryGetLocation,
                ),
              ),
              if (_draft.lat != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: 'Clear GPS',
                  onPressed: () => setState(
                      () { _draft.lat = null; _draft.lng = null; }),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep3(RiverColors t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Td3SectionHeader('Description *', accentColor: t.accent),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: t.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.divider.withValues(alpha: 0.5)),
            ),
            child: TextField(
              controller: _descCtrl,
              maxLines: 6,
              maxLength: 500,
              style: TextStyle(color: t.textPrimary, fontSize: 14),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText:
                    'Describe what happened — water level, people affected, damage observed…',
                hintStyle: TextStyle(color: t.textSecondary, fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(12),
                counterStyle:
                    TextStyle(color: t.textSecondary, fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Td3SectionHeader('Photo Evidence (Optional)'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              setState(() => _draft.photoCount++);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('📷 Photo added (demo stub)'),
                  duration: Duration(seconds: 1)));
            },
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: t.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.divider.withValues(alpha: 0.5)),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_a_photo_outlined, color: t.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      _draft.photoCount == 0
                          ? 'Tap to attach photos'
                          : '${_draft.photoCount} photo(s) attached',
                      style: TextStyle(color: t.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Td3SectionHeader('Reporter Info (Optional)'),
          const SizedBox(height: 8),
          Td3InputField(
            label: 'Your Name',
            hint: 'Full name',
            icon: Icons.person_outline,
            controller: _nameCtrl,
            onChanged: (v) => _draft.reporterName = v,
          ),
          const SizedBox(height: 12),
          Td3InputField(
            label: 'Mobile Number',
            hint: '10-digit mobile',
            icon: Icons.phone_outlined,
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            onChanged: (v) => _draft.reporterPhone = v,
          ),
        ],
      ),
    );
  }

  Widget _buildStep4(RiverColors t) {
    _syncControllers();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Td3SectionHeader('Review Before Submitting', accentColor: t.accent),
          const SizedBox(height: 12),
          Td3Card(
            showGloss: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _ReviewRow(
                    icon: _draft.type?.icon ?? Icons.report,
                    color: _draft.type?.color ?? Colors.grey,
                    label: 'Type',
                    value: _draft.type?.label ?? '—',
                    theme: t,
                  ),
                  const Divider(height: 16),
                  _ReviewRow(
                    icon: _draft.severity.icon,
                    color: _draft.severity.color,
                    label: 'Severity',
                    value: _draft.severity.label,
                    theme: t,
                  ),
                  const Divider(height: 16),
                  _ReviewRow(
                    icon: Icons.location_on,
                    color: Colors.blue,
                    label: 'Location',
                    value: [
                      _draft.district,
                      if (_draft.block.isNotEmpty) _draft.block,
                      if (_draft.village.isNotEmpty) _draft.village,
                    ].join(' > '),
                    theme: t,
                  ),
                  if (_draft.lat != null) ...[
                    const Divider(height: 16),
                    _ReviewRow(
                      icon: Icons.my_location,
                      color: Colors.green,
                      label: 'GPS',
                      value:
                          '${_draft.lat?.toStringAsFixed(5) ?? '--'}, ${_draft.lng?.toStringAsFixed(5) ?? '--'}',
                      theme: t,
                    ),
                  ],
                  const Divider(height: 16),
                  _ReviewRow(
                    icon: Icons.description_outlined,
                    color: t.accent,
                    label: 'Description',
                    value: _draft.description.isNotEmpty
                        ? _draft.description
                        : '—',
                    theme: t,
                  ),
                  if (_draft.photoCount > 0) ...[
                    const Divider(height: 16),
                    _ReviewRow(
                      icon: Icons.photo_library_outlined,
                      color: Colors.purple,
                      label: 'Photos',
                      value: '${_draft.photoCount} attached',
                      theme: t,
                    ),
                  ],
                  if (_draft.reporterName.isNotEmpty) ...[
                    const Divider(height: 16),
                    _ReviewRow(
                      icon: Icons.person,
                      color: Colors.teal,
                      label: 'Reporter',
                      value:
                          '${_draft.reporterName}${_draft.reporterPhone.isNotEmpty ? " (${_draft.reporterPhone})" : ""}',
                      theme: t,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!_step1Valid)
            _Warning('Please go back and select an incident type.'),
          if (!_step2Valid)
            _Warning('Please go back and select a district.'),
          if (!_step3Valid)
            _Warning('Description must be at least 10 characters.'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.share, size: 16),
            label: const Text('Share Report'),
            onPressed: () => Share.share(_draft.shareText,
                subject: 'OpsFlood Incident Report'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              foregroundColor: t.accent,
              side: BorderSide(color: t.accent.withValues(alpha: 0.6)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 10),
          Td3Button(
            label: _submitting ? 'Submitting…' : 'Submit Report',
            icon: Icons.send,
            loading: _submitting,
            color: (_step1Valid && _step2Valid && _step3Valid)
                ? Colors.deepOrange
                : Colors.grey,
            onTap: (_step1Valid && _step2Valid && _step3Valid && !_submitting)
                ? _submit
                : null,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildNavBar(RiverColors t) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: t.navBg,
        border: Border(
            top: BorderSide(
                color: t.divider.withValues(alpha: 0.4), width: 0.75)),
      ),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => _goToStep(_step - 1),
                style: OutlinedButton.styleFrom(
                  foregroundColor: t.textSecondary,
                  side: BorderSide(color: t.divider),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('← Back'),
              ),
            ),
          if (_step > 0) const SizedBox(width: 12),
          if (_step < 3)
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _canProceed ? () => _goToStep(_step + 1) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: t.divider,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Next →',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }

  bool get _canProceed {
    switch (_step) {
      case 0: return _step1Valid;
      case 1: return _step2Valid;
      case 2: return _step3Valid;
      default: return true;
    }
  }

  Widget _buildSuccess(RiverColors t) {
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: const Icon(Icons.check,
                      color: Colors.green, size: 40),
                ),
                const SizedBox(height: 24),
                Text('Report Submitted!',
                    style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  'Your incident report has been saved to the offline queue '
                  'and will be uploaded when connectivity is available.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: t.textSecondary, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 32),
                Td3Button(
                  label: 'Submit Another',
                  icon: Icons.add,
                  color: Colors.deepOrange,
                  onTap: () => setState(() {
                    _submitted = false;
                    _draft
                      ..type = null
                      ..district = ''
                      ..description = '';
                    _descCtrl.clear();
                    _blockCtrl.clear();
                    _villageCtrl.clear();
                    _nameCtrl.clear();
                    _phoneCtrl.clear();
                    _step = 0;
                    _page.jumpToPage(0);
                  }),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: t.textSecondary,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Back to Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StepDot extends StatelessWidget {
  final int index;
  final bool done;
  final bool active;
  final RiverColors theme;
  const _StepDot({
    required this.index,
    required this.done,
    required this.active,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final Color bg;
    final Color fg;
    if (done) {
      bg = t.accent;         fg = Colors.white;
    } else if (active) {
      bg = Colors.deepOrange; fg = Colors.white;
    } else {
      bg = t.cardBg;          fg = t.textSecondary;
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(
            color: active ? Colors.deepOrange : t.divider.withValues(alpha: 0.5),
            width: 1.5),
      ),
      child: Center(
        child: done
            ? const Icon(Icons.check, size: 14, color: Colors.white)
            : Text('$index',
                style: TextStyle(
                    color: fg,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final RiverColors theme;
  const _ReviewRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Warning extends StatelessWidget {
  final String message;
  const _Warning(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
