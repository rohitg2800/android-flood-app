import "package:flutter/material.dart";
import "package:equinox_flood/core/theme/river_theme.dart" as core_theme;

class DataSourcesScreen extends StatelessWidget {
  static const route = "/data-sources";
  const DataSourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = core_theme.RiverTheme.of(context).colors;
    return Scaffold(
      backgroundColor: c.scaffoldBg,
      appBar: AppBar(
        backgroundColor: c.scaffoldBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text("Data & Sources",
            style: TextStyle(
                color: c.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _InfoCard(
            c: c,
            icon: Icons.water_rounded,
            color: const Color(0xFF4CB3FF),
            title: "WRD Bihar",
            subtitle: "Bihar Water Resources Department",
            description:
                "Primary source for river gauge levels across Bihar. Data is scraped from the official WRD portal every 15 minutes during monsoon season.",
            tags: ["Live", "Bihar", "Official"],
          ),
          const SizedBox(height: 12),
          _InfoCard(
            c: c,
            icon: Icons.waves_rounded,
            color: const Color(0xFF3ACC8A),
            title: "CWC FFEM",
            subtitle: "Central Water Commission",
            description:
                "National flood forecasting data from CWC. Covers major river basins including Ganga, Kosi, Gandak, and Ghaghra with danger level thresholds.",
            tags: ["Live", "National", "Official"],
          ),
          const SizedBox(height: 12),
          _InfoCard(
            c: c,
            icon: Icons.public_rounded,
            color: const Color(0xFF818CF8),
            title: "GloFAS",
            subtitle: "Global Flood Awareness System",
            description:
                "European Centre for Medium-Range Weather Forecasts (ECMWF) global flood model. Used for 24/48/72 hour forecasts and rainfall predictions.",
            tags: ["Forecast", "Global", "ECMWF"],
          ),
          const SizedBox(height: 12),
          _InfoCard(
            c: c,
            icon: Icons.psychology_rounded,
            color: const Color(0xFFFFC857),
            title: "LSTM AI Model",
            subtitle: "OpsFlood BiLSTM v1.3",
            description:
                "In-house trained Bidirectional LSTM model on 20+ years of Bihar hydrological data. Generates risk scores and flood predictions per station.",
            tags: ["AI", "On-device", "Private"],
          ),
          const SizedBox(height: 24),
          _PrivacyCard(c: c),
          const SizedBox(height: 12),
          _StorageCard(c: c),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final dynamic c;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String description;
  final List<String> tags;

  const _InfoCard({
    required this.c,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.tags,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.surfaceOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                Text(subtitle,
                    style: TextStyle(color: c.textSecondary, fontSize: 11)),
              ],
            )),
          ]),
          const SizedBox(height: 10),
          Text(description,
              style:
                  TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags
                .map((tag) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: color.withValues(alpha: 0.25)),
                      ),
                      child: Text(tag,
                          style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  final dynamic c;
  const _PrivacyCard({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3ACC8A).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF3ACC8A).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.lock_outline_rounded,
                color: const Color(0xFF3ACC8A), size: 18),
            const SizedBox(width: 8),
            Text("Privacy",
                style: TextStyle(
                    color: const Color(0xFF3ACC8A),
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          Text(
              "Your location is only used to center the map and is never stored or shared. No personal data leaves your device. Flood alerts are based on public river gauge data only.",
              style:
                  TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}

class _StorageCard extends StatelessWidget {
  final dynamic c;
  const _StorageCard({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.surfaceOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.storage_rounded, color: c.textSecondary, size: 18),
            const SizedBox(width: 8),
            Text("What we store",
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          _StorageRow(
              c: c,
              label: "River levels",
              detail: "Cached locally, updated every 15 min",
              stored: true),
          _StorageRow(
              c: c,
              label: "AI predictions",
              detail: "Cached locally for offline use",
              stored: true),
          _StorageRow(
              c: c,
              label: "Alert subscriptions",
              detail: "Station names only, stored locally",
              stored: true),
          _StorageRow(
              c: c,
              label: "Your location",
              detail: "Never stored",
              stored: false),
          _StorageRow(
              c: c,
              label: "Personal data",
              detail: "Never collected",
              stored: false),
        ],
      ),
    );
  }
}

class _StorageRow extends StatelessWidget {
  final dynamic c;
  final String label;
  final String detail;
  final bool stored;
  const _StorageRow(
      {required this.c,
      required this.label,
      required this.detail,
      required this.stored});

  @override
  Widget build(BuildContext context) {
    final color = stored ? const Color(0xFF4CB3FF) : const Color(0xFF3ACC8A);
    final icon = stored ? Icons.check_rounded : Icons.block_rounded;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 10),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            Text(detail,
                style: TextStyle(color: c.textSecondary, fontSize: 11)),
          ],
        )),
      ]),
    );
  }
}
