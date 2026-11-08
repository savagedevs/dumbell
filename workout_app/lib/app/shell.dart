import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'routes.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: child,
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (next) {
        if (next == index) return;
        Get.offNamed(
          [
            AppRoutes.home,
            AppRoutes.history,
            AppRoutes.progress,
            AppRoutes.exercises,
          ][next],
        );
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.history_rounded),
          label: 'History',
        ),
        NavigationDestination(
          icon: Icon(Icons.insights_outlined),
          label: 'Progress',
        ),
        NavigationDestination(
          icon: Icon(Icons.fitness_center_rounded),
          label: 'Exercises',
        ),
      ],
    ),
  );
}
