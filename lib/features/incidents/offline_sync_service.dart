// Offline-First Sync Service
// Caches incidents in SQLite, syncs to Neon when online

class OfflineSyncService {
  // TODO: Initialize sqflite
  // TODO: Create local incidents table
  // TODO: Queue pending submissions
  // TODO: Listen to connectivity changes
  // TODO: Sync queued items to Neon API when online

  Future<void> queueIncident(Map<String, dynamic> incident) async {
    // Save to local SQLite with status = 'pending_sync'
  }

  Future<void> syncPendingIncidents() async {
    // Fetch all pending_sync incidents from SQLite
    // POST each to Neon API
    // Update local status to 'synced'
  }
}
