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
  static const double _bottomNavHeight = 72;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const DashboardScreen(),
      const MessageBuilderScreen(),
      const ExercisesScreen(),
      const AttendanceScreen(),
      if (context.read<AuthProvider>().isAdmin)
        const TemplatesManagementScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    print('HomeScreen build: viewInsets.bottom=${mq.viewInsets.bottom}');
    final authProvider = context.watch<AuthProvider>();
    final isAdmin = authProvider.isAdmin;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: Text(_getTitle(_currentIndex, isAdmin)),
          elevation: 0,
          actions: [
            Container(
              margin: const EdgeInsets.only(left: AppSpacing.sm),
              child: IconButton(
                icon: const Icon(Icons.logout_rounded),
                onPressed: () => _handleLogout(context),
                tooltip: '\u05d4\u05ea\u05e0\u05ea\u05e7',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.15),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(
                bottom: _bottomNavHeight + mq.padding.bottom,
              ),
              child: IndexedStack(
                index: _currentIndex,
                children: _pages,
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: _bottomNavHeight,
                  child: _buildBottomNav(isAdmin),
                ),
              ),
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
      title: '\u05d4\u05ea\u05e0\u05ea\u05e7\u05d5\u05ea',
      content:
          '\u05d4\u05d0\u05dd \u05d0\u05ea\u05d4 \u05d1\u05d8\u05d5\u05d7 \u05e9\u05d1\u05e8\u05e6\u05d5\u05e0\u05da \u05dc\u05d4\u05ea\u05e0\u05ea\u05e7?',
      confirmText: '\u05d4\u05ea\u05e0\u05ea\u05e7',
      cancelText: '\u05d1\u05d9\u05d8\u05d5\u05dc',
      isDestructive: true,
    );

    if (confirm == true && context.mounted) {
      await context.read<AuthProvider>().signOut();
    }
  }

  Widget _buildBottomNav(bool isAdmin) {
    return NavigationBar(
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
          label: '\u05d3\u05e9\u05d1\u05d5\u05e8\u05d3',
        ),
        const NavigationDestination(
          icon: Icon(Icons.message_outlined),
          selectedIcon: Icon(Icons.message_rounded),
          label: '\u05d1\u05e0\u05d9\u05d9\u05ea \u05d4\u05d5\u05d3\u05e2\u05d4',
        ),
        const NavigationDestination(
          icon: Icon(Icons.fitness_center_outlined),
          selectedIcon: Icon(Icons.fitness_center_rounded),
          label: '\u05ea\u05e8\u05d2\u05d9\u05dc\u05d9\u05dd',
        ),
        const NavigationDestination(
          icon: Icon(Icons.people_outline_rounded),
          selectedIcon: Icon(Icons.people_rounded),
          label: '\u05e0\u05d5\u05db\u05d7\u05d5\u05ea',
        ),
        if (isAdmin)
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: '\u05e0\u05d9\u05d4\u05d5\u05dc',
          ),
      ],
    );
  }
}
