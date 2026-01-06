import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/student_model.dart';
import '../models/attendance_model.dart';
import '../services/firestore_service.dart';
import '../providers/auth_provider.dart';
import '../config/app_theme.dart';

/// מסך רישום נוכחות
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _searchQuery = ValueNotifier<String>('');
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<Map<String, bool>> _attendanceNotifier = ValueNotifier({});

  LessonType _selectedLessonType = LessonType.regular;
  Map<String, bool> get _attendance => _attendanceNotifier.value;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    print('AttendanceScreen initState');
  }

  @override
  void dispose() {
    print('AttendanceScreen dispose');
    _searchController.dispose();
    _searchQuery.dispose();
    _scrollController.dispose();
    _attendanceNotifier.dispose();
    super.dispose();
  }

  /// הצגת תפריט אופציות לתלמיד
  Future<void> _showStudentOptions(StudentModel student) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(student.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('עריכה'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('מחיקה'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (result == 'edit') {
      _showEditStudentDialog(student);
    } else if (result == 'delete') {
      _showDeleteConfirmation(student);
    }
  }

  /// הצגת דיאלוג אישור מחיקה
  Future<void> _showDeleteConfirmation(StudentModel student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('אישור מחיקה'),
        content: Text('האם אתה בטוח שברצונך למחוק את ${student.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ביטול'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('מחק'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteStudent(student);
    }
  }

  /// מחיקת תלמיד
  Future<void> _deleteStudent(StudentModel student) async {
    try {
      await _firestoreService.deleteStudent(student.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${student.name} נמחק בהצלחה'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה במחיקת תלמיד: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// הצגת דיאלוג עריכת תלמיד
  Future<void> _showEditStudentDialog(StudentModel student) async {
    final nameController = TextEditingController(text: student.name);
    final phoneController = TextEditingController(text: student.phoneNumber);
    DateTime? selectedBirthday = student.birthday;

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('עריכת תלמיד'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    textDirection: TextDirection.rtl,
                    decoration: const InputDecoration(
                      labelText: 'שם',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'נא להזין שם';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    textDirection: TextDirection.ltr,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'טלפון',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('תאריך לידה'),
                    subtitle: Text(
                      selectedBirthday != null
                          ? '${selectedBirthday!.day}/${selectedBirthday!.month}/${selectedBirthday!.year}'
                          : 'לא נבחר',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedBirthday ?? DateTime.now(),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => selectedBirthday = date);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ביטול'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('שמור'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await _updateStudent(
        student,
        nameController.text.trim(),
        phoneController.text.trim(),
        selectedBirthday,
      );
    }

    nameController.dispose();
    phoneController.dispose();
  }

  /// עדכון תלמיד
  Future<void> _updateStudent(
    StudentModel student,
    String newName,
    String newPhone,
    DateTime? newBirthday,
  ) async {
    try {
      final updatedStudent = student.copyWith(
        name: newName,
        phoneNumber: newPhone,
        birthday: newBirthday,
      );

      await _firestoreService.updateStudent(updatedStudent);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('התלמיד עודכן בהצלחה'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בעדכון תלמיד: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// שמירת נוכחות
  Future<void> _saveAttendance(List<StudentModel> students) async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) return;

    // בדיקה שיש לפחות סימון אחד
    if (_attendance.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('יש לסמן לפחות תלמיד אחד'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // יצירת מפגש נוכחות
      final session = AttendanceSession(
        id: '',
        date: DateTime.now(),
        lessonType: _selectedLessonType,
        instructorId: user.id,
        instructorName: user.name,
        createdAt: DateTime.now(),
      );

      final sessionId = await _firestoreService.createAttendanceSession(session);

      // יצירת רשומות נוכחות
      final records = students.map((student) {
        final attended = _attendance[student.id] ?? false;
        return AttendanceRecord(
          id: '',
          sessionId: sessionId,
          studentId: student.id,
          studentName: student.name,
          attended: attended,
          createdAt: DateTime.now(),
        );
      }).toList();

      await _firestoreService.saveAttendanceRecords(records);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('הנוכחות נשמרה בהצלחה'),
            backgroundColor: AppColors.success,
          ),
        );

        // איפוס הטופס
        _attendanceNotifier.value = {};
        setState(() {
          _selectedLessonType = LessonType.regular;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בשמירת נוכחות: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      body: StreamBuilder<List<StudentModel>>(
        stream: _firestoreService.getActiveStudents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('שגיאה: ${snapshot.error}'));
          }

          final allStudents = snapshot.data ?? [];

          return Column(
            children: [
              // Scrollable content area
              Expanded(
                child: SingleChildScrollView(
                  key: const PageStorageKey<String>('attendanceScrollView'),
                  controller: _scrollController,
                  padding: const EdgeInsets.only(
                    bottom: 180,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.lg),

                      // Lesson type chips
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'סוג שיעור',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _LessonTypeChips(
                              selectedLessonType: _selectedLessonType,
                              onLessonTypeChanged: (type) {
                                setState(() => _selectedLessonType = type);
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // Search bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: _SearchBar(
                          controller: _searchController,
                          searchQuery: _searchQuery,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // Students list
                      ValueListenableBuilder<String>(
                        valueListenable: _searchQuery,
                        builder: (context, searchValue, _) {
                          // סינון לפי חיפוש
                          final filteredStudents = allStudents.where((student) {
                            if (searchValue.isEmpty) return true;
                            return student.name.contains(searchValue);
                          }).toList();

                          return filteredStudents.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(AppSpacing.xl),
                                  child: Center(
                                    child: Text(
                                      'לא נמצאו תלמידים',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                                  itemCount: filteredStudents.length,
                                  itemBuilder: (context, index) {
                                    final student = filteredStudents[index];

                                    return ValueListenableBuilder<Map<String, bool>>(
                                      valueListenable: _attendanceNotifier,
                                      builder: (context, attendance, _) {
                                        final isPresent = attendance[student.id] ?? false;

                                        return _StudentAttendanceTile(
                                          student: student,
                                          isPresent: isPresent,
                                          onToggle: () {
                                            final newAttendance = Map<String, bool>.from(_attendanceNotifier.value);
                                            final current = newAttendance[student.id] ?? false;
                                            if (current) {
                                              newAttendance.remove(student.id);
                                            } else {
                                              newAttendance[student.id] = true;
                                            }
                                            _attendanceNotifier.value = newAttendance;
                                          },
                                          onLongPress: () => _showStudentOptions(student),
                                        );
                                      },
                                    );
                                  },
                                );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Sticky bottom bar with KPIs and save button
              ValueListenableBuilder<Map<String, bool>>(
                valueListenable: _attendanceNotifier,
                builder: (context, attendance, _) {
                  return _StickySaveBar(
                    totalStudents: allStudents.length,
                    presentCount: attendance.length,
                    isSaving: _isSaving,
                    hasSelection: attendance.isNotEmpty,
                    onSave: () => _saveAttendance(allStudents),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// COMPONENT: Lesson Type Chips
// ============================================================================
class _LessonTypeChips extends StatelessWidget {
  final LessonType selectedLessonType;
  final ValueChanged<LessonType> onLessonTypeChanged;

  const _LessonTypeChips({
    required this.selectedLessonType,
    required this.onLessonTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: LessonType.values.map((type) {
              final isSelected = type == selectedLessonType;
              final session = AttendanceSession(
                id: '',
                date: DateTime.now(),
                lessonType: type,
                instructorId: '',
                instructorName: '',
                createdAt: DateTime.now(),
              );

              return Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: ChoiceChip(
                  label: Text(session.lessonTypeName),
                  selected: isSelected,
                  onSelected: (_) => onLessonTypeChanged(type),
                  selectedColor: AppColors.primaryLight,
                  backgroundColor: AppColors.surfaceVariant,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: isSelected ? 2 : 1,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// COMPONENT: Search Bar
// ============================================================================
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueNotifier<String> searchQuery;

  const _SearchBar({
    required this.controller,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: ValueListenableBuilder<String>(
          valueListenable: searchQuery,
          builder: (context, searchValue, _) {
            return TextField(
              controller: controller,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'חפש תלמיד...',
                hintStyle: const TextStyle(color: AppColors.textHint),
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                suffixIcon: searchValue.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          controller.clear();
                          searchQuery.value = '';
                        },
                        color: AppColors.textSecondary,
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              ),
              onChanged: (value) {
                searchQuery.value = value;
              },
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// COMPONENT: Student Attendance Tile
// ============================================================================
class _StudentAttendanceTile extends StatelessWidget {
  final StudentModel student;
  final bool isPresent;
  final VoidCallback onToggle;
  final VoidCallback onLongPress;

  const _StudentAttendanceTile({
    required this.student,
    required this.isPresent,
    required this.onToggle,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      color: isPresent ? AppColors.accent : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPresent ? AppColors.primary : AppColors.border,
          width: isPresent ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        leading: CircleAvatar(
          backgroundColor: isPresent ? AppColors.primary : AppColors.surfaceVariant,
          child: Text(
            student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
            style: TextStyle(
              color: isPresent ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          student.name,
          style: TextStyle(
            fontWeight: isPresent ? FontWeight.bold : FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: student.phoneNumber.isNotEmpty
            ? Text(
                student.phoneNumber,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              )
            : null,
        trailing: Checkbox(
          value: isPresent,
          onChanged: (_) => onToggle(),
          activeColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        onTap: onToggle,
        onLongPress: onLongPress,
      ),
    );
  }
}

// ============================================================================
// COMPONENT: Sticky Save Bar
// ============================================================================
class _StickySaveBar extends StatelessWidget {
  final int totalStudents;
  final int presentCount;
  final bool isSaving;
  final bool hasSelection;
  final VoidCallback onSave;

  const _StickySaveBar({
    required this.totalStudents,
    required this.presentCount,
    required this.isSaving,
    required this.hasSelection,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = totalStudents > 0
        ? (presentCount / totalStudents * 100).toStringAsFixed(0)
        : '0';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: AppSpacing.lg + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // KPI Row
              _AttendanceKpiRow(
                totalStudents: totalStudents,
                presentCount: presentCount,
                percentage: percentage,
              ),

              const SizedBox(height: AppSpacing.lg),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (isSaving || !hasSelection) ? null : onSave,
                  icon: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save, size: 20),
                  label: Text(
                    isSaving ? 'שומר...' : 'סיום ושמירה',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    elevation: 2,
                    disabledBackgroundColor: AppColors.surfaceVariant,
                    disabledForegroundColor: AppColors.textHint,
                  ),
                ),
              ),

              // Helper text when no selection
              if (!hasSelection)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    'סמן לפחות תלמיד אחד כדי לשמור',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
    );
  }
}

// ============================================================================
// COMPONENT: Attendance KPI Row
// ============================================================================
class _AttendanceKpiRow extends StatelessWidget {
  final int totalStudents;
  final int presentCount;
  final String percentage;

  const _AttendanceKpiRow({
    required this.totalStudents,
    required this.presentCount,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildKpiCard(
            label: 'אחוז נוכחות',
            value: '$percentage%',
            icon: Icons.pie_chart,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _buildKpiCard(
            label: 'נוכחים',
            value: '$presentCount',
            icon: Icons.check_circle,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _buildKpiCard(
            label: 'סה"כ',
            value: '$totalStudents',
            icon: Icons.people,
            color: AppColors.info,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
