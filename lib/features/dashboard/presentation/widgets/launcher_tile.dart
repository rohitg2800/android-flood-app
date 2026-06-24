import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:equinox_flood/core/theme/river_theme.dart" as core_theme;
import "package:equinox_flood/core/widgets/ops_badge.dart";
import "../../domain/dashboard_tile.dart";

class LauncherTile extends StatefulWidget {
  final DashboardTile tile;
  const LauncherTile({super.key, required this.tile});
  @override
  State<LauncherTile> createState() => _LauncherTileState();
}

class _LauncherTileState extends State<LauncherTile> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scale = Tween(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _onTap() {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(context, widget.tile.route);
  }

  @override
  Widget build(BuildContext context) {
    final c     = core_theme.RiverTheme.of(context).colors;
    final color = widget.tile.color;
    return GestureDetector(
      onTapDown:   (_) => _ctrl.forward(),
      onTapUp:     (_) { _ctrl.reverse(); _onTap(); },
      onTapCancel: ()  => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            color: c.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.surfaceOutline),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.28)),
                ),
                child: Icon(widget.tile.icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                widget.tile.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: c.textPrimary, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.tile.badge != null) ...[
                const SizedBox(height: 4),
                OpsBadge(label: widget.tile.badge!, variant: OpsBadgeVariant.danger),
              ],
            ],
          ),
        ),
      ),
    );
  }
}