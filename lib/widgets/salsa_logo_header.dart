import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// כותרת לוגו משותפת לספלאש ולוגין
class SalsaLogoHeader extends StatelessWidget {
  final bool isCompact;
  final bool showSubtitle;
  final double? logoSize;
  final double? titleSize;
  final double? subtitleSize;

  const SalsaLogoHeader({
    super.key,
    this.isCompact = false,
    this.showSubtitle = true,
    this.logoSize,
    this.titleSize,
    this.subtitleSize,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveLogoSize = logoSize ?? (isCompact ? 60.0 : 100.0);
    final effectiveTitleSize = titleSize ?? (isCompact ? 24.0 : 32.0);
    final effectiveSubtitleSize = subtitleSize ?? (isCompact ? 14.0 : 16.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // לוגו - SVG של זוג רוקד
        SvgPicture.asset(
          'assets/icon/app_icon_1024_vector.svg',
          width: effectiveLogoSize,
          height: effectiveLogoSize,
          fit: BoxFit.contain,
        ),

        SizedBox(height: isCompact ? 12 : 20),

        // כותרת "Salsa CRM"
        Text(
          'Salsa CRM',
          style: TextStyle(
            fontSize: effectiveTitleSize,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
            fontFamily: 'Rubik',
          ),
          textAlign: TextAlign.center,
        ),

        if (showSubtitle) ...[
          SizedBox(height: isCompact ? 4 : 8),

          // טקסט משנה
          Text(
            'מערכת ניהול לצוות מדריכי סלסה',
            style: TextStyle(
              fontSize: effectiveSubtitleSize,
              color: Colors.grey[600],
              fontFamily: 'Rubik',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
