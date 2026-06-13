// lib/screens/crowd_report_feed_screen.dart
// OpsFlood — Module 14: Crowd-Report Feed
//
// Citizens can:
//  • Post a flood incident (photo, location, type, severity)
//  • View a live feed of verified + unverified reports
//  • Upvote/flag reports
//  • Filter by district or type
//  • Reports stored in Firestore: crowd_reports/{docId}

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class CrowdReport {
  final String id;
  final String userId;
  final String displayName;
  final String district;
  final String type;       // 'road_flooded' | 'house_inundated' | 'bridge_danger' | 'rescue_needed' | 'other'
  final String severity;   // 'low' | 'medium' | 'high' | 'critical'
  final String description;
  final String? photoUrl;
  final double lat;
  final double lng;
  final DateTime createdAt;
  final bool verified;
  final int upvotes;

  const CrowdReport({
    required this.id, required this.userId,
    required this.displayName, required this.district,
    required this.type, required this.severity,
    required this.description, this.photoUrl,
    required this.lat, required this.lng,
    required this.createdAt, required this.verified,
    required this.upvotes,
  });

  factory CrowdReport.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CrowdReport(
      id:          doc.id,
      userId:      d['userId']      as String? ?? '',
      displayName: d['displayName'] as String? ?? 'Anonymous',
      district:    d['district']    as String? ?? '',
      type:        d['type']        as String? ?? 'other',
      severity:    d['severity']    as String? ?? 'medium',
      description: d['description'] as String? ?? '',
      photoUrl:    d['photoUrl']    as String?,
      lat:         (d['lat']        as num?)?.toDouble() ?? 0,
      lng:         (d['lng']        as num?)?.toDouble() ?? 0,
      createdAt:   (d['createdAt']  as Timestamp?)?.toDate() ?? DateTime.now(),
      verified:    d['verified']    as bool? ?? false,
      upvotes:     d['upvotes']     as int?  ?? 0,
    );
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _filterDistrictProvider = StateProvider<String?>((_) => null);
final _filterTypeProvider     = StateProvider<String?>((_) => null);

final _reportsStreamProvider =
    StreamProvider.autoDispose<List<CrowdReport>>((ref) {
  Query q = FirebaseFirestore.instance
      .collection('crowd_reports')
      .orderBy('createdAt', descending: true)
      .limit(50);

  final district = ref.watch(_filterDistrictProvider);
  final type     = ref.watch(_filterTypeProvider);
  if (district != null) q = q.where('district', isEqualTo: district);
  if (type     != null) q = q.where('type',     isEqualTo: type);

  return q.snapshots().map(
      (snap) => snap.docs.map(CrowdReport.fromFirestore).toList());
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class CrowdReportFeedScreen extends ConsumerWidget {
  static const String route = '/crowd-reports';
  const CrowdReportFeedScreen({super.key});

  static const _types = [
    'road_flooded', 'house_inundated',
    'bridge_danger', 'rescue_needed', 'other',
  ];
  static const _typeLabels = [
    'Road Flooded', 'House Inundated',
    'Bridge Danger', 'Rescue Needed', 'Other',
  ];
  static const _districts = [
    'Patna', 'Darbhanga', 'Muzaffarpur', 'Bhagalpur',
    'Supaul', 'Sitamarhi', 'Madhubani', 'Saran',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(_reportsStreamProvider);
    final filterDistrict = ref.watch(_filterDistrictProvider);
    final filterType     = ref.watch(_filterTypeProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Community Reports'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilters(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSubmitSheet(context, ref),
        backgroundColor: const Color(0xFF0D47A1),
        icon: const Icon(Icons.add_a_photo, color: Colors.white),
        label: const Text('Report',
            style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // Active filters chip row
          if (filterDistrict != null || filterType != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  const Text('Filters: ',
                      style: TextStyle(fontSize: 12)),
                  if (filterDistrict != null)
                    Chip(
                      label: Text(filterDistrict,
                          style: const TextStyle(
                              fontSize: 11)),
                      onDeleted: () => ref
                          .read(_filterDistrictProvider.notifier)
                          .state = null,
                    ),
                  if (filterType != null) ...
                    [
                      const SizedBox(width: 4),
                      Chip(
                        label: Text(
                            _typeLabels[
                                _types.indexOf(filterType!)],
                            style: const TextStyle(
                                fontSize: 11)),
                        onDeleted: () => ref
                            .read(_filterTypeProvider.notifier)
                            .state = null,
                      ),
                    ],
                ],
              ),
            ),
          Expanded(
            child: reportsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text('Error: $e')),
              data: (reports) => reports.isEmpty
                  ? const Center(
                      child: Text('No reports yet. Be the first!',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: reports.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) =>
                          _ReportCard(report: reports[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilters(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _FilterSheet(ref: ref),
    );
  }

  void _showSubmitSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _SubmitReportSheet(),
    );
  }
}

// ---------------------------------------------------------------------------
// Report card
// ---------------------------------------------------------------------------

class _ReportCard extends StatelessWidget {
  final CrowdReport report;
  const _ReportCard({required this.report});

  Color _severityColor(String s) => switch (s) {
    'critical' => const Color(0xFFEF4444),
    'high'     => const Color(0xFFFF9800),
    'medium'   => const Color(0xFFFFEB3B),
    _          => const Color(0xFF4CAF50),
  };

  String _typeLabel(String t) => switch (t) {
    'road_flooded'    => 'Road Flooded',
    'house_inundated' => 'House Inundated',
    'bridge_danger'   => 'Bridge Danger',
    'rescue_needed'   => 'Rescue Needed',
    _                 => 'Other',
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo
          if (report.photoUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12)),
              child: Image.network(
                report.photoUrl!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _severityColor(report.severity)
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: _severityColor(report.severity)),
                      ),
                      child: Text(
                        report.severity.toUpperCase(),
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: _severityColor(report.severity)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(_typeLabel(report.type),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    const Spacer(),
                    if (report.verified)
                      const Icon(Icons.verified,
                          size: 14,
                          color: Color(0xFF1565C0)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(report.description,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black87)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 12, color: Colors.grey),
                    const SizedBox(width: 2),
                    Text(report.district,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey)),
                    const SizedBox(width: 8),
                    const Icon(Icons.person_outline,
                        size: 12, color: Colors.grey),
                    const SizedBox(width: 2),
                    Text(report.displayName,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey)),
                    const Spacer(),
                    Text(
                      timeago.format(report.createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter sheet
// ---------------------------------------------------------------------------

class _FilterSheet extends StatelessWidget {
  final WidgetRef ref;
  const _FilterSheet({required this.ref});

  static const _districts = [
    'Patna', 'Darbhanga', 'Muzaffarpur', 'Bhagalpur',
    'Supaul', 'Sitamarhi', 'Madhubani', 'Saran',
  ];
  static const _types = [
    ('road_flooded',    'Road Flooded'),
    ('house_inundated', 'House Inundated'),
    ('bridge_danger',   'Bridge Danger'),
    ('rescue_needed',   'Rescue Needed'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filter Reports',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          const Text('District',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: _districts
                .map((d) => ActionChip(
                      label: Text(d,
                          style:
                              const TextStyle(fontSize: 12)),
                      onPressed: () {
                        ref
                            .read(
                                _filterDistrictProvider.notifier)
                            .state = d;
                        Navigator.pop(context);
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          const Text('Type',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: _types
                .map((t) => ActionChip(
                      label: Text(t.$2,
                          style:
                              const TextStyle(fontSize: 12)),
                      onPressed: () {
                        ref
                            .read(_filterTypeProvider.notifier)
                            .state = t.$1;
                        Navigator.pop(context);
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Submit report sheet
// ---------------------------------------------------------------------------

class _SubmitReportSheet extends StatefulWidget {
  const _SubmitReportSheet();
  @override
  State<_SubmitReportSheet> createState() =>
      _SubmitReportSheetState();
}

class _SubmitReportSheetState
    extends State<_SubmitReportSheet> {
  final _descCtrl = TextEditingController();
  String _type     = 'road_flooded';
  String _severity = 'medium';
  String _district = 'Patna';
  File?  _photo;
  bool   _submitting = false;

  static const _types = [
    ('road_flooded',    'Road Flooded'),
    ('house_inundated', 'House Inundated'),
    ('bridge_danger',   'Bridge Danger'),
    ('rescue_needed',   'Rescue Needed'),
    ('other',           'Other'),
  ];
  static const _severities = [
    ('low', 'Low'), ('medium', 'Medium'),
    ('high', 'High'), ('critical', 'Critical'),
  ];
  static const _districts = [
    'Patna', 'Darbhanga', 'Muzaffarpur', 'Bhagalpur',
    'Supaul', 'Sitamarhi', 'Madhubani', 'Saran',
  ];

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.camera, imageQuality: 70);
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<void> _submit() async {
    if (_descCtrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      String? photoUrl;
      if (_photo != null) {
        final ref = FirebaseStorage.instance
            .ref('crowd_reports/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_photo!);
        photoUrl = await ref.getDownloadURL();
      }
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium);
      } catch (_) {}
      await FirebaseFirestore.instance.collection('crowd_reports').add({
        'userId':      user?.uid ?? 'anonymous',
        'displayName': user?.displayName ?? 'Anonymous',
        'district':    _district,
        'type':        _type,
        'severity':    _severity,
        'description': _descCtrl.text.trim(),
        'photoUrl':    photoUrl,
        'lat':         pos?.latitude  ?? 0,
        'lng':         pos?.longitude ?? 0,
        'createdAt':   FieldValue.serverTimestamp(),
        'verified':    false,
        'upvotes':     0,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submit failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Submit Report',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            // Photo
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _photo != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(_photo!, fit: BoxFit.cover))
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined,
                              size: 32, color: Colors.grey),
                          SizedBox(height: 4),
                          Text('Tap to add photo',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            // District
            DropdownButtonFormField<String>(
              value: _district,
              decoration: const InputDecoration(
                  labelText: 'District',
                  border: OutlineInputBorder()),
              items: _districts
                  .map((d) =>
                      DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) => setState(() => _district = v!),
            ),
            const SizedBox(height: 10),
            // Type
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder()),
              items: _types
                  .map((t) => DropdownMenuItem(
                      value: t.$1, child: Text(t.$2)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 10),
            // Severity
            DropdownButtonFormField<String>(
              value: _severity,
              decoration: const InputDecoration(
                  labelText: 'Severity',
                  border: OutlineInputBorder()),
              items: _severities
                  .map((s) => DropdownMenuItem(
                      value: s.$1, child: Text(s.$2)))
                  .toList(),
              onChanged: (v) => setState(() => _severity = v!),
            ),
            const SizedBox(height: 10),
            // Description
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  padding:
                      const EdgeInsets.symmetric(vertical: 14)),
              child: _submitting
                  ? const SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Report',
                      style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
