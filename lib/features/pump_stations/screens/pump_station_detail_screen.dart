import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pump_station_provider.dart';
import '../data/repositories/pump_station_repository.dart';

class PumpStationDetailScreen extends ConsumerWidget {
  final String stationId;
  const PumpStationDetailScreen({super.key, required this.stationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stationAsync = ref.watch(pumpStationByIdProvider(stationId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Station Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(pumpStationByIdProvider(stationId)),
          ),
        ],
      ),
      body: stationAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Could not load station details',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(pumpStationByIdProvider(stationId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (station) => _StationDetailBody(station: station),
      ),
    );
  }
}

class _StationDetailBody extends ConsumerStatefulWidget {
  final PumpStation station;
  const _StationDetailBody({required this.station});

  @override
  ConsumerState<_StationDetailBody> createState() => _StationDetailBodyState();
}

class _StationDetailBodyState extends ConsumerState<_StationDetailBody> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _reporterController = TextEditingController();
  final _contactController = TextEditingController();

  String _issueType = 'mechanical';
  String _severity = 'medium';
  bool _showReportForm = false;

  @override
  void dispose() {
    _descController.dispose();
    _reporterController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    final report = IssueReport(
      stationId: widget.station.id,
      issueType: _issueType,
      description: _descController.text.trim(),
      severity: _severity,
      reporterName: _reporterController.text.trim().isEmpty
          ? null
          : _reporterController.text.trim(),
      contactNumber: _contactController.text.trim().isEmpty
          ? null
          : _contactController.text.trim(),
    );

    final success =
        await ref.read(issueReportProvider.notifier).submitReport(report);

    if (!mounted) return;
    if (success) {
      setState(() => _showReportForm = false);
      _descController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Issue reported successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit report. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportState = ref.watch(issueReportProvider);
    final station = widget.station;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Info Card ──────────────────────────────────────────
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(station.name,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(station.location,
                      style: const TextStyle(color: Colors.grey)),
                  const Divider(height: 24),
                  _InfoRow(label: 'Status', value: station.status),
                  _InfoRow(
                      label: 'Capacity',
                      value: '${station.capacityPercent.toStringAsFixed(1)}%'),
                  if (station.district != null)
                    _InfoRow(label: 'District', value: station.district!),
                  if (station.lastMaintenance != null)
                    _InfoRow(
                        label: 'Last Maintenance',
                        value: station.lastMaintenance!),
                  if (station.nextMaintenance != null)
                    _InfoRow(
                        label: 'Next Maintenance',
                        value: station.nextMaintenance!),
                  if (station.contactNumber != null)
                    _InfoRow(label: 'Contact', value: station.contactNumber!),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Report Issue Button ────────────────────────────────
          if (!_showReportForm)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _showReportForm = true),
                icon: const Icon(Icons.report_problem),
                label: const Text('Report an Issue'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),

          // ── Report Form ────────────────────────────────────────
          if (_showReportForm)
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Report Issue',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),

                      // Issue type
                      DropdownButtonFormField<String>(
                        value: _issueType,
                        decoration: const InputDecoration(
                          labelText: 'Issue Type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'mechanical', child: Text('Mechanical')),
                          DropdownMenuItem(
                              value: 'electrical', child: Text('Electrical')),
                          DropdownMenuItem(
                              value: 'flooding', child: Text('Flooding')),
                          DropdownMenuItem(
                              value: 'blockage', child: Text('Blockage')),
                          DropdownMenuItem(
                              value: 'other', child: Text('Other')),
                        ],
                        onChanged: (v) =>
                            setState(() => _issueType = v ?? _issueType),
                      ),
                      const SizedBox(height: 12),

                      // Severity
                      DropdownButtonFormField<String>(
                        value: _severity,
                        decoration: const InputDecoration(
                          labelText: 'Severity',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'low', child: Text('Low')),
                          DropdownMenuItem(
                              value: 'medium', child: Text('Medium')),
                          DropdownMenuItem(value: 'high', child: Text('High')),
                          DropdownMenuItem(
                              value: 'critical', child: Text('Critical')),
                        ],
                        onChanged: (v) =>
                            setState(() => _severity = v ?? _severity),
                      ),
                      const SizedBox(height: 12),

                      // Description
                      TextFormField(
                        controller: _descController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description *',
                          hintText: 'Describe the issue in detail…',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Description is required'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Reporter name (optional)
                      TextFormField(
                        controller: _reporterController,
                        decoration: const InputDecoration(
                          labelText: 'Your Name (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Contact (optional)
                      TextFormField(
                        controller: _contactController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Contact Number (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  setState(() => _showReportForm = false),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  reportState.isLoading ? null : _submitReport,
                              child: reportState.isLoading
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Text('Submit'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.grey, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
