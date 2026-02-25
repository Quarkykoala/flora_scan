import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/scan/scan_screen.dart';
import '../screens/plant/plant_detail_screen.dart';
import '../screens/plant/add_plant_screen.dart';
import '../screens/diagnosis/diagnosis_result_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/scan/scan_history_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/scan',
            name: 'scan',
            builder: (context, state) {
              final plantId = state.uri.queryParameters['plantId'];
              return ScanScreen(plantId: plantId);
            },
          ),
          GoRoute(
            path: '/scan-history',
            name: 'scan-history',
            builder: (context, state) {
              final plantId = state.uri.queryParameters['plantId'];
              return ScanHistoryScreen(plantId: plantId);
            },
          ),
          GoRoute(
            path: '/plant/add',
            name: 'add-plant',
            builder: (context, state) => const AddPlantScreen(),
          ),
          GoRoute(
            path: '/plant/:id',
            name: 'plant-detail',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return PlantDetailScreen(plantId: id);
            },
          ),
          GoRoute(
            path: '/diagnosis/:scanId',
            name: 'diagnosis-result',
            builder: (context, state) {
              final scanId = state.pathParameters['scanId']!;
              return DiagnosisResultScreen(scanId: scanId);
            },
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

/// Shell wrapper providing bottom navigation.
class HomeShell extends StatelessWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateSelectedIndex(context),
        onDestinationSelected: (index) => _onItemTapped(index, context),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.eco_outlined),
            selectedIcon: Icon(Icons.eco),
            label: 'Plants',
          ),
          NavigationDestination(
            icon: Icon(Icons.document_scanner_outlined),
            selectedIcon: Icon(Icons.document_scanner),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/') return 0;
    if (location.startsWith('/scan')) return 1;
    if (location.startsWith('/scan-history')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
      case 1:
        context.go('/scan');
      case 2:
        context.go('/scan-history');
      case 3:
        context.go('/settings');
    }
  }
}
