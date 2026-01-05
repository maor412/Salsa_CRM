import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// כרטיס בסיסי של האפליקציה
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final VoidCallback? onTap;
  final bool hasBorder;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.onTap,
    this.hasBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: AppRadius.mediumRadius,
        border: hasBorder
            ? Border.all(
                color: AppColors.border.withOpacity(0.5),
                width: 1,
              )
            : null,
        boxShadow: AppShadows.small,
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
        child: child,
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.mediumRadius,
          child: card,
        ),
      );
    }

    return card;
  }
}

/// כרטיס מידע (Info Card) עם אייקון וכותרת
class AppInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final Color? backgroundColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const AppInfoCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.backgroundColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: backgroundColor,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: (iconColor ?? AppColors.primary).withOpacity(0.1),
              borderRadius: AppRadius.smallRadius,
            ),
            child: Icon(
              icon,
              color: iconColor ?? AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// כרטיס סטטיסטיקה (Stat Card)
class AppStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData? icon;
  final Color color;
  final Widget? chart;
  final VoidCallback? onTap;

  const AppStatCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    required this.color,
    this.chart,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: color, size: 24),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (chart != null) ...[
            SizedBox(
              height: 100,
              child: chart!,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// כרטיס התראה (Alert Card)
class AppAlertCard extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;
  final VoidCallback? onDismiss;

  const AppAlertCard({
    super.key,
    required this.message,
    this.icon = Icons.info_outline,
    this.color = AppColors.info,
    this.onDismiss,
  });

  const AppAlertCard.warning({
    super.key,
    required this.message,
    this.onDismiss,
  })  : icon = Icons.warning_amber_rounded,
        color = AppColors.warning;

  const AppAlertCard.error({
    super.key,
    required this.message,
    this.onDismiss,
  })  : icon = Icons.error_outline,
        color = AppColors.error;

  const AppAlertCard.success({
    super.key,
    required this.message,
    this.onDismiss,
  })  : icon = Icons.check_circle_outline,
        color = AppColors.success;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: _getBackgroundColor(),
      hasBorder: false,
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              icon: Icon(Icons.close, size: 20, color: color),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }

  Color _getBackgroundColor() {
    if (color == AppColors.warning) return AppColors.warningLight;
    if (color == AppColors.error) return AppColors.errorLight;
    if (color == AppColors.success) return AppColors.successLight;
    return AppColors.infoLight;
  }
}
