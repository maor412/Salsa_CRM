import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../config/app_theme.dart';
import '../widgets/app_dialog.dart';
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
          elevation: 0,
          actions: [
            Container(
              margin: const EdgeInsets.only(left: AppSpacing.sm),
              child: IconButton(
                icon: const Icon(Icons.logout_rounded),
                onPressed: () => _handleLogout(context),
                tooltip: 'התנתק',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.15),
                  foregroundColor: Colors.white,
                ),
              ),
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
            const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'דשבורד',
            ),
            const NavigationDestination(
              icon: Icon(Icons.message_outlined),
              selectedIcon: Icon(Icons.message_rounded),
              label: 'בניית הודעה',
            ),
            const NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined),
              selectedIcon: Icon(Icons.fitness_center_rounded),
              label: 'תרגילים',
            ),
            const NavigationDestination(
              icon: Icon(Icons.people_outline_rounded),
              selectedIcon: Icon(Icons.people_rounded),
              label: 'נוכחות',
            ),
            if (isAdmin)
              const NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'ניהול',
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
    final confirm = await AppDialog.showConfirmDialog(
      context: context,
      title: 'התנתקות',
      content: 'האם אתה בטוח שברצונך להתנתק?',
      confirmText: 'התנתק',
      cancelText: 'ביטול',
      isDestructive: true,
    );

    if (confirm == true && context.mounted) {
      await context.read<AuthProvider>().signOut();
    }
  }
}
