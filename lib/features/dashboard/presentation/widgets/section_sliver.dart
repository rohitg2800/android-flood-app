import "package:flutter/material.dart";
import "package:equinox_flood/core/widgets/ops_section_header.dart";
import "../../domain/dashboard_tile.dart";
import "tile_grid.dart";

class SectionSliver extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<DashboardTile> tiles;
  final int columns;

  const SectionSliver({
    super.key,
    required this.label,
    required this.icon,
    required this.tiles,
    this.columns = 3,
  });

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: OpsSectionHeader(label: label, icon: icon)),
        TileGrid(tiles: tiles, columns: columns),
      ],
    );
  }
}