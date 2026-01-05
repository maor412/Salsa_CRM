import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Widget לחיבור בין בועות שיינס (חץ אנכי)
class ShinesConnector extends StatelessWidget {
  const ShinesConnector({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 2,
          height: 20,
          color: AppColors.primary.withOpacity(0.3),
        ),
        Icon(
          Icons.arrow_downward_rounded,
          color: AppColors.primary,
          size: 24,
        ),
        Container(
          width: 2,
          height: 20,
          color: AppColors.primary.withOpacity(0.3),
        ),
      ],
    );
  }
}
