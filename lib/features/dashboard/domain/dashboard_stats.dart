class DashboardStats {
  final int critical;
  final int elevated;
  final int safe;
  final int noData;
  final String lastUpdated;

  const DashboardStats({
    required this.critical,
    required this.elevated,
    required this.safe,
    required this.noData,
    required this.lastUpdated,
  });

  int get total => critical + elevated + safe + noData;

  String get heroSubtitle {
    if (critical > 0)
      return "$critical critical  ·  $elevated elevated  ·  $safe safe";
    if (elevated > 0)
      return "$elevated elevated  ·  $safe safe  ·  monitoring active";
    if (safe > 0) return "All $safe stations safe  ·  no active alerts";
    return "Fetching live data…";
  }
}
