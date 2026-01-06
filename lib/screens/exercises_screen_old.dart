import 'package:flutter/material.dart';
import '../models/exercise_model.dart';
import '../services/firestore_service.dart';

/// מסך ניהול תרגילים
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
    // אתחול תרגילים אם אין
    _firestoreService.initializeDefaultExercises();
  }

  /// עדכון סטטוס תרגיל
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
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('שגיאה: ${snapshot.error}'),
          );
        }

        final exercises = snapshot.data ?? [];

        if (exercises.isEmpty) {
          return const Center(
            child: Text('אין תרגילים זמינים'),
          );
        }

        // חישוב אינדקס של התרגיל הבא שלא הושלם
        final nextIncompleteIndex = exercises.indexWhere((e) => !e.isCompleted);
        final nextExercisesCount = 3;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // חלון עליון - התרגילים לשיעור הבא
            _buildNextLessonCard(exercises, nextIncompleteIndex, nextExercisesCount),

            const SizedBox(height: 16),

            // רשימה מלאה של תרגילים
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.list_alt, color: Colors.deepPurple),
                        const SizedBox(width: 8),
                        const Text(
                          'כל התרגילים',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        _buildProgressIndicator(exercises),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...exercises.asMap().entries.map((entry) {
                      final index = entry.key;
                      final exercise = entry.value;
                      return _buildExerciseItem(exercise, index);
                    }),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// בניית כרטיס התרגילים לשיעור הבא
  Widget _buildNextLessonCard(
    List<ExerciseModel> exercises,
    int nextIndex,
    int count,
  ) {
    // מציאת כל התרגילים המושלמים
    final allCompletedExercises = exercises
        .where((e) => e.isCompleted && e.completedAt != null)
        .toList();

    // אם אין תרגילים מושלמים, לא נציג חזרה
    List<ExerciseModel> completedExercises = [];

    if (allCompletedExercises.isNotEmpty) {
      // מציאת התאריך האחרון שסומנו בו תרגילים
      final latestDate = allCompletedExercises
          .map((e) => e.completedAt!)
          .reduce((a, b) => a.isAfter(b) ? a : b);

      // סינון כל התרגילים שסומנו באותו יום (התעלמות מהשעה)
      completedExercises = allCompletedExercises.where((e) {
        final exerciseDate = e.completedAt!;
        return exerciseDate.year == latestDate.year &&
               exerciseDate.month == latestDate.month &&
               exerciseDate.day == latestDate.day;
      }).toList();

      // מיון לפי סדר המקורי (orderIndex)
      completedExercises.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    }

    final upcomingExercises = exercises
        .where((e) => !e.isCompleted)
        .take(count)
        .toList();

    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.upcoming, color: Colors.blue[800]),
                const SizedBox(width: 8),
                Text(
                  'התרגילים לשיעור הבא',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // חזרה על תרגילים קודמים
            if (completedExercises.isNotEmpty) ...[
              const Text(
                'חזרה:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              ...completedExercises.map((exercise) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.replay, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(child: Text(exercise.name)),
                      ],
                    ),
                  )),
              const SizedBox(height: 8),
            ],

            // תרגילים חדשים
            const Text(
              'חדש:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            ...upcomingExercises.map((exercise) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.fiber_new, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          exercise.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  /// בניית פריט תרגיל
  Widget _buildExerciseItem(ExerciseModel exercise, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _toggleExercise(exercise),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: exercise.isCompleted ? Colors.green[50] : Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: exercise.isCompleted ? Colors.green : Colors.grey[300]!,
            ),
          ),
          child: Row(
            children: [
              // מספר סידורי
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: exercise.isCompleted ? Colors.green : Colors.grey[300],
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: exercise.isCompleted ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // פרטי התרגיל
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: exercise.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      exercise.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // Checkbox
              Checkbox(
                value: exercise.isCompleted,
                onChanged: (_) => _toggleExercise(exercise),
                activeColor: Colors.green,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// אינדיקטור התקדמות
  Widget _buildProgressIndicator(List<ExerciseModel> exercises) {
    final completed = exercises.where((e) => e.isCompleted).length;
    final total = exercises.length;
    final percentage = total > 0 ? (completed / total * 100).toStringAsFixed(0) : '0';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.deepPurple[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$completed/$total ($percentage%)',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple[800],
        ),
      ),
    );
  }
}
