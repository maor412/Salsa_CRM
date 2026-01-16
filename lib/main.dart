import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/shines_provider.dart';
import 'services/notification_service.dart';
import 'services/birthday_notification_service.dart';
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

  // הצגת נוטיפיקציה מקומית עם ה-channel הנכון
  final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'weekly_reminders',
    'Weekly Reminders',
    channelDescription: 'Weekly message reminders from Firebase',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
  );

  const NotificationDetails details = NotificationDetails(android: androidDetails);

  await notifications.show(
    message.hashCode,
    message.notification?.title ?? '',
    message.notification?.body ?? '',
    details,
  );
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

  // אתחול שירות התראות
  await NotificationService().initialize();

  // תזמון תזכורות שבועיות (רביעי ושבת) - באמצעות Firebase Functions בלבד
  // await NotificationService().scheduleWeeklyMessageReminders(); // מבוטל - Firebase Functions שולח את ההתראות

  // אתחול שירות משימות רקע (יריץ נוטיפיקציות גם כשהאפליקציה סגורה)
  await BackgroundService.initialize();

  // בדיקת ימי הולדת ושליחת התראות (לפעם הראשונה)
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


