import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'dashboard_screen.dart';
import 'message_builder_screen.dart';
import 'exercises_screen.dart';
import 'attendance_screen.dart';
import 'admin/templates_management_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isAdmin = authProvider.isAdmin;

    final screens = [
      const DashboardScreen(),
      const MessageBuilderScreen(),
      const ExercisesScreen(),
      const AttendanceScreen(),
      if (isAdmin) const TemplatesManagementScreen(),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_getTitle(_currentIndex, isAdmin)),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _handleLogout(context),
              tooltip: '\u05d4\u05ea\u05e0\u05ea\u05e7',
            ),
          ],
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard),
              label: '\u05d3\u05e9\u05d1\u05d5\u05e8\u05d3',
            ),
            NavigationDestination(
              icon: const Icon(Icons.message_outlined),
              selectedIcon: const Icon(Icons.message),
              label: '\u05d1\u05e0\u05d9\u05d9\u05ea \u05d4\u05d5\u05d3\u05e2\u05d4',
            ),
            NavigationDestination(
              icon: const Icon(Icons.fitness_center_outlined),
              selectedIcon: const Icon(Icons.fitness_center),
              label: '\u05ea\u05e8\u05d2\u05d9\u05dc\u05d9\u05dd',
            ),
            NavigationDestination(
              icon: const Icon(Icons.people_outline),
              selectedIcon: const Icon(Icons.people),
              label: '\u05e0\u05d5\u05db\u05d7\u05d5\u05ea',
            ),
            if (isAdmin)
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: '\u05e0\u05d9\u05d4\u05d5\u05dc',
              ),
          ],
        ),
      ),
    );
  }

  String _getTitle(int index, bool isAdmin) {
    final titles = [
      '\u05d3\u05e9\u05d1\u05d5\u05e8\u05d3',
      '\u05d1\u05e0\u05d9\u05d9\u05ea \u05d4\u05d5\u05d3\u05e2\u05d4',
      '\u05ea\u05e8\u05d2\u05d9\u05dc\u05d9\u05dd',
      '\u05e0\u05d5\u05db\u05d7\u05d5\u05ea',
      if (isAdmin) '\u05e0\u05d9\u05d4\u05d5\u05dc',
    ];
    return titles[index];
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('\u05d4\u05ea\u05e0\u05ea\u05e7\u05d5\u05ea'),
          content: const Text(
            '\u05d4\u05d0\u05dd \u05d0\u05ea\u05d4 \u05d1\u05d8\u05d5\u05d7 \u05e9\u05d1\u05e8\u05e6\u05d5\u05e0\u05da \u05dc\u05d4\u05ea\u05e0\u05ea\u05e7?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('\u05d1\u05d9\u05d8\u05d5\u05dc'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('\u05d4\u05ea\u05e0\u05ea\u05e7'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true && context.mounted) {
      await context.read<AuthProvider>().signOut();
    }
  }
}
