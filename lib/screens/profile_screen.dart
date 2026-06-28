// lib/screens/profile_screen.dart  v2 — explicit back button
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/river_theme.dart';
import '../widgets/app_back_button.dart';

final _editingProvider = StateProvider<bool>((_) => false);
final _nameProvider    = StateProvider<String>((_) => 'OpsFlood User');
final _emailProvider   = StateProvider<String>((_) => 'user@opsflood.app');
final _phoneProvider   = StateProvider<String>((_) => '');

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t       = RiverColors.of(context);
    final editing = ref.watch(_editingProvider);
    final name    = ref.watch(_nameProvider);
    final email   = ref.watch(_emailProvider);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.navBg,
        foregroundColor: t.textPrimary,
        leading: const AppBackButton(),
        title: Text(
          'Profile',
          style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(_editingProvider.notifier).state = !editing,
            child: Text(
              editing ? 'Save' : 'Edit',
              style: TextStyle(
                  color: t.accent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // Avatar
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: t.accent.withValues(alpha: 0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: TextStyle(
                        color: t.accent,
                        fontSize: 38,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                if (editing)
                  Container(
                    decoration: BoxDecoration(
                      color: t.accent,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 16),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _ProfileField(
            t: t,
            label: 'Name',
            value: name,
            editing: editing,
            onChanged: (v) => ref.read(_nameProvider.notifier).state = v,
          ),
          const SizedBox(height: 10),
          _ProfileField(
            t: t,
            label: 'Email',
            value: email,
            editing: editing,
            onChanged: (v) => ref.read(_emailProvider.notifier).state = v,
          ),
          const SizedBox(height: 10),
          _ProfileField(
            t: t,
            label: 'Phone',
            value: ref.watch(_phoneProvider),
            editing: editing,
            hint: 'Add phone number',
            onChanged: (v) => ref.read(_phoneProvider.notifier).state = v,
          ),
          const SizedBox(height: 24),
          _InfoCard(
            t: t,
            text: 'Your profile is stored locally and is not shared with any server.',
          ),
        ],
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.t,
    required this.label,
    required this.value,
    required this.editing,
    required this.onChanged,
    this.hint,
  });
  final RiverColors t;
  final String label;
  final String value;
  final bool editing;
  final ValueChanged<String> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: editing
          ? TextFormField(
              initialValue: value,
              style: TextStyle(color: t.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(color: t.textSecondary, fontSize: 12),
                hintText: hint,
                border: InputBorder.none,
              ),
              onChanged: onChanged,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? (hint ?? '—') : value,
                  style: TextStyle(
                    color: value.isEmpty ? t.textSecondary : t.textPrimary,
                    fontSize: 14,
                    fontStyle:
                        value.isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.t, required this.text});
  final RiverColors t;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.accent.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: t.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style:
                  TextStyle(color: t.textSecondary, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
