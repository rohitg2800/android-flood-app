// File: lib/widgets/map/map_top_bar.dart
// Updated: June 2026
// Changes: Added live station counter subtitle + search autocomplete
//          (Task 4 — FloodDataProvider Consumer + Autocomplete<FloodStation>)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/flood_station.dart';
import '../../providers/flood_data_provider.dart';
import '../../providers/map_command_provider.dart';
import '../../theme/rx.dart';

// ── MapTopBar ─────────────────────────────────────────────────────────────────
class MapTopBar extends StatelessWidget {
  final MapViewMode  mode;
  final SyncMeta     syncMeta;
  final bool         drawerOpen;
  final VoidCallback onToggle;
  final VoidCallback onDrawerToggle;
  final void Function(FloodStation station) onStationSelected;

  const MapTopBar({
    super.key,
    required this.mode,
    required this.syncMeta,
    required this.drawerOpen,
    required this.onToggle,
    required this.onDrawerToggle,
    required this.onStationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final rc      = context.rc;
    final isBihar = mode == MapViewMode.bihar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color:        rc.cardBg.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                  border:       Border.all(color: rc.stroke, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.radar_rounded,
                        color: rc.accent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'COMMAND CENTER',
                            style: TextStyle(
                              color:         rc.textPrimary,
                              fontSize:      13,
                              fontWeight:    FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          // ── Live station counter (Task 4) ────────────────
                          Consumer<FloodDataProvider>(
                            builder: (_, p, __) {
                              final critical = p.biharStations
                                  .where((s) => s.riskLevel == 'CRITICAL')
                                  .length;
                              return Text(
                                '${p.biharLiveCount} stations live · $critical critical',
                                style: TextStyle(
                                  color:      rc.textSecondary,
                                  fontSize:   10,
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            MapIconBtn(
              icon:    drawerOpen
                           ? Icons.close_rounded
                           : Icons.list_rounded,
              onTap:   onDrawerToggle,
              tooltip: 'Live Telemetry',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            MapToggleChip(
              label:  '🗺 Bihar',
              active: isBihar,
              onTap:  isBihar ? null : onToggle,
            ),
            const SizedBox(width: 8),
            MapToggleChip(
              label:  '🇮🇳 National',
              active: !isBihar,
              onTap:  isBihar ? onToggle : null,
            ),
          ],
        ),
        const SizedBox(height: 6),
        // ── Search autocomplete (Task 4) ─────────────────────────────────
        Consumer<FloodDataProvider>(
          builder: (_, provider, __) {
            final stations = isBihar
                ? provider.biharStations
                : provider.allStations;
            return Autocomplete<FloodStation>(
              displayStringForOption: (s) =>
                  '${s.city} · ${s.riverName}',
              optionsBuilder: (TextEditingValue textValue) {
                if (textValue.text.isEmpty) return const [];
                final query = textValue.text.toLowerCase();
                return stations.where((s) =>
                    s.city.toLowerCase().contains(query) ||
                    s.riverName.toLowerCase().contains(query));
              },
              onSelected: (FloodStation selected) {
                onStationSelected(selected);
              },
              fieldViewBuilder: (
                context,
                controller,
                focusNode,
                onFieldSubmitted,
              ) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: rc.cardBg.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: rc.stroke.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded,
                          size: 15, color: rc.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller:  controller,
                          focusNode:   focusNode,
                          style: TextStyle(
                            color:    rc.textPrimary,
                            fontSize: 12,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search station or city…',
                            hintStyle: TextStyle(
                              color:    rc.textSecondary,
                              fontSize: 12,
                            ),
                            border:         InputBorder.none,
                            isDense:        true,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 6),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              optionsViewBuilder: (
                context,
                onSelected,
                options,
              ) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    color:        rc.cardBg,
                    elevation:    4,
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                          maxHeight: 220, maxWidth: 320),
                      child: ListView.builder(
                        padding:     EdgeInsets.zero,
                        shrinkWrap:  true,
                        itemCount:   options.length,
                        itemBuilder: (context, index) {
                          final s = options.elementAt(index);
                          final riskColor = _riskColor(s.riskLevel);
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius:          6,
                              backgroundColor: riskColor,
                            ),
                            title: Text(
                              s.city,
                              style: TextStyle(
                                color:      rc.textPrimary,
                                fontSize:   12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              s.riverName,
                              style: TextStyle(
                                color:    rc.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                            onTap: () => onSelected(s),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 4),
        // ── Sync freshness bar ───────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color:        rc.cardBg.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(8),
            border:       Border.all(
                color: rc.stroke.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(Icons.sync_rounded, size: 13, color: rc.accent),
              const SizedBox(width: 6),
              Text(
                'Data last synced: ${syncMeta.freshnessLabel}',
                style: TextStyle(
                  color:      rc.textSecondary,
                  fontSize:   11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _riskColor(String level) {
    switch (level) {
      case 'CRITICAL': return const Color(0xFFC62828);
      case 'HIGH':     return const Color(0xFFFF8F00);
      case 'MODERATE': return const Color(0xFFF57F17);
      case 'LOW':      return const Color(0xFF2E7D32);
      default:         return const Color(0xFF757575);
    }
  }
}

// ── MapIconBtn ────────────────────────────────────────────────────────────────
class MapIconBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;
  final String       tooltip;

  const MapIconBtn({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip = '',
  });

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color:        rc.cardBg.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: rc.stroke),
          ),
          child: Icon(icon, color: rc.accent, size: 20),
        ),
      ),
    );
  }
}

// ── MapToggleChip ─────────────────────────────────────────────────────────────
class MapToggleChip extends StatelessWidget {
  final String        label;
  final bool          active;
  final VoidCallback? onTap;

  const MapToggleChip({
    super.key,
    required this.label,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? rc.accent.withValues(alpha: 0.15)
              : rc.cardBg.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? rc.accent : rc.stroke,
            width: active ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:      active ? rc.accent : rc.textSecondary,
            fontSize:   12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
