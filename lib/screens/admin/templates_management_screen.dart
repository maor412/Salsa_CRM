import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/message_model.dart';
import '../../models/student_model.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';
import 'whatsapp_settings_screen.dart';

/// מסך ניהול תבניות הודעות (Admin בלבד)
class TemplatesManagementScreen extends StatefulWidget {
  const TemplatesManagementScreen({super.key});

  @override
  State<TemplatesManagementScreen> createState() =>
      _TemplatesManagementScreenState();
}

class _TemplatesManagementScreenState extends State<TemplatesManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (!authProvider.isAdmin) {
      return const Center(
        child: Text('רק אדמין יכול לגשת למסך זה'),
      );
    }

    return StreamBuilder<List<MessageTemplate>>(
      stream: _firestoreService.getAllTemplates(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('שגיאה: ${snapshot.error}'));
        }

        final templates = snapshot.data ?? [];

        return Column(
          children: [
            // כפתורי ניהול
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // כפתור הגדרות WhatsApp
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WhatsAppSettingsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.settings),
                      label: const Text('הגדרות קבוצת WhatsApp'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // כפתור הוספת תבנית
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showTemplateDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('הוסף תבנית חדשה'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // כפתור הוספת תלמיד
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddStudentDialog(context),
                      icon: const Icon(Icons.person_add),
                      label: const Text('הוסף תלמיד'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // רשימת תבניות
            Expanded(
              child: templates.isEmpty
                  ? const Center(
                      child: Text('אין תבניות. הוסף תבנית ראשונה!'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: templates.length,
                      itemBuilder: (context, index) {
                        final template = templates[index];
                        return _buildTemplateCard(template);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  /// בניית כרטיס תבנית
  Widget _buildTemplateCard(MessageTemplate template) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // כותרת וקטגוריה
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.categoryName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: template.isActive
                              ? Colors.green[100]
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          template.isActive ? 'פעילה' : 'מושבתת',
                          style: TextStyle(
                            fontSize: 12,
                            color: template.isActive
                                ? Colors.green[800]
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // כפתורי פעולה
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showTemplateDialog(
                        context,
                        template: template,
                      ),
                      tooltip: 'עריכה',
                    ),
                    IconButton(
                      icon: Icon(
                        template.isActive
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => _toggleTemplateStatus(template),
                      tooltip: template.isActive ? 'השבת' : 'הפעל',
                    ),
                  ],
                ),
              ],
            ),

            const Divider(),

            // תוכן התבנית
            Text(
              template.content,
              style: const TextStyle(fontSize: 14),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// הצגת דיאלוג הוספה/עריכת תבנית
  Future<void> _showTemplateDialog(
    BuildContext context, {
    MessageTemplate? template,
  }) async {
    final isEditing = template != null;
    final contentController = TextEditingController(
      text: template?.content ?? '',
    );
    MessageCategory selectedCategory = template?.category ?? MessageCategory.regular;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(isEditing ? 'עריכת תבנית' : 'תבנית חדשה'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // בחירת קטגוריה
                  const Text(
                    'קטגוריה:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<MessageCategory>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: MessageCategory.values.map((category) {
                      final temp = MessageTemplate(
                        id: '',
                        content: '',
                        category: category,
                        createdAt: DateTime.now(),
                      );
                      return DropdownMenuItem(
                        value: category,
                        child: Text(temp.categoryName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedCategory = value);
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // תוכן התבנית
                  const Text(
                    'תוכן ההודעה:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: contentController,
                    textDirection: TextDirection.rtl,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'הכנס את תוכן ההודעה כאן...\n\n'
                          'ניתן להשתמש ב:\n'
                          '{{BIRTHDAY_BLOCK}} - ברכה ליום הולדת\n'
                          '{{SENDER_NAME}} - שם השולח',
                    ),
                  ),

                  const SizedBox(height: 8),

                  // הסבר על placeholders
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'הערה: יש להשתמש ב-{{BIRTHDAY_BLOCK}} ו-{{SENDER_NAME}} '
                      'בכל תבנית. הם יוחלפו אוטומטית.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
            child: const Text('\u05D1\u05D9\u05D8\u05D5\u05DC'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (contentController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('נא להזין תוכן להודעה'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context, true);
                },
                child: Text(isEditing ? 'עדכן' : 'הוסף'),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true && mounted) {
      await _saveTemplate(
        template: template,
        content: contentController.text.trim(),
        category: selectedCategory,
      );
    }

    contentController.dispose();
  }

  /// שמירת תבנית
  Future<void> _saveTemplate({
    MessageTemplate? template,
    required String content,
    required MessageCategory category,
  }) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser;

      if (template == null) {
        // יצירת תבנית חדשה
        final newTemplate = MessageTemplate(
          id: '',
          content: content,
          category: category,
          createdAt: DateTime.now(),
          createdBy: user?.id,
        );

        await _firestoreService.addMessageTemplate(newTemplate);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('התבנית נוספה בהצלחה'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // עדכון תבנית קיימת
        final updatedTemplate = template.copyWith(
          content: content,
          category: category,
        );

        await _firestoreService.updateMessageTemplate(updatedTemplate);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('התבנית עודכנה בהצלחה'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// שינוי סטטוס תבנית (פעיל/מושבת)
  Future<void> _toggleTemplateStatus(MessageTemplate template) async {
    try {
      final updatedTemplate = template.copyWith(
        isActive: !template.isActive,
      );

      await _firestoreService.updateMessageTemplate(updatedTemplate);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              updatedTemplate.isActive
                  ? 'התבנית הופעלה'
                  : 'התבנית הושבתה',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// הצגת דיאלוג הוספת תלמיד
  Future<void> _showAddStudentDialog(BuildContext context) async {
    final result = await showDialog<_NewStudentData>(
      context: context,
      builder: (context) => const _AddStudentDialog(),
    );
    if (result != null) {
      await _addNewStudent(
        name: result.name,
        phone: result.phone,
        birthday: result.birthday,
      );
    }
  }

  Future<void> _addNewStudent({
    required String name,
    required String phone,
    required DateTime birthday,
  }) async {
    try {
      // יצירת מודל תלמיד חדש
      final newStudent = StudentModel(
        id: '', // ה-ID ייווצר אוטומטית על ידי Firestore
        name: name,
        phoneNumber: phone,
        birthday: birthday,
        joinedAt: DateTime.now(),
        isActive: true,
      );

      // שמירה ב-Firestore
      await _firestoreService.addStudent(newStudent);

      // הצגת הודעת הצלחה
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('התלמיד נוסף בהצלחה'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // הצגת הודעת שגיאה
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בהוספת תלמיד: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

class _NewStudentData {
  final String name;
  final String phone;
  final DateTime birthday;

  const _NewStudentData({
    required this.name,
    required this.phone,
    required this.birthday,
  });
}

class _AddStudentDialog extends StatefulWidget {
  const _AddStudentDialog();

  @override
  State<_AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends State<_AddStudentDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _phoneFocusNode = FocusNode();
  DateTime? _selectedBirthday;
  String? _birthdayError;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  Future<void> _selectBirthday() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      locale: const Locale('he', 'IL'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedBirthday = picked;
        _birthdayError = null;
      });
    }
  }

  void _submit() {
    setState(() {
      _birthdayError = _selectedBirthday == null ? 'אנא בחר תאריך לידה' : null;
    });

    if (_formKey.currentState!.validate() && _selectedBirthday != null) {
      Navigator.pop(
        context,
        _NewStudentData(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          birthday: _selectedBirthday!,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        scrollable: true,
        title: const Text('\u05D4\u05D5\u05E1\u05E3 \u05EA\u05DC\u05DE\u05D9\u05D3 \u05D7\u05D3\u05E9'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '\u05E9\u05DD \u05DE\u05DC\u05D0',
                  hintText: '\u05D4\u05D6\u05DF \u05E9\u05DD \u05DE\u05DC\u05D0',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '\u05D0\u05E0\u05D0 \u05D4\u05D6\u05DF \u05E9\u05DD \u05DE\u05DC\u05D0';
                  }
                  return null;
                },
                autofocus: true,
                onFieldSubmitted: (_) => _phoneFocusNode.requestFocus(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                focusNode: _phoneFocusNode,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: '\u05D8\u05DC\u05E4\u05D5\u05DF',
                  hintText: '\u05D4\u05D6\u05DF \u05DE\u05E1\u05E4\u05E8 \u05D8\u05DC\u05E4\u05D5\u05DF',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '\u05D0\u05E0\u05D0 \u05D4\u05D6\u05DF \u05DE\u05E1\u05E4\u05E8 \u05D8\u05DC\u05E4\u05D5\u05DF';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _phoneFocusNode.unfocus(),
              ),
              const SizedBox(height: 16),
              // תאריך לידה (חובה)
              InkWell(
                onTap: _selectBirthday,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'תאריך לידה',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.cake),
                    errorText: _birthdayError,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedBirthday == null
                            ? 'בחר תאריך לידה'
                            : '${_selectedBirthday!.day}/${_selectedBirthday!.month}/${_selectedBirthday!.year}',
                        style: TextStyle(
                          color: _selectedBirthday == null
                              ? Colors.grey[600]
                              : Colors.black,
                        ),
                      ),
                      const Icon(Icons.calendar_today, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('\u05D1\u05D9\u05D8\u05D5\u05DC'),
          ),
          ElevatedButton(
            onPressed: _submit,
            child: const Text('\u05E9\u05DE\u05D9\u05E8\u05D4'),
          ),
        ],
      ),
    );
  }
}
