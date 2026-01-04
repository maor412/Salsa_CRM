import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'services/notification_service.dart';
import 'services/birthday_notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // אתחול Firebase
  // שים לב: צריך להריץ 'flutterfire configure' ליצירת firebase_options.dart
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print('Firebase initialization error: $e');
    print('הרץ את הפקודה: flutterfire configure');
  }

  // אתחול שירות התראות
  await NotificationService().initialize();
  await NotificationService().scheduleWeeklyMessageReminders();

  // בדיקת ימי הולדת ושליחת התראות
  await BirthdayNotificationService().scheduleTodayBirthdayNotifications();

  runApp(const SalsaCRMApp());
}

class SalsaCRMApp extends StatelessWidget {
  const SalsaCRMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ],
      child: MaterialApp(
          title: 'Salsa CRM',
          debugShowCheckedModeBanner: false,

          // תמיכה ב-RTL ועברית - זה החלק הקריטי:
          locale: const Locale('he', 'IL'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('he', 'IL'),
          ],

        // עיצוב
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.light,
          ),
          fontFamily: 'Rubik', // ניתן להוסיף פונט עברי

          // תמיכה ב-RTL
          textTheme: const TextTheme(
            bodyLarge: TextStyle(fontSize: 16),
            bodyMedium: TextStyle(fontSize: 14),
            titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          // AppBar
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 2,
          ),

          // Cards
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),

          // Buttons
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),

        // ניתוב עם Splash Screen
        home: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            // שלב 1: הצגת Splash Screen בזמן אתחול
            if (authProvider.isInitializing) {
              return const SplashScreen();
            }

            // שלב 2: לאחר אתחול - ניווט לפי מצב אימות
            if (authProvider.isAuthenticated) {
              return const HomeScreen();
            }
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}


