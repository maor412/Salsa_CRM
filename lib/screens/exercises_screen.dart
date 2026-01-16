import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/exercise_model.dart';
import '../services/firestore_service.dart';
import '../config/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/shines_flow_dialog.dart';

/// מסך ניהול תרגילים - מעוצב
class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final ScrollController _scrollController = ScrollController();

  bool _isFabVisible = true;
  bool _isScrolling = false;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;
  late Animation<double> _fabOpacityAnimation;

  // מצב פתוח/סגור של כל רמה
  final Map<String, bool> _expandedLevels = {
    'רמת בסיס': false,
    'רמה 1': false,
    'רמה 2': false,
    'רמה 3': false,
    'רמה 4': false,
    'רמה 5': false,
  };

  @override
  void initState() {
    super.initState();
    _firestoreService.initializeDefaultExercises();

    // ============================================================
    // 🔄 עדכון DB - איתחול מחדש של כל 92 התרגילים החדשים! 🔄
    // ⚠️ פונקציה זו תמחק את כל התרגילים הישנים ותוסיף את החדשים
    // ⚠️ השורה הבאה מושבתת - הסר את ההערה רק אם אתה רוצה לאפס מחדש!
    // ============================================================
    // _resetExercisesOnce();

    // אתחול אנימציית FAB
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _fabScaleAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );

    _fabOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    // זיהוי תחילת גלילה
    if (notification is ScrollStartNotification) {
      _isScrolling = true;
    }

    // זיהוי עדכון גלילה - בדיקת כיוון
    if (notification is ScrollUpdateNotification) {
      if (notification.scrollDelta != null) {
        if (notification.scrollDelta! > 0) {
          // גלילה למטה - הסתר FAB
          if (_isFabVisible) {
            _isFabVisible = false;
            _fabAnimationController.forward();
          }
        } else if (notification.scrollDelta! < 0) {
          // גלילה למעלה - הצג FAB
          if (!_isFabVisible) {
            _isFabVisible = true;
            _fabAnimationController.reverse();
          }
        }
      }
    }

    // זיהוי סיום גלילה - החזר את ה-FAB
    if (notification is ScrollEndNotification) {
      _isScrolling = false;
      if (!_isFabVisible) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!_isScrolling && mounted) {
            _isFabVisible = true;
            _fabAnimationController.reverse();
          }
        });
      }
    }

    return false;
  }

  Future<void> _toggleExercise(ExerciseModel exercise) async {
    await _firestoreService.updateExerciseStatus(
      exercise.id,
      !exercise.isCompleted,
    );
  }

  // ============================================================
  // 🔄 פונקציית עדכון DB - מחיקה והכנסת 92 תרגילים חדשים! 🔄
  // ============================================================
  // פונקציה זו מבצעת:
  // 1. מחיקת כל התרגילים הקיימים ב-Firestore
  // 2. הכנסת 92 התרגילים החדשים (רמת בסיס עד רמה 5)
  // 3. איפוס כל המצב (isCompleted = false)
  //
  // ⚠️ השתמש בזה פעם אחת בלבד!
  // ⚠️ אחרי הריצה הראשונה - הסר/הערה את הקריאה לפונקציה ב-initState (שורה 49)
  // ============================================================
  Future<void> _resetExercisesOnce() async {
    try {
      await _firestoreService.resetExercises();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('התרגילים אותחלו מחדש בהצלחה!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      print('Error resetting exercises: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה באיתחול תרגילים: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _openShinesDialog() {
    ShinesFlowDialog.show(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<List<ExerciseModel>>(
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

        return NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: ListView(
            key: const PageStorageKey<String>('exercises_list'),
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxxl + AppSpacing.xl, // padding תחתון גדול למניעת דחיסה
            ),
            children: [
              // בלוק התקדמות כללית
              _buildProgressCard(exercises),

              const SizedBox(height: AppSpacing.lg),

              // כרטיס התרגילים לשיעור הבא
              _buildNextLessonCard(exercises, nextIncompleteIndex, nextExercisesCount),

              const SizedBox(height: AppSpacing.lg),

              // רשימה מלאה של תרגילים
              _buildAllExercisesCard(exercises),
            ],
          ),
        );
      },
    ),
      floatingActionButton: ScaleTransition(
        scale: _fabScaleAnimation,
        child: FadeTransition(
          opacity: _fabOpacityAnimation,
          child: IgnorePointer(
            ignoring: !_isFabVisible,
            child: FloatingActionButton.extended(
              onPressed: _openShinesDialog,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              heroTag: 'shinesFab',
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text(
                'שיינס',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // בלוק התקדמות כללית עם LinearProgressIndicator
  Widget _buildProgressCard(List<ExerciseModel> exercises) {
    final completed = exercises.where((e) => e.isCompleted).length;
    final total = exercises.length;
    final percentage = total > 0 ? (completed / total) : 0.0;
    final percentageText = (percentage * 100).toStringAsFixed(0);

    return AppCard(
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
                  Icons.trending_up_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Text(
                  'ההתקדמות שלי',
                  style: TextStyle(
                    fontSize: 18,
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
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: AppRadius.largeRadius,
                ),
                child: Text(
                  '$completed/$total',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    fontSize: 16,
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
                    value: percentage,
                    minHeight: 10,
                    backgroundColor: AppColors.accent,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '$percentageText%',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
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
      color: AppColors.accent, // שינוי מתכלת לסגול בהיר
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: AppRadius.smallRadius,
                ),
                child: const Icon(
                  Icons.upcoming_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Text(
                  'התרגילים לשיעור הבא',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Chips במקום טקסטים
          if (completedExercises.isNotEmpty) ...[
            Chip(
              avatar: const Icon(
                Icons.replay_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
              label: const Text('חזרה'),
              backgroundColor: AppColors.surfaceVariant,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...completedExercises.map((exercise) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs, right: AppSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.textSecondary,
                        ),
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

          Chip(
            avatar: const Icon(
              Icons.fiber_new_rounded,
              size: 16,
              color: AppColors.primary,
            ),
            label: const Text('חדש'),
            backgroundColor: AppColors.primary.withOpacity(0.15),
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...upcomingExercises.map((exercise) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs, right: AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withOpacity(0.7),
                      ),
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

  Widget _buildAllExercisesCard(List<ExerciseModel> exercises) {
    // קיבוץ תרגילים לפי רמות
    final Map<String, List<ExerciseModel>> exercisesByLevel = {
      'רמת בסיס': [],
      'רמה 1': [],
      'רמה 2': [],
      'רמה 3': [],
      'רמה 4': [],
      'רמה 5': [],
    };

    for (var exercise in exercises) {
      if (exercisesByLevel.containsKey(exercise.level)) {
        exercisesByLevel[exercise.level]!.add(exercise);
      }
    }

    return AppCard(
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
              const Expanded(
                child: Text(
                  'כל התרגילים',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // תפריטים נפתחים לפי רמות
          ...exercisesByLevel.entries.map((entry) {
            final level = entry.key;
            final levelExercises = entry.value;

            if (levelExercises.isEmpty) return const SizedBox.shrink();

            return _buildLevelSection(level, levelExercises, exercises);
          }),
        ],
      ),
    );
  }

  Widget _buildLevelSection(String level, List<ExerciseModel> levelExercises, List<ExerciseModel> allExercises) {
    final completed = levelExercises.where((e) => e.isCompleted).length;
    final total = levelExercises.length;

    return StatefulBuilder(
      builder: (context, setLocalState) {
        final isExpanded = _expandedLevels[level] ?? false;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setLocalState(() {
                  _expandedLevels[level] = !isExpanded;
                });
              },
              borderRadius: AppRadius.mediumRadius,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: isExpanded ? AppColors.accent : AppColors.surface,
                  borderRadius: AppRadius.mediumRadius,
                  border: Border.all(
                    color: isExpanded ? AppColors.primary.withOpacity(0.3) : AppColors.border,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // כותרת הרמה
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withOpacity(0.1),
                          ),
                          child: Center(
                            child: Text(
                              level == 'רמת בסיס' ? 'B' : level.split(' ')[1],
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
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
                                level,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$completed מתוך $total הושלמו',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ],
                    ),

                    // רשימת התרגילים (כשמורחב)
                    if (isExpanded) ...[
                      const SizedBox(height: AppSpacing.md),
                      const Divider(height: 1),
                      const SizedBox(height: AppSpacing.md),
                      ...levelExercises.map((exercise) {
                        final globalIndex = allExercises.indexOf(exercise);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _buildExerciseItem(exercise, globalIndex),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.mediumRadius,
              border: Border.all(
                color: AppColors.border,
                width: 1,
              ),
              // פס צד ירוק רק למשימות שהושלמו
              boxShadow: exercise.isCompleted
                  ? [
                      const BoxShadow(
                        color: AppColors.success,
                        offset: Offset(-4, 0),
                        blurRadius: 0,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // אייקון מצב יחיד (הסרת כפילות)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: exercise.isCompleted
                        ? AppColors.success
                        : AppColors.surfaceVariant,
                    border: Border.all(
                      color: exercise.isCompleted
                          ? AppColors.success
                          : AppColors.border,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: exercise.isCompleted
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 22,
                          )
                        : Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: exercise.isCompleted
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                          decoration: exercise.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        exercise.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary.withOpacity(0.8),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                // כפתור יוטיוב אם יש קישור
                if (exercise.videoUrl != null && exercise.videoUrl!.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.md),
                  IconButton(
                    onPressed: () => _openVideo(exercise.videoUrl!),
                    icon: SvgPicture.asset(
                      'assets/icon/youtube_icon.svg',
                      width: 32,
                      height: 32,
                    ),
                    tooltip: 'צפה בסרטון',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openVideo(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'לא ניתן לפתוח את הסרטון';
      }
    } catch (e) {
      print('שגיאה בפתיחת הסרטון: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('לא ניתן לפתוח את הסרטון: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
