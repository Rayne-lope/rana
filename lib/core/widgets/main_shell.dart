import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rana/core/router/app_router.dart';

/// Shell widget that wraps the three main screens (Camera, Gallery, Settings)
/// and renders a persistent [NavigationBar] at the bottom.
///
/// Navigation state is managed by [StatefulShellRoute] — each branch preserves
/// its own navigator stack when the user switches tabs.
class MainShell extends StatelessWidget {
  const MainShell({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  static const List<_Destination> _destinations = [
    _Destination(
      icon: Icons.camera_alt_outlined,
      selectedIcon: Icons.camera_alt,
      label: 'Camera',
      route: AppRoutes.camera,
    ),
    _Destination(
      icon: Icons.photo_library_outlined,
      selectedIcon: Icons.photo_library,
      label: 'Gallery',
      route: AppRoutes.gallery,
    ),
    _Destination(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'Settings',
      route: AppRoutes.settings,
    ),
  ];

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          backgroundColor: Colors.black,
          indicatorColor: Colors.white12,
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onDestinationSelected,
          destinations: _destinations
              .map(
                (d) => NavigationDestination(
                  icon: Icon(d.icon, color: Colors.white54),
                  selectedIcon: Icon(d.selectedIcon, color: Colors.white),
                  label: d.label,
                ),
              )
              .toList(),
        ),
      );
}

/// Immutable descriptor for a single [NavigationBar] destination.
class _Destination {
  const _Destination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;
}
