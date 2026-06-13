// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import '../providers/theme_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = RiverColors.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: CustomScrollView(
        slivers: [
          Td3AppBar(
            title: 'Profile',
            actions: [
              IconButton(
                icon: Icon(Icons.edit_rounded, color: t.textSecondary, size: 20),
                onPressed: () {},
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Avatar + Name card
                Td3Card(
                  elevation: Td3.elevHigh,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: t.accent.withValues(alpha: 0.15),
                            border: Border.all(
                              color: t.accent.withValues(alpha: 0.4),
                              width: 2,
                            ),
                          ),
                          child: Icon(Icons.person_rounded,
                              color: t.accent, size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('OpsFlood User',
                                  style: TextStyle(
                                      color: t.textPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text('Bihar Flood Monitoring',
                                  style: TextStyle(
                                      color: t.textSecondary,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Profile menu tiles
                _ProfileTile(
                    icon: Icons.notifications_rounded,
                    label: 'Notification Preferences',
                    t: t),
                _ProfileTile(
                    icon: Icons.location_on_rounded,
                    label: 'Saved Locations',
                    t: t),
                _ProfileTile(
                    icon: Icons.share_rounded,
                    label: 'Share OpsFlood',
                    t: t),
                _ProfileTile(
                    icon: Icons.info_outline_rounded,
                    label: 'About',
                    t: t),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData   icon;
  final String     label;
  final RiverColors t;

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    // Use Material instead of Container+BoxDecoration so ListTile ink splashes
    // paint on Material, not on an intercepting DecoratedBox.
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(icon, color: t.accent, size: 20),
          title: Text(label,
              style:
                  TextStyle(color: t.textPrimary, fontSize: 14)),
          trailing: Icon(Icons.chevron_right,
              color: t.textSecondary, size: 18),
          onTap: () {},
        ),
      ),
    );
  }
}
