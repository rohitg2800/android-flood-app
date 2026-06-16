// lib/widgets/dashboard/dashboard_footer.dart  v3
// Fixed:
//   • StreamBuilder<DataFetchSnapshot> — not parameterised with DataFetchSnapshot
//   • DataFetchEngine.instance.last — nullable DataFetchSnapshot?
//   • Removed undefined .last on Stream
import 'package:flutter/material.dart';
import '../../services/data_fetch_engine.dart';
import '../../theme/river_theme.dart';

class DashboardFooter extends StatelessWidget {
  const DashboardFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return StreamBuilder<DataFetchSnapshot>(
      stream:      DataFetchEngine.instance.stream,
      initialData: DataFetchEngine.instance.last,
      builder: (context, snap) {
        final data      = snap.data;
        final fetchedAt = data?.fetchedAt;
        final isLoading = data?.isLoading ?? false;
        final count     = data?.stations.length ?? 0;
        final errored   = data?.error != null;

        final Color  dotColor;
        final String statusLabel;
        if (isLoading) {
          dotColor    = AppPalette.warning;
          statusLabel = 'Refreshing\u2026';
        } else if (errored) {
          dotColor    = AppPalette.critical;
          statusLabel = 'Connection error';
        } else if (count > 0) {
          dotColor    = AppPalette.safe;
          statusLabel = '$count stations live';
        } else {
          dotColor    = AppPalette.warning;
          statusLabel = 'Awaiting data\u2026';
        }

        final timeLabel = fetchedAt == null
            ? ''
            : _relativeTime(fetchedAt);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                statusLabel,
                style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
              if (timeLabel.isNotEmpty) ...[
                Text(
                  '  ·  ',
                  style: TextStyle(color: t.textSecondary, fontSize: 11),
                ),
                Text(
                  timeLabel,
                  style: TextStyle(color: t.textSecondary, fontSize: 11),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static String _relativeTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60)  return '${d.inSeconds}s ago';
    if (d.inMinutes < 60)  return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }
}
