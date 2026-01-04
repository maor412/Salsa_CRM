import 'package:flutter/material.dart';
import '../widgets/salsa_logo_header.dart';

/// מסך טעינה (Splash Screen)
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // לוגו + כותרת + תת-כותרת (גרסה גדולה יותר)
            const SalsaLogoHeader(
              isCompact: false,
              showSubtitle: true,
              logoSize: 150,
              titleSize: 36,
              subtitleSize: 18,
            ),

            const SizedBox(height: 48),

            // אינדיקטור טעינה
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}
