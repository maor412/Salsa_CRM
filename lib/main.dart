import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:workmanager/workmanager.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/shines_provider.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'config/app_theme.dart';

// Handler לנוטיפיקציות כשהאפליקציה סגורה לגמרי
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  print('📱 Background message received: ${message.notification?.title}');
}

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

  // רישום ה-background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  unawaited(_initializeStartupServices());

  runApp(const SalsaCRMApp());
}

Future<void> _initializeStartupServices() async {
  try {
    await NotificationService().initialize();
  } catch (e) {
    print('Notification service initialization error: $e');
  }

  // ביטול אגרסיבי של כל משימות Workmanager
  // Firebase Functions מטפל בכל הנוטיפיקציות:
  // - ימי הולדת: כל יום ב-14:30 (timezone Israel)
  // - תזכורות רביעי ושבת: ב-10:00 בבוקר (timezone Israel)
  try {
    // ביטול ישיר של Workmanager ללא אתחול BackgroundService
    await Workmanager().cancelAll();
    print('✅ Workmanager tasks cancelled directly');
  } catch (e) {
    print('⚠️ Error cancelling Workmanager: $e');
    // אם נכשל, ננסה דרך BackgroundService
    try {
      await BackgroundService.cancelAll();
      print('✅ Background tasks cancelled via BackgroundService');
    } catch (e2) {
      print('⚠️ Error cancelling background tasks: $e2');
    }
  }
}

class SalsaCRMApp extends StatelessWidget {
  const SalsaCRMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) {
          final provider = ShinesProvider();
          provider.listenToShines();
          return provider;
        }),
      ],
      child: MaterialApp(
        title: 'Salsa CRM',
        debugShowCheckedModeBanner: false,

        // תמיכה ב-RTL ועברית
        locale: const Locale('he', 'IL'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('he', 'IL'),
        ],

        // Theme - שימוש ב-AppTheme המרכזי
        theme: AppTheme.lightTheme,

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
