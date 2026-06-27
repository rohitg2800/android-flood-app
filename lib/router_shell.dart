import 'package:flutter/material.dart';

// Small standalone widget for a 4-tab bottom navigation shell.
// This is intentionally kept independent from existing legacy MainShell
// so it can be wired into GoRouter's ShellRoute.

class FourTabShellScaffold extends StatefulWidget {
  final int currentIndex;
  final Widget dashboard;
  final Widget map;
  final Widget alerts;
  final Widget profile;

  const FourTabShellScaffold({
    super.key,
    required this.currentIndex,
    required this.dashboard,
    required this.map,
    required this.alerts,
    required this.profile,
  });

  @override
  State<FourTabShellScaffold> createState() => _FourTabShellScaffoldState();
}

class _FourTabShellScaffoldState extends State<FourTabShellScaffold> {
  late int _index = widget.currentIndex;

  @override
  void didUpdateWidget(covariant FourTabShellScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _index = widget.currentIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final body = IndexedStack(
      index: _index,
      children: [
        widget.dashboard,
        widget.map,
        widget.alerts,
        widget.profile,
      ],
    );

    return Scaffold(
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _index,
        backgroundColor: cs.surface,
        selectedItemColor: cs.primary,
        unselectedItemColor: cs.onSurface.withValues(alpha: 0.6),
        onTap: (i) {
          setState(() => _index = i);
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Map'),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications_rounded), label: 'Alerts'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

class IndexedStack extends StatelessWidget {
  final int index;
  final List<Widget> children;
  const IndexedStack({super.key, required this.index, required this.children});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(children.length, (i) {
        return Offstage(
          offstage: i != index,
          child: TickerMode(
            enabled: i == index,
            child: children[i],
          ),
        );
      }),
    );
  }
}
