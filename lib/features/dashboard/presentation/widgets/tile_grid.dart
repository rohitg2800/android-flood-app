import "package:flutter/material.dart";
import "../../domain/dashboard_tile.dart";
import "launcher_tile.dart";

class TileGrid extends StatelessWidget {
  final List<DashboardTile> tiles;
  final int columns;
  const TileGrid({super.key, required this.tiles, this.columns = 3});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: columns == 2 ? 1.6 : 1.05,
        ),
        itemCount: tiles.length,
        itemBuilder: (_, i) => LauncherTile(tile: tiles[i]),
      ),
    );
  }
}