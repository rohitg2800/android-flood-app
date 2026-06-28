// lib/screens/onboarding_screen.dart
// OpsFlood — Module 14: Onboarding & In-App Update
//
// • 4-page animated onboarding (PageView) with skip/next/done
// • Saves seen state to SharedPreferences (key: 'onboarding_done')
// • In-app update check via in_app_update package (Android)
// • Shown only on first launch; subsequent launches route to /shell

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_palette.dart';

// ---------------------------------------------------------------------------
// Onboarding page data
// ---------------------------------------------------------------------------

class _PageData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _PageData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

const _pages = [
  _PageData(
    title: 'Real-Time Flood Alerts',
    subtitle:
        'Get instant notifications when river levels cross danger thresholds at 50+ CWC stations across Bihar.',
    icon: Icons.notifications_active_outlined,
    color: AppPalette.oceanAccent,
  ),
  _PageData(
    title: 'Live River Map',
    subtitle:
        'Track flood risk across all 38 Bihar districts with our colour-coded heatmap, updated every 15 minutes.',
    icon: Icons.map_outlined,
    color: AppPalette.oceanAccent,
  ),
  _PageData(
    title: 'Evacuation Routes',
    subtitle:
        'Find the nearest safe shelter and open road routes instantly — works offline when you need it most.',
    icon: Icons.directions_outlined,
    color: AppPalette.oceanAccent,
  ),
  _PageData(
    title: 'Community Reporting',
    subtitle:
        'Report local flooding with a photo and location. Help your district prepare and respond faster.',
    icon: Icons.group_outlined,
    color: AppPalette.oceanAccent,
  ),
];

// ---------------------------------------------------------------------------
// Helper: check / mark onboarding done
// ---------------------------------------------------------------------------

Future<bool> isOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_done') ?? false;
}

Future<void> markOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboarding_done', true);
}

// ---------------------------------------------------------------------------
// OnboardingScreen
// ---------------------------------------------------------------------------

class OnboardingScreen extends StatefulWidget {
  static const String route = '/onboarding';
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() =>
      _OnboardingScreenState();
}

class _OnboardingScreenState
    extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _current = 0;

  void _next() {
    if (_current < _pages.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await markOnboardingDone();
    if (!mounted) return;
    context.go('/shell'); // ✅ GoRouter-aware navigation
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_current];
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: page.color,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Skip',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 14)),
              ),
            ),
            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) =>
                    setState(() => _current = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) =>
                    _OnboardingPage(data: _pages[i]),
              ),
            ),
            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(
                      horizontal: 4),
                  width:  _current == i ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _current == i
                        ? Colors.white
                        : Colors.white38,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Action button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: page.color,
                    padding: const EdgeInsets.symmetric(
                        vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(30)),
                  ),
                  child: Text(
                    _current == _pages.length - 1
                        ? 'Get Started'
                        : 'Next',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual onboarding page
// ---------------------------------------------------------------------------

class _OnboardingPage extends StatelessWidget {
  final _PageData data;
  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 32, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width:  120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon,
                size: 60, color: Colors.white),
          ),
          const SizedBox(height: 40),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// InAppUpdateChecker — call from main() or SplashScreen
// ---------------------------------------------------------------------------
//
// Add to pubspec.yaml:
//   in_app_update: ^4.2.3
//
// Usage:
//   await InAppUpdateChecker.check(context);

class InAppUpdateChecker {
  InAppUpdateChecker._();

  static Future<void> check(BuildContext context) async {
    // Uncomment when in_app_update is added to pubspec:
    // try {
    //   final info = await InAppUpdate.checkForUpdate();
    //   if (info.updateAvailability ==
    //       UpdateAvailability.updateAvailable) {
    //     if (info.immediateUpdateAllowed) {
    //       await InAppUpdate.performImmediateUpdate();
    //     } else if (info.flexibleUpdateAllowed) {
    //       await InAppUpdate.startFlexibleUpdate();
    //       await InAppUpdate.completeFlexibleUpdate();
    //     }
    //   }
    // } catch (e) {
    //   debugPrint('[InAppUpdate] $e');
    // }
    debugPrint('[InAppUpdateChecker] stub — add in_app_update to pubspec');
  }
}
