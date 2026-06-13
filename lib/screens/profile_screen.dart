// lib/screens/profile_screen.dart  — Riverpod rebuild
// Removed package:provider dependency; uses flutter_riverpod throughout.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';

// ── Minimal auth state stub (replace with real Firebase auth provider) ────────
class _AuthState {
  final String? email;
  final String? displayName;
  final bool isLoggedIn;
  const _AuthState({this.email, this.displayName, this.isLoggedIn = false});
}

final _authProvider = Provider<_AuthState>((_) => const _AuthState(
  email: null,
  displayName: null,
  isLoggedIn: false,
));

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t    = RiverColors.of(context);
    final auth = ref.watch(_authProvider);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          Td3AppBar(
            title: 'Profile',
            subtitle: auth.email ?? 'Guest',
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: t.textPrimary, size: 18),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Avatar tile
                Td3Card(
                  elevation: Td3.elevHigh,
                  accentColor: t.accent,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                t.accent.withValues(alpha: 0.30),
                                t.accent.withValues(alpha: 0.10),
                              ],
                            ),
                            border: Border.all(
                                color: t.accent.withValues(alpha: 0.4)),
                          ),
                          child: Icon(Icons.person_rounded,
                              color: t.accent, size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                auth.displayName ?? 'User',
                                style: TextStyle(
                                    color: t.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                auth.email ?? 'Not signed in',
                                style: TextStyle(
                                    color: t.textSecondary, fontSize: 13),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: auth.isLoggedIn
                                      ? AppPalette.safe.withValues(alpha: 0.15)
                                      : AppPalette.warning.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: auth.isLoggedIn
                                        ? AppPalette.safe.withValues(alpha: 0.4)
                                        : AppPalette.warning.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  auth.isLoggedIn ? 'Verified' : 'Guest',
                                  style: TextStyle(
                                    color: auth.isLoggedIn
                                        ? AppPalette.safe
                                        : AppPalette.warning,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Placeholder settings rows
                _ProfileTile(
                    icon: Icons.notifications_outlined,
                    label: 'Notification Preferences',
                    t: t),
                _ProfileTile(
                    icon: Icons.language_outlined,
                    label: 'Language',
                    t: t),
                _ProfileTile(
                    icon: Icons.info_outline_rounded,
                    label: 'About OpsFlood',
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
  final IconData icon;
  final String   label;
  final RiverColors t;
  const _ProfileTile({
    required this.icon, required this.label, required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: t.cardBg, borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: t.accent, size: 20),
        title: Text(label, style: TextStyle(color: t.textPrimary, fontSize: 14)),
        trailing: Icon(Icons.chevron_right, color: t.textSecondary, size: 18),
        onTap: () {},
      ),
    );
  }
}
