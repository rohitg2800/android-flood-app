// lib/screens/incident_report_screen.dart
// OpsFlood — Module 11: Community Incident Report Form
//
// Features:
//  • Category picker (flood, landslide, rescue needed, road blocked, other)
//  • Description text field
//  • Optional photo attachment (image_picker)
//  • GPS location capture (location_service)
//  • Severity slider (1–5)
//  • Submit to Firestore via IncidentSyncService
//  • Optimistic local save + background sync

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum IncidentCategory {
  flood,
  landslide,
  rescueNeeded,
  roadBlocked,
  embankmentBreach,
  other;

  String get label => switch (this) {
        IncidentCategory.flood            => '🌊 Flood',
        IncidentCategory.landslide        => '⛰️ Landslide',
        IncidentCategory.rescueNeeded     => '🏥 Rescue Needed',
        IncidentCategory.roadBlocked      => '🚧 Road Blocked',
        IncidentCategory.embankmentBreach => '🚨 Embankment Breach',
        IncidentCategory.other            => '📌 Other',
      };
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class IncidentReportScreen extends ConsumerStatefulWidget {
  const IncidentReportScreen({super.key});

  @override
  ConsumerState<IncidentReportScreen> createState() =>
      _IncidentReportScreenState();
}

class _IncidentReportScreenState
    extends ConsumerState<IncidentReportScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _descCtrl   = TextEditingController();
  final _locationCtrl = TextEditingController();

  IncidentCategory _category = IncidentCategory.flood;
  double           _severity = 3;
  String?          _photoPath;
  bool             _locating = false;
  bool             _submitting = false;
  String?          _latLng;

  @override
  void dispose() {
    _descCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    // In production: use image_picker plugin
    // final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    // setState(() => _photoPath = picked?.path);
    setState(() => _photoPath = '/demo/photo.jpg'); // stub
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo attached (stub)')),
      );
    }
  }

  Future<void> _getLocation() async {
    setState(() => _locating = true);
    await Future.delayed(const Duration(seconds: 1)); // stub
    setState(() {
      _latLng   = '25.5941° N, 85.1376° E'; // stub for Patna
      _locating = false;
      _locationCtrl.text = _latLng!;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    // In production: call ref.read(incidentSyncServiceProvider).submit(...);
    await Future.delayed(const Duration(seconds: 2)); // stub

    setState(() => _submitting = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Incident reported. Thank you!'),
          backgroundColor: AppPalette.safe,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Report Incident')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ─ Category
            Text('Category',
                style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: IncidentCategory.values.map((c) {
                final sel = _category == c;
                return ChoiceChip(
                  label: Text(c.label),
                  selected: sel,
                  onSelected: (_) =>
                      setState(() => _category = c),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ─ Severity
            Text('Severity  (${_severity.toInt()} / 5)',
                style: theme.textTheme.labelLarge),
            Slider(
              value:    _severity,
              min:      1,
              max:      5,
              divisions: 4,
              label:    _severity.toInt().toString(),
              onChanged: (v) => setState(() => _severity = v),
            ),
            const SizedBox(height: 8),

            // ─ Description
            TextFormField(
              controller: _descCtrl,
              maxLines:   4,
              maxLength:  500,
              decoration: const InputDecoration(
                labelText:   'Description',
                hintText:
                    'What happened? Affected areas, visible damage…',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  (v == null || v.trim().length < 10)
                      ? 'Minimum 10 characters'
                      : null,
            ),
            const SizedBox(height: 16),

            // ─ Location
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _locationCtrl,
                    readOnly:   true,
                    decoration: const InputDecoration(
                      labelText:   'Location',
                      hintText:    'Tap to capture GPS…',
                      border:      OutlineInputBorder(),
                      prefixIcon:  Icon(Icons.location_on),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty)
                            ? 'Location required'
                            : null,
                  ),
                ),
                const SizedBox(width: 8),
                _locating
                    ? const SizedBox(
                        width: 48, height: 48,
                        child: Center(
                            child: CircularProgressIndicator(
                                strokeWidth: 2)))
                    : IconButton.filled(
                        icon: const Icon(Icons.my_location),
                        onPressed: _getLocation,
                        tooltip: 'Capture GPS',
                      ),
              ],
            ),
            const SizedBox(height: 16),

            // ─ Photo
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon:  const Icon(Icons.camera_alt),
                    label: Text(_photoPath == null
                        ? 'Attach Photo (optional)'
                        : 'Photo attached ✅'),
                    onPressed: _pickPhoto,
                  ),
                ),
                if (_photoPath != null) ...
                  [
                    const SizedBox(width: 8),
                    IconButton(
                      icon:     const Icon(Icons.close),
                      onPressed: () =>
                          setState(() => _photoPath = null),
                    ),
                  ],
              ],
            ),
            const SizedBox(height: 32),

            // ─ Submit
            FilledButton.icon(
              icon:  _submitting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white))
                  : const Icon(Icons.send),
              label: Text(_submitting ? 'Submitting…' : 'Submit Report'),
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
