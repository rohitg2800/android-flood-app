import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equinox_flood/features/community/models/community_report.dart';
import 'package:equinox_flood/features/community/providers/community_provider.dart';
import 'package:equinox_flood/features/community/screens/submit_report_screen.dart';

class CommunityReportsScreen extends ConsumerWidget {
  const CommunityReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(communityReportsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        title: Text(
          'Community Reports',
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: () => ref.invalidate(communityReportsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF00D4FF),
        foregroundColor: Colors.black,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const SubmitReportScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Report',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: reportsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: Color(0xFFFF4C4C), size: 48),
              const SizedBox(height: 12),
              Text('Failed to load reports',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: Colors.white70)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(communityReportsProvider),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: Colors.black),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (reports) => reports.isEmpty
            ? _EmptyReports()
            : RefreshIndicator(
                color: const Color(0xFF00D4FF),
                onRefresh: () async =>
                    ref.invalidate(communityReportsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  itemCount: reports.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) =>
                      _ReportCard(report: reports[i], ref: ref),
                ),
              ),
      ),
    );
  }
}

class _EmptyReports extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.campaign_outlined,
              size: 64, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text('No reports yet. Be the first to report.',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5), fontSize: 15)),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final CommunityReport report;
  final WidgetRef ref;
  const _ReportCard({required this.report, required this.ref});

  Color _severityColor(ReportSeverity s) {
    switch (s) {
      case ReportSeverity.low:
        return const Color(0xFF00E676);
      case ReportSeverity.medium:
        return const Color(0xFFFFD600);
      case ReportSeverity.high:
        return const Color(0xFFFF6D00);
      case ReportSeverity.critical:
        return const Color(0xFFFF4C4C);
    }
  }

  IconData _categoryIcon(ReportCategory c) {
    switch (c) {
      case ReportCategory.flooding:
        return Icons.water_rounded;
      case ReportCategory.blocked_drain:
        return Icons.block_rounded;
      case ReportCategory.pump_failure:
        return Icons.power_off_rounded;
      case ReportCategory.road_damage:
        return Icons.warning_amber_rounded;
      case ReportCategory.evacuation_needed:
        return Icons.directions_run_rounded;
      case ReportCategory.other:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sColor = _severityColor(report.severity);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF12121A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: sColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_categoryIcon(report.category),
                      color: sColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    report.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: sColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: sColor.withOpacity(0.4), width: 1),
                  ),
                  child: Text(
                    report.severity.name.toUpperCase(),
                    style: TextStyle(
                        color: sColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              report.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6), fontSize: 13),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 13,
                    color: const Color(0xFF00D4FF).withOpacity(0.8)),
                const SizedBox(width: 4),
                Text(
                  report.districtName ?? 'Bihar',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    final repo = ref.read(communityRepositoryProvider);
                    await repo.upvoteReport(report.id);
                    ref.invalidate(communityReportsProvider);
                  },
                  child: Row(
                    children: [
                      Icon(Icons.thumb_up_alt_outlined,
                          size: 15,
                          color: const Color(0xFF00D4FF).withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text('${report.upvotes}',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
