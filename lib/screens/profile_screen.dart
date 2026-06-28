// lib/screens/profile_screen.dart  v2.0
// Full profile editor — name/email/phone/district, notification prefs, account stats
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import '../app_router.dart';

class ProfileScreen extends StatefulWidget {
  static const route = '/profile';
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl     = TextEditingController(text: 'Flood Officer');
  final _emailCtrl    = TextEditingController(text: 'officer@bwrd.gov.in');
  final _phoneCtrl    = TextEditingController(text: '+91 98765 43210');
  final _districtCtrl = TextEditingController(text: 'Patna');

  bool _editMode          = false;
  bool _notifCritical     = true;
  bool _notifWarning      = true;
  bool _notifRainfall     = false;
  bool _notifWeeklyReport = true;

  static const _districts = [
    'Patna','Muzaffarpur','Darbhanga','Bhagalpur','Gaya','Nalanda',
    'Vaishali','Saran','Siwan','Gopalganj','Madhubani','Sitamarhi',
    'Supaul','Saharsa','Madhepura','Khagaria','Samastipur','Begusarai',
    'Munger','Bhojpur','Buxar','Rohtas','Kaimur','Araria','Purnia',
    'Katihar','Kishanganj','E. Champaran','W. Champaran','Sheohar',
  ];

  String _initials() {
    final parts = _nameCtrl.text.trim().split(' ');
    if (parts.isEmpty) return 'FO';
    return parts.length == 1
        ? parts[0].substring(0, 2).toUpperCase()
        : '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _phoneCtrl.dispose(); _districtCtrl.dispose();
    super.dispose();
  }

  void _save() {
    HapticFeedback.mediumImpact();
    setState(() => _editMode = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Profile saved'),
        backgroundColor: const Color(0xFF26A69A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(Routes.onboarding, (r) => false); },
            child: const Text('Sign Out', style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          Td3AppBar(
            title: 'Profile',
            subtitle: 'Account & preferences',
            actions: [
              TextButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  if (_editMode) { _save(); } else { setState(() => _editMode = true); }
                },
                child: Text(_editMode ? 'Save' : 'Edit',
                  style: const TextStyle(color: Color(0xFF2196F3), fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 60),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Avatar ────────────────────────────────────────────────
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 84, height: 84,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: const Color(0xFF1976D2).withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))],
                        ),
                        child: Center(child: Text(_initials(), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800))),
                      ),
                      if (_editMode)
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            width: 26, height: 26,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1976D2),
                              shape: BoxShape.circle,
                              border: Border.all(color: t.scaffoldBg, width: 2),
                            ),
                            child: const Center(child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 12)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(child: Text(_nameCtrl.text, style: TextStyle(color: t.textPrimary, fontSize: 18, fontWeight: FontWeight.w700))),
                Center(child: Text('Bihar Water Resources Dept.', style: TextStyle(color: t.textSecondary, fontSize: 11))),
                const SizedBox(height: 20),

                // ── Account Stats ─────────────────────────────────────────
                Row(
                  children: [
                    _StatCell(t: t, label: 'Days Active', value: '142'),
                    _StatCell(t: t, label: 'Reports',     value: '23'),
                    _StatCell(t: t, label: 'Alerts Recv', value: '387'),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Edit fields ───────────────────────────────────────────
                Td3Card(
                  elevation: Td3.elevMid,
                  accentColor: const Color(0xFF2196F3),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ACCOUNT DETAILS', style: TextStyle(color: const Color(0xFF2196F3), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                        const SizedBox(height: 14),
                        _EditField(t: t, label: 'Full Name',     ctrl: _nameCtrl,     icon: Icons.person_rounded,     enabled: _editMode),
                        _EditField(t: t, label: 'Email',         ctrl: _emailCtrl,    icon: Icons.email_rounded,       enabled: _editMode, keyboard: TextInputType.emailAddress),
                        _EditField(t: t, label: 'Phone',         ctrl: _phoneCtrl,    icon: Icons.phone_rounded,       enabled: _editMode, keyboard: TextInputType.phone),
                        _EditField(t: t, label: 'District',      ctrl: _districtCtrl, icon: Icons.location_on_rounded, enabled: _editMode, isDropdown: true, dropdownItems: _districts),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Notification prefs ────────────────────────────────────
                Td3Card(
                  elevation: Td3.elevMid,
                  accentColor: const Color(0xFFFF8F00),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NOTIFICATION PREFERENCES', style: TextStyle(color: const Color(0xFFFF8F00), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                        const SizedBox(height: 14),
                        _ToggleRow(t: t, label: 'Critical & Emergency Alerts', icon: Icons.warning_rounded, color: const Color(0xFFE53935),
                          value: _notifCritical, onChanged: (v) => setState(() => _notifCritical = v)),
                        _ToggleRow(t: t, label: 'Warning Level Alerts',       icon: Icons.report_problem_rounded, color: const Color(0xFFFF8F00),
                          value: _notifWarning, onChanged: (v) => setState(() => _notifWarning = v)),
                        _ToggleRow(t: t, label: 'Heavy Rainfall Alerts',      icon: Icons.grain_rounded, color: const Color(0xFF1976D2),
                          value: _notifRainfall, onChanged: (v) => setState(() => _notifRainfall = v)),
                        _ToggleRow(t: t, label: 'Weekly Summary Report',      icon: Icons.assessment_rounded, color: const Color(0xFF26A69A),
                          value: _notifWeeklyReport, onChanged: (v) => setState(() => _notifWeeklyReport = v)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Sign Out ──────────────────────────────────────────────
                Td3Card(
                  elevation: Td3.elevLow,
                  accentColor: const Color(0xFFE53935),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _confirmSignOut,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      child: Row(
                        children: [
                          const Icon(Icons.logout_rounded, color: Color(0xFFE53935), size: 20),
                          const SizedBox(width: 12),
                          Text('Sign Out', style: const TextStyle(color: Color(0xFFE53935), fontSize: 14, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          const Icon(Icons.chevron_right_rounded, color: Color(0xFFE53935), size: 18),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final RiverColors t;
  final String label, value;
  const _StatCell({required this.t, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Color(0xFF2196F3), fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(color: t.textSecondary, fontSize: 9), textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _EditField extends StatelessWidget {
  final RiverColors t;
  final String label;
  final TextEditingController ctrl;
  final IconData icon;
  final bool enabled;
  final TextInputType keyboard;
  final bool isDropdown;
  final List<String> dropdownItems;

  const _EditField({
    required this.t, required this.label, required this.ctrl,
    required this.icon, required this.enabled,
    this.keyboard = TextInputType.text,
    this.isDropdown = false, this.dropdownItems = const [],
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: t.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        if (isDropdown && enabled)
          DropdownButtonFormField<String>(
            value: dropdownItems.contains(ctrl.text) ? ctrl.text : null,
            hint: Text(ctrl.text, style: TextStyle(color: t.textPrimary, fontSize: 13)),
            items: dropdownItems.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) { if (v != null) ctrl.text = v; },
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: const Color(0xFF2196F3), size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          )
        else
          TextField(
            controller: ctrl,
            enabled:    enabled,
            keyboardType: keyboard,
            style: TextStyle(color: t.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: enabled ? const Color(0xFF2196F3) : t.textSecondary, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: t.stroke.withValues(alpha: 0.3)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
      ],
    ),
  );
}

class _ToggleRow extends StatelessWidget {
  final RiverColors t;
  final String label;
  final IconData icon;
  final Color color;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.t, required this.label, required this.icon, required this.color, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(color: t.textPrimary, fontSize: 12, fontWeight: FontWeight.w500))),
        Switch.adaptive(
          value: value,
          onChanged: (v) { HapticFeedback.selectionClick(); onChanged(v); },
          activeColor: color,
        ),
      ],
    ),
  );
}
