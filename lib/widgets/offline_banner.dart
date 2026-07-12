import 'package:flutter/material.dart';
import '../services/offline_cache_service.dart';

/// Resolves issue #26: Offline Mode Banner
class OfflineBanner extends StatelessWidget {
  final DateTime? lastSyncTime;

  const OfflineBanner({super.key, this.lastSyncTime});

  String _formatLastSync() {
    if (lastSyncTime == null) return 'Never synced';
    final diff = DateTime.now().difference(lastSyncTime!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: OfflineCacheService().connectivityStream,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;
        if (isOnline) return const SizedBox.shrink();
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          color: Colors.orange.shade700,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.wifi_off, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Offline Mode — Showing cached data · Last synced: ${_formatLastSync()}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
