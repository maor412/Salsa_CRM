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
  final ValueNotifier<Map<String, bool>> _attendanceNotifier =
      ValueNotifier({});

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

      final sessionId =
          await _firestoreService.createAttendanceSession(session);

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
                    bottom: AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.md),

                      // Lesson type chips
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _LessonTypeChips(
                              selectedLessonType: _selectedLessonType,
                              onLessonTypeChanged: (type) {
                                setState(() => _selectedLessonType = type);
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.md),

                      ValueListenableBuilder<Map<String, bool>>(
                        valueListenable: _attendanceNotifier,
                        builder: (context, attendance, _) {
                          return _AttendanceSummaryBar(
                            selectedCount: attendance.length,
                            totalCount: allStudents.length,
                          );
                        },
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // Search bar
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg),
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.lg),
                                  itemCount: filteredStudents.length,
                                  itemBuilder: (context, index) {
                                    final student = filteredStudents[index];

                                    return ValueListenableBuilder<
                                        Map<String, bool>>(
                                      valueListenable: _attendanceNotifier,
                                      builder: (context, attendance, _) {
                                        final isPresent =
                                            attendance[student.id] ?? false;

                                        return _StudentAttendanceTile(
                                          student: student,
                                          isPresent: isPresent,
                                          onToggle: () {
                                            final newAttendance =
                                                Map<String, bool>.from(
                                                    _attendanceNotifier.value);
                                            final current =
                                                newAttendance[student.id] ??
                                                    false;
                                            if (current) {
                                              newAttendance.remove(student.id);
                                            } else {
                                              newAttendance[student.id] = true;
                                            }
                                            _attendanceNotifier.value =
                                                newAttendance;
                                          },
                                          onLongPress: () =>
                                              _showStudentOptions(student),
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
                    isSaving: _isSaving,
                    hasSelection: attendance.isNotEmpty,
                    selectedCount: attendance.length,
                    totalCount: allStudents.length,
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.largeRadius,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        boxShadow: AppShadows.small,
      ),
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
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: ChoiceChip(
                label: Text(session.lessonTypeName),
                selected: isSelected,
                onSelected: (_) => onLessonTypeChanged(type),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surfaceVariant,
                showCheckmark: true,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 1,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _AttendanceSummaryBar extends StatelessWidget {
  final int selectedCount;
  final int totalCount;

  const _AttendanceSummaryBar({
    required this.selectedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedCount > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: hasSelection ? AppColors.accent : AppColors.surface,
          borderRadius: AppRadius.largeRadius,
          border: Border.all(
            color: hasSelection
                ? AppColors.primary.withValues(alpha: 0.18)
                : AppColors.border.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: hasSelection
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.surfaceVariant,
                borderRadius: AppRadius.smallRadius,
              ),
              child: Icon(
                hasSelection
                    ? Icons.check_circle_rounded
                    : Icons.people_outline_rounded,
                color: hasSelection ? AppColors.primary : AppColors.textHint,
                size: 21,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                hasSelection
                    ? 'סומנו $selectedCount מתוך $totalCount תלמידים'
                    : 'עדיין לא סומנה נוכחות',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: hasSelection
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ],
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.largeRadius,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: ValueListenableBuilder<String>(
        valueListenable: searchQuery,
        builder: (context, searchValue, _) {
          return TextField(
            controller: controller,
            textDirection: TextDirection.rtl,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'חפש תלמיד...',
              hintStyle: const TextStyle(color: AppColors.textHint),
              prefixIcon: const Icon(Icons.search, color: AppColors.primary),
              suffixIcon: searchValue.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () {
                        controller.clear();
                        searchQuery.value = '';
                      },
                      color: AppColors.textSecondary,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: AppSpacing.md),
            ),
            onChanged: (value) {
              searchQuery.value = value;
            },
          );
        },
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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          onLongPress: onLongPress,
          borderRadius: AppRadius.largeRadius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: isPresent ? AppColors.accent : AppColors.surface,
              borderRadius: AppRadius.largeRadius,
              border: Border.all(
                color: isPresent
                    ? AppColors.primary.withValues(alpha: 0.55)
                    : AppColors.border.withValues(alpha: 0.75),
                width: isPresent ? 1.6 : 1,
              ),
              boxShadow: AppShadows.small,
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isPresent
                        ? AppColors.primary
                        : AppColors.surfaceVariant,
                    borderRadius: AppRadius.roundRadius,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    student.name.isNotEmpty
                        ? student.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: isPresent ? Colors.white : AppColors.textSecondary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    student.name,
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.2,
                      fontWeight: isPresent ? FontWeight.w800 : FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isPresent ? AppColors.primary : AppColors.surface,
                    borderRadius: AppRadius.roundRadius,
                    border: Border.all(
                      color: isPresent
                          ? AppColors.primary
                          : AppColors.textSecondary.withValues(alpha: 0.45),
                      width: 2,
                    ),
                  ),
                  child: isPresent
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 22,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// COMPONENT: Sticky Save Bar
// ============================================================================
class _StickySaveBar extends StatelessWidget {
  final bool isSaving;
  final bool hasSelection;
  final int selectedCount;
  final int totalCount;
  final VoidCallback onSave;

  const _StickySaveBar({
    required this.isSaving,
    required this.hasSelection,
    required this.selectedCount,
    required this.totalCount,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
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
          top: AppSpacing.sm,
          bottom: AppSpacing.sm + MediaQuery.of(context).padding.bottom,
        ),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasSelection) ...[
                Text(
                  'סומנו $selectedCount מתוך $totalCount',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              ElevatedButton.icon(
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
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  elevation: hasSelection ? 2 : 0,
                  disabledBackgroundColor:
                      AppColors.surfaceVariant.withValues(alpha: 0.9),
                  disabledForegroundColor: AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// COMPONENT: Attendance KPI Row
