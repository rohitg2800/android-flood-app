// lib/widgets/nearby_stations_section.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/nearby_stations_provider.dart';
import '../services/emergency_contact_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

class NearbyStationsSection extends ConsumerWidget {
  const NearbyStationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nearbyStationsProvider);
    final colors = Theme.of(context).colorScheme;

    if (state.isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: colors.primary),
          ),
        ),
      );
    }

    if (state.cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(Icons.place_rounded, size: 16, color: colors.primary),
              const SizedBox(width: 6),
              Text(
                'PREFERRED CITIES',
                style: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),

        // ── Horizontal card list ────────────────────────────────────────
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: state.cards.length,
            itemBuilder: (ctx, i) => _PreferredCityCard(card: state.cards[i]),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PreferredCityCard
// ─────────────────────────────────────────────────────────────────────────────

class _PreferredCityCard extends StatelessWidget {
  final NearbyCardState card;
  const _PreferredCityCard({required this.card});

  Color _riskColor(String label) {
    switch (label.toUpperCase()) {
      case 'CRITICAL':
      case 'DANGER':
        return const Color(0xFFFF3B30);
      case 'SEVERE':
        return const Color(0xFFFF6B35);
      case 'HIGH':
      case 'WARNING':
        return const Color(0xFFFFCC00);
      default:
        return const Color(0xFF34C759);
    }
  }

  @override
  Widget build(BuildContext context) {
    final station = card.nearby.station;
    final contacts = card.contacts;
    final scheme = Theme.of(context).colorScheme;
    final color = _riskColor(station.riskLabel);

    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header band ───────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.water_rounded, size: 14, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    station.station,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Risk pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    station.riskLabel,
                    style: TextStyle(
                      color: color,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── River + state ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Text(
              '${station.river}  •  ${station.state}',
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.55),
                fontSize: 10,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // ── Level progress bar ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: station.danger > 0
                        ? (station.current / station.danger).clamp(0.0, 1.0)
                        : 0.0,
                    backgroundColor: scheme.onSurface.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${station.current.toStringAsFixed(2)} m'
                  ' / ${station.danger.toStringAsFixed(2)} m',
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),

          // ── Divider ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: scheme.onSurface.withValues(alpha: 0.12),
            ),
          ),

          // ── Emergency contact feed ────────────────────────────────────
          Expanded(
            child: contacts.isEmpty
                ? _noContactsPlaceholder(context)
                : _ContactFeed(contacts: contacts),
          ),
        ],
      ),
    );
  }

  Widget _noContactsPlaceholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Icon(Icons.phone_disabled_rounded,
              size: 13, color: scheme.onSurface.withValues(alpha: 0.4)),
          const SizedBox(width: 6),
          Text(
            'No contacts on file',
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.4),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ContactFeed — shows up to 4 contacts, non-scrollable inside the card
// ─────────────────────────────────────────────────────────────────────────────

class _ContactFeed extends StatelessWidget {
  final List<EmergencyContact> contacts;
  const _ContactFeed({required this.contacts});

  @override
  Widget build(BuildContext context) {
    final shown = contacts.take(4).toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: shown.length,
      itemBuilder: (ctx, i) => _ContactRow(contact: shown[i]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ContactRow
// ─────────────────────────────────────────────────────────────────────────────

class _ContactRow extends StatelessWidget {
  final EmergencyContact contact;
  const _ContactRow({required this.contact});

  Color _catColor() {
    switch (contact.category) {
      case 'NDRF':
        return const Color(0xFF007AFF);
      case 'NDMA':
        return const Color(0xFFFF6B35);
      case 'SDRF Bihar':
        return const Color(0xFFFF3B30);
      case 'District Administration':
        return const Color(0xFF34C759);
      case 'Barrage':
        return const Color(0xFF5AC8FA);
      case 'Medical':
        return const Color(0xFFFF2D55);
      case 'Emergency':
        return const Color(0xFFFF9500);
      default:
        return const Color(0xFF8E8E93);
    }
  }

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: contact.phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cat = _catColor();

    return GestureDetector(
      onTap: _call,
      onLongPress: () {
        HapticFeedback.mediumImpact();
        Clipboard.setData(ClipboardData(text: contact.phone));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${contact.phone} copied'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            // Category colour dot
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: cat, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),

            // Contact name
            Expanded(
              child: Text(
                contact.name,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Phone chip
            GestureDetector(
              onTap: _call,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cat.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: cat.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.call_rounded, size: 9, color: cat),
                    const SizedBox(width: 3),
                    Text(
                      contact.phone,
                      style: TextStyle(
                        color: cat,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
