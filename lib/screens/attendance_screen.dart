import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/student_model.dart';
import '../models/attendance_model.dart';
import '../services/firestore_service.dart';
import '../providers/auth_provider.dart';

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

  LessonType _selectedLessonType = LessonType.regular;
  Map<String, bool> _attendance = {};
  bool _isSaving = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchQuery.dispose();
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
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה במחיקת תלמיד: $e'),
            backgroundColor: Colors.red,
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
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בעדכון תלמיד: $e'),
            backgroundColor: Colors.red,
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
          backgroundColor: Colors.orange,
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
            backgroundColor: Colors.green,
          ),
        );

        // איפוס הטופס
        setState(() {
          _attendance.clear();
          _selectedLessonType = LessonType.regular;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בשמירת נוכחות: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StudentModel>>(
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
            // סוג שיעור וחיפוש
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // בחירת סוג שיעור
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Text(
                            'סוג שיעור:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButton<LessonType>(
                              isExpanded: true,
                              value: _selectedLessonType,
                              items: LessonType.values.map((type) {
                                final session = AttendanceSession(
                                  id: '',
                                  date: DateTime.now(),
                                  lessonType: type,
                                  instructorId: '',
                                  instructorName: '',
                                  createdAt: DateTime.now(),
                                );
                                return DropdownMenuItem(
                                  value: type,
                                  child: Text(session.lessonTypeName),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedLessonType = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // חיפוש
                  ValueListenableBuilder<String>(
                    valueListenable: _searchQuery,
                    builder: (context, searchValue, _) {
                      return TextField(
                        controller: _searchController,
                        textDirection: TextDirection.rtl,
                        decoration: InputDecoration(
                          hintText: 'חפש תלמיד...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: searchValue.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _searchQuery.value = '';
                                  },
                                )
                              : null,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          _searchQuery.value = value;
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            // רשימת תלמידים
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: _searchQuery,
                builder: (context, searchValue, _) {
                  // סינון לפי חיפוש
                  final filteredStudents = allStudents.where((student) {
                    if (searchValue.isEmpty) return true;
                    return student.name.contains(searchValue);
                  }).toList();

                  return filteredStudents.isEmpty
                      ? const Center(
                          child: Text('לא נמצאו תלמידים'),
                        )
                      : ListView.builder(
                          itemCount: filteredStudents.length,
                          itemBuilder: (context, index) {
                            final student = filteredStudents[index];
                            final isPresent = _attendance[student.id] ?? false;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isPresent ? Colors.green : Colors.grey,
                                child: Text(
                                  student.name.isNotEmpty
                                      ? student.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(student.name),
                              subtitle: student.phoneNumber.isNotEmpty
                                  ? Text(student.phoneNumber)
                                  : null,
                              trailing: Checkbox(
                                value: isPresent,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _attendance[student.id] = true;
                                    } else {
                                      _attendance.remove(student.id);
                                    }
                                  });
                                },
                                activeColor: Colors.green,
                              ),
                              onTap: () {
                                setState(() {
                                  final current = _attendance[student.id] ?? false;
                                  if (current) {
                                    _attendance.remove(student.id);
                                  } else {
                                    _attendance[student.id] = true;
                                  }
                                });
                              },
                              onLongPress: () => _showStudentOptions(student),
                            );
                          },
                        );
                },
              ),
            ),

            // סטטיסטיקה וכפתור שמירה
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Column(
                children: [
                  // סטטיסטיקה
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        'סה"כ',
                        '${allStudents.length}',
                        Colors.blue,
                      ),
                      _buildStatItem(
                        'נוכחים',
                        '${_attendance.length}',
                        Colors.green,
                      ),
                      _buildStatItem(
                        'אחוז',
                        allStudents.isEmpty
                            ? '0%'
                            : '${(_attendance.length / allStudents.length * 100).toStringAsFixed(0)}%',
                        Colors.orange,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // כפתור שמירה
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () => _saveAttendance(allStudents),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'שומר...' : 'סיום ושמירה'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// בניית פריט סטטיסטיקה
  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
