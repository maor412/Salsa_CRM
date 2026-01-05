import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
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
              // התראות
              if (data.alerts.isNotEmpty) ...[
                ...data.alerts.map((alert) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppAlertCard.warning(message: alert),
                )),
                const SizedBox(height: AppSpacing.lg),
              ],

              // כרטיסי סטטיסטיקה
              AppStatCard(
                title: 'אחוז נוכחות בשיעור האחרון',
                value: '${data.lastSessionAttendanceRate.toStringAsFixed(0)}%',
                icon: Icons.people_rounded,
                chart: _buildPieChart(data.lastSessionAttendanceRate),
                color: AppColors.info,
              ),
              const SizedBox(height: AppSpacing.lg),

              AppStatCard(
                title: 'התקדמות תרגילים',
                value: '${data.exercisesProgress.toStringAsFixed(0)}%',
                icon: Icons.fitness_center_rounded,
                chart: _buildLinearProgress(data.exercisesProgress),
                color: AppColors.success,
              ),
              const SizedBox(height: AppSpacing.lg),

              GestureDetector(
                onTap: () => _showAbsenteesSheet(context),
                child: AppStatCard(
                  title: 'תלמידים עם 3 היעדרויות ברצף',
                  value: '${data.studentsWithThreeAbsences}',
                  icon: Icons.person_off_rounded,
                  chart: _buildNumberDisplay(data.studentsWithThreeAbsences),
                  color: data.studentsWithThreeAbsences > 0
                      ? AppColors.error
                      : AppColors.success,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ימי הולדת
              if (data.birthdayStudents.isNotEmpty) ...[
                _buildBirthdaySection(data.birthdayStudents),
              ],
            ],
          ),
        );
      },
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
                        color: AppColors.error.withOpacity(0.1),
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
                            backgroundColor: AppColors.error.withOpacity(0.1),
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
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.errorLight,
                              borderRadius: AppRadius.largeRadius,
                            ),
                            child: Text(
                              '${item.consecutiveAbsences}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.error,
                              ),
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

  Widget _buildPieChart(double percentage) {
    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            value: percentage,
            color: AppColors.info,
            title: '${percentage.toStringAsFixed(0)}%',
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            value: 100 - percentage,
            color: AppColors.border,
            title: '',
            radius: 50,
          ),
        ],
        sectionsSpace: 2,
        centerSpaceRadius: 0,
      ),
    );
  }

  Widget _buildLinearProgress(double percentage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: AppRadius.largeRadius,
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 16,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${percentage.toStringAsFixed(0)}% הושלמו',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberDisplay(int number) {
    return Center(
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: number > 0
              ? AppColors.errorLight
              : AppColors.successLight,
        ),
        child: Center(
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: number > 0 ? AppColors.error : AppColors.success,
            ),
          ),
        ),
      ),
    );
  }

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
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: AppRadius.smallRadius,
                ),
                child: const Icon(
                  Icons.cake_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Text(
                'ימי הולדת השבוע',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...students.map((student) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    const Icon(
                      Icons.celebration_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      student.name,
                      style: const TextStyle(
                        fontSize: 15,
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
}
