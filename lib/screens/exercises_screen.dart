import 'package:flutter/material.dart';
import '../models/exercise_model.dart';
import '../services/firestore_service.dart';
import '../config/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_empty_state.dart';

/// מסך ניהול תרגילים - מעוצב
class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _firestoreService.initializeDefaultExercises();
  }

  Future<void> _toggleExercise(ExerciseModel exercise) async {
    await _firestoreService.updateExerciseStatus(
      exercise.id,
      !exercise.isCompleted,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ExerciseModel>>(
      stream: _firestoreService.getExercises(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingState(message: 'טוען תרגילים...');
        }

        if (snapshot.hasError) {
          return AppErrorState(
            message: 'שגיאה בטעינת תרגילים: ${snapshot.error}',
            onRetry: () => setState(() {}),
          );
        }

        final exercises = snapshot.data ?? [];

        if (exercises.isEmpty) {
          return const AppEmptyState(
            icon: Icons.fitness_center_rounded,
            title: 'אין תרגילים זמינים',
            subtitle: 'התרגילים יתווספו אוטומטית',
          );
        }

        final nextIncompleteIndex = exercises.indexWhere((e) => !e.isCompleted);
        const nextExercisesCount = 3;

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // כרטיס התרגילים לשיעור הבא
            _buildNextLessonCard(exercises, nextIncompleteIndex, nextExercisesCount),

            const SizedBox(height: AppSpacing.lg),

            // רשימה מלאה של תרגילים
            AppCard(
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
                          Icons.list_alt_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      const Text(
                        'כל התרגילים',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      _buildProgressIndicator(exercises),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ...exercises.asMap().entries.map((entry) {
                    final index = entry.key;
                    final exercise = entry.value;
                    return _buildExerciseItem(exercise, index);
                  }),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNextLessonCard(
    List<ExerciseModel> exercises,
    int nextIndex,
    int count,
  ) {
    final allCompletedExercises = exercises
        .where((e) => e.isCompleted && e.completedAt != null)
        .toList();

    List<ExerciseModel> completedExercises = [];

    if (allCompletedExercises.isNotEmpty) {
      final latestDate = allCompletedExercises
          .map((e) => e.completedAt!)
          .reduce((a, b) => a.isAfter(b) ? a : b);

      completedExercises = allCompletedExercises.where((e) {
        final exerciseDate = e.completedAt!;
        return exerciseDate.year == latestDate.year &&
               exerciseDate.month == latestDate.month &&
               exerciseDate.day == latestDate.day;
      }).toList();

      completedExercises.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    }

    final upcomingExercises = exercises
        .where((e) => !e.isCompleted)
        .take(count)
        .toList();

    return AppCard(
      color: AppColors.infoLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.2),
                  borderRadius: AppRadius.smallRadius,
                ),
                child: const Icon(
                  Icons.upcoming_rounded,
                  color: AppColors.info,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Text(
                'התרגילים לשיעור הבא',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          if (completedExercises.isNotEmpty) ...[
            const Text(
              'חזרה:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            ...completedExercises.map((exercise) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.replay_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          exercise.name,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: AppSpacing.md),
          ],

          const Text(
            'חדש:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ...upcomingExercises.map((exercise) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    const Icon(
                      Icons.fiber_new_rounded,
                      size: 16,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        exercise.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildExerciseItem(ExerciseModel exercise, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleExercise(exercise),
          borderRadius: AppRadius.mediumRadius,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: exercise.isCompleted
                  ? AppColors.successLight
                  : AppColors.surfaceVariant,
              borderRadius: AppRadius.mediumRadius,
              border: Border.all(
                color: exercise.isCompleted
                    ? AppColors.success
                    : AppColors.border,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: exercise.isCompleted
                        ? AppColors.success
                        : AppColors.border,
                  ),
                  child: Center(
                    child: exercise.isCompleted
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 20,
                          )
                        : Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                          decoration: exercise.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        exercise.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: AppSpacing.sm),

                Checkbox(
                  value: exercise.isCompleted,
                  onChanged: (_) => _toggleExercise(exercise),
                  activeColor: AppColors.success,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(List<ExerciseModel> exercises) {
    final completed = exercises.where((e) => e.isCompleted).length;
    final total = exercises.length;
    final percentage = total > 0 ? (completed / total * 100).toStringAsFixed(0) : '0';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: AppRadius.largeRadius,
      ),
      child: Text(
        '$completed/$total ($percentage%)',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
          fontSize: 13,
        ),
      ),
    );
  }
}
