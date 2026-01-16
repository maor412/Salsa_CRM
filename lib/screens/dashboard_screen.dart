import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/dashboard_provider.dart';
import '../config/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_dialog.dart';

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
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              // התראות קומפקטיות למעלה
              if (data.alerts.isNotEmpty) ...[
                _buildCompactAlerts(data.alerts),
                const SizedBox(height: AppSpacing.lg),
              ],

              // שורת KPI קומפקטית (3 אריחים)
              _buildKPIRow(data),
              const SizedBox(height: AppSpacing.lg),

              // כרטיס נוכחות מפורט עם Donut Chart
              _buildAttendanceCard(data),
              const SizedBox(height: AppSpacing.lg),

              // כרטיס התקדמות תרגילים מפורט
              _buildExercisesProgressCard(data),
              const SizedBox(height: AppSpacing.lg),

              // ימי הולדת השבוע (בסוף)
              if (data.birthdayStudents.isNotEmpty) ...[
                _buildBirthdaySection(data.birthdayStudents),
              ],
            ],
          ),
        );
      },
    );
  }

  // התראות קומפקטיות
  Widget _buildCompactAlerts(List<String> alerts) {
    if (alerts.length == 1) {
      return _buildSingleAlert(alerts[0]);
    }

    // מספר התראות - כרטיס מתקפל
    return AppCard(
      color: AppColors.warningLight,
      hasBorder: false,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => _showAlertsSheet(context, alerts),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.warning,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '${alerts.length} התראות דורשות תשומת לב',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.warning,
              ),
            ),
          ),
          Icon(
            Icons.chevron_left_rounded,
            color: AppColors.warning,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildSingleAlert(String message) {
    return AppCard(
      color: AppColors.warningLight,
      hasBorder: false,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.warning,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // שורת KPI קומפקטית
  Widget _buildKPIRow(data) {
    return Row(
      children: [
        // אריח נוכחות
        Expanded(
          child: _buildMiniKPICard(
            title: 'נוכחות',
            value: '${data.lastSessionAttendanceRate.toStringAsFixed(0)}%',
            icon: Icons.people_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        // אריח התקדמות
        Expanded(
          child: _buildMiniKPICard(
            title: 'תרגילים',
            value: '${data.exercisesProgress.toStringAsFixed(0)}%',
            icon: Icons.fitness_center_rounded,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        // אריח מחסירים
        Expanded(
          child: GestureDetector(
            onTap: () => _showAbsenteesSheet(context),
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
    );
  }

  Widget _buildMiniKPICard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // כרטיס נוכחות מפורט עם Donut Chart סגול
  Widget _buildAttendanceCard(data) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.smallRadius,
                ),
                child: const Icon(
                  Icons.people_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Text(
                  'נוכחות בשיעור האחרון',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Column(
              children: [
                SizedBox(
                  height: 140,
                  child: _buildDonutChart(data.lastSessionAttendanceRate),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '${data.lastSessionAttendanceRate.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'נוכחות כללית',
                  style: TextStyle(
                    fontSize: 13,
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

  Widget _buildDonutChart(double percentage) {
    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            value: percentage,
            color: AppColors.primary,
            title: '',
            radius: 28,
          ),
          PieChartSectionData(
            value: 100 - percentage,
            color: AppColors.accent,
            title: '',
            radius: 28,
          ),
        ],
        sectionsSpace: 0,
        centerSpaceRadius: 45,
      ),
    );
  }

  // כרטיס התקדמות תרגילים מפורט
  Widget _buildExercisesProgressCard(data) {
    final completed = (data.exercisesProgress / 100 * 100).round();
    final total = 100;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: AppRadius.smallRadius,
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  color: AppColors.success,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Text(
                  'התקדמות תרגילים',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: AppRadius.largeRadius,
                  child: LinearProgressIndicator(
                    value: data.exercisesProgress / 100,
                    minHeight: 12,
                    backgroundColor: AppColors.successLight,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.success),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '${data.exercisesProgress.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                'הושלמו $completed מתוך $total תרגילים',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (data.currentExerciseLevel.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                const Text(
                  '•',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs - 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.largeRadius,
                  ),
                  child: Text(
                    data.currentExerciseLevel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
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

  // כרטיס ימי הולדת משודרג
  Widget _buildBirthdaySection(List students) {
    return AppCard(
      color: AppColors.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: AppRadius.smallRadius,
                ),
                child: const Icon(
                  Icons.cake_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Text(
                  'ימי הולדת השבוע',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: AppRadius.largeRadius,
                ),
                child: Text(
                  '${students.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...students.map((student) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      student.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              )),
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
                            backgroundColor: AppColors.error.withValues(alpha: 0.1),
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
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: SvgPicture.asset(
                                'assets/icon/whatsapp_icon.svg',
                                width: 22,
                                height: 22,
                                colorFilter: const ColorFilter.mode(
                                  Colors.white,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                            onPressed: () => _openWhatsApp(item.student.phoneNumber),
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
    final formattedPhone = cleanPhone.startsWith('+') ? cleanPhone : '+972${cleanPhone.replaceFirst(RegExp(r'^0'), '')}';

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

