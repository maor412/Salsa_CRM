import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/message_model.dart';
import '../../models/pending_student_model.dart';
import '../../models/student_model.dart';
import '../../services/firestore_service.dart';
import '../../services/attendance_report_service.dart';
import '../../services/whatsapp_settings_service.dart';
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
  static const String _studentJoinLink =
      'https://salsa-crew-assistant.web.app/join/?token=7ZOCp52ropIiMdTyrY2aj31LEeYCyLuR';

  final FirestoreService _firestoreService = FirestoreService();
  final AttendanceReportService _reportService = AttendanceReportService();
  final WhatsAppSettingsService _whatsappSettingsService =
      WhatsAppSettingsService();
  bool _isGeneratingPdf = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (!authProvider.isAdmin) {
      return const Center(
        child: Text('רק אדמין יכול לגשת למסך זה'),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AdminActionGrid(
              onAddStudent: () => _showAddStudentDialog(context),
              onShowJoinLink: () => _showJoinLinkDialog(context),
              onExportPdf: _handleExportPdf,
              isGeneratingPdf: _isGeneratingPdf,
            ),
            const SizedBox(height: AppSpacing.md),
            _PendingStudentsSection(
              firestoreService: _firestoreService,
              onApprove: _approvePendingStudent,
              onReject: _rejectPendingStudent,
            ),
            const SizedBox(height: AppSpacing.xl),
            FutureBuilder<String?>(
              future: _whatsappSettingsService.getGroupLink(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _QrLoadingCard();
                }

                if (snapshot.hasError) {
                  return _QrEmptyCard(
                    title: 'לא ניתן לטעון את קישור הקבוצה',
                    message: 'נסה לפתוח שוב את המסך או לעדכן את הקישור.',
                    buttonLabel: 'הגדר קישור WhatsApp',
                    onPressed: () => _openWhatsAppSettings(context),
                  );
                }

                final groupLink = snapshot.data?.trim();
                if (groupLink == null || groupLink.isEmpty) {
                  return _QrEmptyCard(
                    title: 'עדיין אין קישור לקבוצת WhatsApp',
                    message: 'הוסף קישור הזמנה כדי להציג כאן קוד QR לסריקה.',
                    buttonLabel: 'הגדר קישור WhatsApp',
                    onPressed: () => _openWhatsAppSettings(context),
                  );
                }

                return _WhatsAppQrCard(
                  groupLink: groupLink,
                  onEditLink: () => _openWhatsAppSettings(context),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWhatsAppSettings(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WhatsAppSettingsScreen(),
      ),
    );
    if (mounted) {
      _whatsappSettingsService.clearCache();
      setState(() {});
    }
  }

  Future<void> _showJoinLinkDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'קישור למסך מילוי פרטים',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'שלח את הקישור לתלמידים חדשים. הפרטים ייכנסו לרשימת המתנה לאישור.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: SizedBox(
                      width: 180,
                      height: 180,
                      child: QrImageView(
                        data: _studentJoinLink,
                        version: QrVersions.auto,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const SelectableText(
                    _studentJoinLink,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('סגור'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await Clipboard.setData(
                              const ClipboardData(text: _studentJoinLink),
                            );
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            if (mounted) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('הקישור הועתק'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy),
                          label: const Text('העתק'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _approvePendingStudent(PendingStudentModel pending) async {
    try {
      await _firestoreService.approvePendingStudent(pending);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${pending.name} נוסף לרשימת התלמידים'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה באישור תלמיד: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _rejectPendingStudent(PendingStudentModel pending) async {
    try {
      await _firestoreService.rejectPendingStudent(pending.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${pending.name} נדחה'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בדחיית תלמיד: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
    MessageCategory selectedCategory =
        template?.category ?? MessageCategory.regular;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setState) => WillPopScope(
            onWillPop: () async {
              // Store the content before popping
              return true;
            },
            child: AlertDialog(
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
      ),
    );

    // Delay dispose to ensure dialog animation completes
    Future.delayed(const Duration(milliseconds: 300), () {
      contentController.dispose();
    });

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
              updatedTemplate.isActive ? 'התבנית הופעלה' : 'התבנית הושבתה',
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
// COMPONENT: Pending Students
// ============================================================================
class _PendingStudentsSection extends StatelessWidget {
  final FirestoreService firestoreService;
  final Future<void> Function(PendingStudentModel pending) onApprove;
  final Future<void> Function(PendingStudentModel pending) onReject;

  const _PendingStudentsSection({
    required this.firestoreService,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PendingStudentModel>>(
      stream: firestoreService.getPendingStudents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final pendingStudents = snapshot.data ?? [];
        if (pendingStudents.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'תלמידים ממתינים לאישור',
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
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(AppRadius.round),
                  ),
                  child: Text(
                    '${pendingStudents.length}',
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ...pendingStudents.map(
              (student) => _PendingStudentCard(
                student: student,
                onApprove: () => onApprove(student),
                onReject: () => onReject(student),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PendingStudentCard extends StatelessWidget {
  final PendingStudentModel student;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingStudentCard({
    required this.student,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.18),
                child: Text(
                  student.name.isNotEmpty ? student.name[0] : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${student.phoneNumber} · ${_formatDate(student.birthday)}',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close),
                  label: const Text('דחה'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check),
                  label: const Text('אשר'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ============================================================================
// COMPONENT: WhatsApp QR Card
// ============================================================================
class _WhatsAppQrCard extends StatelessWidget {
  final String groupLink;
  final VoidCallback onEditLink;

  const _WhatsAppQrCard({
    required this.groupLink,
    required this.onEditLink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.whatsapp.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.qr_code_2,
                  color: AppColors.whatsapp,
                  size: 30,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'קוד הצטרפות לקבוצה',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'סריקה תפתח את קבוצת ה-WhatsApp',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEditLink,
                tooltip: 'ערוך קישור',
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.whatsapp,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.divider),
            ),
            child: QrImageView(
              data: groupLink,
              version: QrVersions.auto,
              size: 230,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: AppColors.textPrimary,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            groupLink,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QrLoadingCard extends StatelessWidget {
  const _QrLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.medium,
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _QrEmptyCard extends StatelessWidget {
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _QrEmptyCard({
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.medium,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.qr_code_2,
              color: AppColors.primary,
              size: 36,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.settings),
              label: Text(buttonLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.whatsapp,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// COMPONENT: Admin Action Grid
// ============================================================================
class _AdminActionGrid extends StatelessWidget {
  final VoidCallback onAddStudent;
  final VoidCallback onShowJoinLink;
  final VoidCallback onExportPdf;
  final bool isGeneratingPdf;

  const _AdminActionGrid({
    required this.onAddStudent,
    required this.onShowJoinLink,
    required this.onExportPdf,
    required this.isGeneratingPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildActionCard(
                icon: Icons.link,
                label: 'הצג קישור מילוי פרטים',
                color: AppColors.primary,
                onTap: onShowJoinLink,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildActionCard(
                icon: Icons.picture_as_pdf,
                label: isGeneratingPdf ? 'יוצר PDF...' : 'ייצא דוח נוכחות',
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
          height: 142,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
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
                        size: 26,
                      ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
                              template.isActive
                                  ? Icons.check_circle
                                  : Icons.cancel,
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
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.1),
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
                      color: template.isActive
                          ? AppColors.warning
                          : AppColors.success,
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
        title: const Text(
            '\u05D4\u05D5\u05E1\u05E3 \u05EA\u05DC\u05DE\u05D9\u05D3 \u05D7\u05D3\u05E9'),
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
                  hintText:
                      '\u05D4\u05D6\u05DF \u05E9\u05DD \u05DE\u05DC\u05D0',
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
                  hintText:
                      '\u05D4\u05D6\u05DF \u05DE\u05E1\u05E4\u05E8 \u05D8\u05DC\u05E4\u05D5\u05DF',
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
