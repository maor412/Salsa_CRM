import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/message_model.dart';
import '../../models/student_model.dart';
import '../../services/firestore_service.dart';
import '../../services/attendance_report_service.dart';
import '../../providers/auth_provider.dart';
import '../../config/app_theme.dart';
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
  final AttendanceReportService _reportService = AttendanceReportService();
  bool _isGeneratingPdf = false;

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

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Admin actions grid
                _AdminActionGrid(
                  onWhatsAppSettings: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WhatsAppSettingsScreen(),
                      ),
                    );
                  },
                  onAddTemplate: () => _showTemplateDialog(context),
                  onAddStudent: () => _showAddStudentDialog(context),
                  onExportPdf: _handleExportPdf,
                  isGeneratingPdf: _isGeneratingPdf,
                ),

                const SizedBox(height: AppSpacing.xl),

                // Templates section header
                Row(
                  children: [
                    const Text(
                      'תבניות הודעות',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${templates.length}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.md),

                // Templates list
                templates.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.xl),
                          child: Text(
                            'אין תבניות. הוסף תבנית ראשונה!',
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
                        itemCount: templates.length,
                        itemBuilder: (context, index) {
                          final template = templates[index];
                          return _TemplateCard(
                            template: template,
                            onEdit: () => _showTemplateDialog(
                              context,
                              template: template,
                            ),
                            onToggleStatus: () => _toggleTemplateStatus(template),
                          );
                        },
                      ),
              ],
            ),
          ),
        );
      },
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

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) => Directionality(
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
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('\u05D1\u05D9\u05D8\u05D5\u05DC'),
              ),
              ElevatedButton(
                onPressed: () {
                  final content = contentController.text.trim();
                  if (content.isEmpty) {
                    Navigator.pop(dialogContext, {'error': 'empty'});
                    return;
                  }
                  Navigator.pop(dialogContext, {
                    'content': content,
                    'category': selectedCategory,
                  });
                },
                child: Text(isEditing ? 'עדכן' : 'הוסף'),
              ),
            ],
          ),
        ),
      ),
    );

    contentController.dispose();

    if (!mounted || result == null) return;

    if (result['error'] == 'empty') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('נא להזין תוכן להודעה'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    await _saveTemplate(
      template: template,
      content: result['content'] as String,
      category: result['category'] as MessageCategory,
    );
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
              backgroundColor: AppColors.success,
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
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה: $e'),
            backgroundColor: AppColors.error,
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
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה: $e'),
            backgroundColor: AppColors.error,
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
            backgroundColor: AppColors.success,
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
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// טיפול בייצוא PDF
  Future<void> _handleExportPdf() async {
    setState(() => _isGeneratingPdf = true);

    try {
      await _reportService.showPdfPreview();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה ביצירת דוח: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }
}

// ============================================================================
// COMPONENT: Admin Action Grid
// ============================================================================
class _AdminActionGrid extends StatelessWidget {
  final VoidCallback onWhatsAppSettings;
  final VoidCallback onAddTemplate;
  final VoidCallback onAddStudent;
  final VoidCallback onExportPdf;
  final bool isGeneratingPdf;

  const _AdminActionGrid({
    required this.onWhatsAppSettings,
    required this.onAddTemplate,
    required this.onAddStudent,
    required this.onExportPdf,
    required this.isGeneratingPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'פעולות ניהול',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.settings,
                label: 'הגדרות WhatsApp',
                color: AppColors.whatsapp,
                onTap: onWhatsAppSettings,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildActionCard(
                icon: Icons.add_circle,
                label: 'תבנית חדשה',
                color: AppColors.primary,
                onTap: onAddTemplate,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.person_add,
                label: 'הוסף תלמיד',
                color: AppColors.info,
                onTap: onAddStudent,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildActionCard(
                icon: Icons.picture_as_pdf,
                label: isGeneratingPdf ? 'יוצר PDF...' : 'ייצא דוח PDF',
                color: AppColors.error,
                onTap: isGeneratingPdf ? () {} : onExportPdf,
                isLoading: isGeneratingPdf,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool fullWidth = false,
    bool isLoading = false,
  }) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isLoading
                    ? SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      )
                    : Icon(
                        icon,
                        color: color,
                        size: 28,
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// COMPONENT: Template Card
// ============================================================================
class _TemplateCard extends StatelessWidget {
  final MessageTemplate template;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;

  const _TemplateCard({
    required this.template,
    required this.onEdit,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with category and status
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
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: template.isActive
                              ? AppColors.successLight
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              template.isActive ? Icons.check_circle : Icons.cancel,
                              size: 14,
                              color: template.isActive
                                  ? AppColors.success
                                  : AppColors.textHint,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              template.isActive ? 'פעילה' : 'מושבתת',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: template.isActive
                                    ? AppColors.success
                                    : AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Action buttons
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: onEdit,
                      tooltip: 'עריכה',
                      color: AppColors.primary,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton(
                      icon: Icon(
                        template.isActive
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                      ),
                      onPressed: onToggleStatus,
                      tooltip: template.isActive ? 'השבת' : 'הפעל',
                      color: template.isActive ? AppColors.warning : AppColors.success,
                      style: IconButton.styleFrom(
                        backgroundColor: template.isActive
                            ? AppColors.warning.withValues(alpha: 0.1)
                            : AppColors.success.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const Divider(height: AppSpacing.xl),

            // Content preview
            Text(
              template.content,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// COMPONENT: Add Student Dialog
// ============================================================================
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
