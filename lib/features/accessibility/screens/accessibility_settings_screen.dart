import 'package:flutter/material.dart';

class AccessibilitySettingsScreen extends StatelessWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
<<<<<<< HEAD
      appBar: AppBar(title: const Text('Accessibility Settings')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Accessibility settings are temporarily unavailable while this feature is being integrated.',
=======
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Accessibility',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _SectionHeader('Visual'),
          _ToggleTile(
            icon: Icons.contrast_rounded,
            label: 'High Contrast',
            subtitle: 'Enhances visibility for low vision users',
            value: settings.highContrast,
            onChanged: (_) => notifier.toggleHighContrast(),
          ),
          _ToggleTile(
            icon: Icons.text_increase_rounded,
            label: 'Large Text',
            subtitle: 'Increases font size across the app',
            value: settings.largeIcons,
            onChanged: (_) => notifier.toggleLargeIcons(),
          ),
          _ToggleTile(
            icon: Icons.animation_rounded,
            label: 'Reduce Motion',
            subtitle: 'Minimises animations and transitions',
            value: settings.reduceMotion,
            onChanged: (_) => notifier.toggleReduceMotion(),
          ),
          const SizedBox(height: 8),
          _SectionHeader('Audio & Speech'),
          _ToggleTile(
            icon: Icons.record_voice_over_rounded,
            label: 'Screen Reader Mode',
            subtitle: 'Optimises layout for TalkBack / screen readers',
            value: settings.screenReaderOptimized,
            onChanged: (_) => notifier.toggleScreenReaderOptimized(),
          ),
          _ToggleTile(
            icon: Icons.volume_up_rounded,
            label: 'Text-to-Speech Alerts',
            subtitle: 'Reads flood alerts aloud with severity and station',
            value: settings.textToSpeechAlerts,
            onChanged: (_) => notifier.toggleTTS(),
          ),
          const SizedBox(height: 8),
          _SectionHeader('Haptics'),
          _ToggleTile(
            icon: Icons.vibration_rounded,
            label: 'Haptic Feedback',
            subtitle: 'Tactile feedback on interactions',
            value: settings.hapticFeedback,
            onChanged: (_) => notifier.toggleHaptic(),
          ),
          _ToggleTile(
            icon: Icons.sos_rounded,
            label: 'Custom Vibration Patterns',
            subtitle: 'SOS pattern for emergency, distinct per severity tier',
            value: settings.customVibrationPatterns,
            onChanged: (_) => notifier.toggleVibration(),
          ),
          const SizedBox(height: 20),
          _SectionHeader('Text Scale'),
          _ScaleSlider(
            value: settings.fontSizeScale,
            onChanged: notifier.setFontSizeScale,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
            color: Color(0xFF00D4FF),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF12121A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF00D4FF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF00D4FF), size: 20),
        ),
        title: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style:
                TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
        trailing: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF00D4FF),
          inactiveThumbColor: Colors.white30,
          inactiveTrackColor: Colors.white10,
>>>>>>> 62aa11686ade765099217874c2d458aa2faccf9d
        ),
      ),
    );
  }
}
