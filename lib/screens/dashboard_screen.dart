import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/dashboard_provider.dart';
import '../config/app_theme.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_dialog.dart';

class _DashboardPanel extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  const _DashboardPanel({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.largeRadius,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: AppRadius.mediumRadius,
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const AppLoadingState(message: 'טוען נתוני דשבורד...');
        }

        final data = provider.data;

        return RefreshIndicator(
          onRefresh: provider.refresh,
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              if (data.alerts.isNotEmpty) ...[
                _buildCompactAlerts(data.alerts),
                const SizedBox(height: AppSpacing.md),
              ],
              _buildKPIRow(data),
              const SizedBox(height: AppSpacing.md),
              _buildAttendanceCard(data),
              const SizedBox(height: AppSpacing.md),
              _buildExercisesProgressCard(data),
              if (data.birthdayStudents.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _buildBirthdaySection(data.birthdayStudents),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactAlerts(List<String> alerts) {
    final message = alerts.length == 1
        ? alerts.first
        : '${alerts.length} התראות דורשות תשומת לב';

    return InkWell(
      onTap: alerts.length > 1 ? () => _showAlertsSheet(context, alerts) : null,
      borderRadius: AppRadius.mediumRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.warningLight,
          borderRadius: AppRadius.mediumRadius,
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: AppRadius.smallRadius,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warning,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (alerts.length > 1)
              const Icon(
                Icons.chevron_left_rounded,
                color: AppColors.warning,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildKPIRow(data) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.largeRadius,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
        boxShadow: AppShadows.small,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildMiniKPICard(
              title: 'נוכחות',
              value: '${data.lastSessionAttendanceRate.toStringAsFixed(0)}%',
              icon: Icons.people_rounded,
              color: AppColors.primary,
            ),
          ),
          _buildKPIDivider(),
          Expanded(
            child: _buildMiniKPICard(
              title: 'תרגילים',
              value: '${data.exercisesProgress.toStringAsFixed(0)}%',
              icon: Icons.fitness_center_rounded,
              color: AppColors.success,
            ),
          ),
          _buildKPIDivider(),
          Expanded(
            child: InkWell(
              onTap: () => _showAbsenteesSheet(context),
              borderRadius: AppRadius.mediumRadius,
              child: _buildMiniKPICard(
                title: 'מחסירים',
                value: '${data.studentsWithThreeAbsences}',
                icon: Icons.person_off_rounded,
                color: data.studentsWithThreeAbsences > 0
                    ? AppColors.error
                    : AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIDivider() {
    return Container(
      width: 1,
      height: 54,
      color: AppColors.divider,
    );
  }

  Widget _buildMiniKPICard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(data) {
    final percentage = data.lastSessionAttendanceRate;
    final presentText = '${percentage.toStringAsFixed(0)}%';

    return _DashboardPanel(
      icon: Icons.people_rounded,
      iconColor: AppColors.primary,
      title: 'נוכחות בשיעור האחרון',
      child: Row(
        children: [
          SizedBox(
            width: 116,
            height: 116,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _buildDonutChart(percentage),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      presentText,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'הגיעו',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusLine(
                  color: AppColors.primary,
                  label: 'נוכחות כללית',
                  value: presentText,
                ),
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: AppRadius.roundRadius,
                  child: LinearProgressIndicator(
                    value: (percentage / 100).clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: AppColors.accent,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'מדד מהשיעור האחרון שנשמר',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusLine({
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDonutChart(double percentage) {
    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            value: percentage.clamp(0, 100),
            color: AppColors.primary,
            title: '',
            radius: 16,
          ),
          PieChartSectionData(
            value: (100 - percentage).clamp(0, 100),
            color: AppColors.accent,
            title: '',
            radius: 16,
          ),
        ],
        sectionsSpace: 2,
        centerSpaceRadius: 38,
      ),
    );
  }

  Widget _buildExercisesProgressCard(data) {
    final completed = data.exercisesProgress.round();
    final progress = (data.exercisesProgress / 100).clamp(0.0, 1.0);

    return _DashboardPanel(
      icon: Icons.fitness_center_rounded,
      iconColor: AppColors.success,
      title: 'התקדמות תרגילים',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${data.exercisesProgress.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.success,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: AppRadius.roundRadius,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: AppColors.successLight,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.success),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text(
                'הושלמו $completed מתוך 100 תרגילים',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (data.currentExerciseLevel.isNotEmpty) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: AppRadius.roundRadius,
                  ),
                  child: Text(
                    data.currentExerciseLevel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBirthdaySection(List students) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: AppRadius.largeRadius,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: AppRadius.mediumRadius,
            ),
            child: const Icon(
              Icons.cake_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ימי הולדת השבוע',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: students
                      .map(
                        (student) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.7),
                            borderRadius: AppRadius.roundRadius,
                          ),
                          child: Text(
                            student.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: AppRadius.roundRadius,
            ),
            child: Text(
              '${students.length}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAlertsSheet(BuildContext context, List<String> alerts) {
    AppDialog.showAppBottomSheet(
      context: context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: AppRadius.smallRadius,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: Text(
                    'התראות',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: AppRadius.largeRadius,
                  ),
                  child: Text(
                    '${alerts.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // List
            ...alerts.asMap().entries.map((entry) {
              final index = entry.key;
              final alert = entry.value;
              return Container(
                margin: EdgeInsets.only(
                  bottom: index < alerts.length - 1 ? AppSpacing.md : 0,
                ),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: AppRadius.mediumRadius,
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        alert,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showAbsenteesSheet(BuildContext context) {
    AppDialog.showAppBottomSheet(
      context: context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Consumer<DashboardProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const SizedBox(
                height: 180,
                child: AppLoadingState(),
              );
            }

            final absentees = provider.data.studentsWithConsecutiveAbsences;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: AppRadius.smallRadius,
                      ),
                      child: const Icon(
                        Icons.person_off_rounded,
                        color: AppColors.error,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    const Expanded(
                      child: Text(
                        'רשימת מחסירים',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: AppRadius.largeRadius,
                      ),
                      child: Text(
                        '${absentees.length}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // List
                if (absentees.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(
                      child: Text(
                        'אין תלמידים עם 3 חיסורים רצופים',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: absentees.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = absentees[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.error.withValues(alpha: 0.1),
                            child: Text(
                              item.student.name.isNotEmpty
                                  ? item.student.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          title: Text(
                            item.student.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            'חיסורים רצופים: ${item.consecutiveAbsences}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: SvgPicture.asset(
                                'assets/icon/whatsapp_icon.svg',
                                width: 24,
                                height: 24,
                              ),
                            ),
                            onPressed: () =>
                                _openWhatsApp(item.student.phoneNumber),
                            tooltip: 'שליחת הודעה בווטסאפ',
                            style: IconButton.styleFrom(
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    // הסרת תווים מיוחדים ממספר הטלפון
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // וידוא שהמספר מתחיל ב-+ (נדרש לפורמט בינלאומי)
    final formattedPhone = cleanPhone.startsWith('+')
        ? cleanPhone
        : '+972${cleanPhone.replaceFirst(RegExp(r'^0'), '')}';

    final url = Uri.parse('https://wa.me/$formattedPhone');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'לא ניתן לפתוח את WhatsApp';
      }
    } catch (e) {
      print('שגיאה בפתיחת WhatsApp: $e');
    }
  }
}
