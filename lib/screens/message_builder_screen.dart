import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/message_model.dart';
import '../models/student_model.dart';
import '../services/firestore_service.dart';
import '../services/whatsapp_settings_service.dart';
import '../providers/auth_provider.dart';
import '../config/app_theme.dart';

/// מסך בניית והודעות WhatsApp
class MessageBuilderScreen extends StatefulWidget {
  const MessageBuilderScreen({super.key});

  @override
  State<MessageBuilderScreen> createState() => _MessageBuilderScreenState();
}

class _MessageBuilderScreenState extends State<MessageBuilderScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final WhatsAppSettingsService _whatsappSettingsService = WhatsAppSettingsService();
  final TextEditingController _messageController = TextEditingController();

  MessageCategory _selectedCategory = MessageCategory.regular;
  MessageEvent? _currentEvent;
  List<StudentModel> _birthdayStudents = [];
  Set<String> _selectedBirthdayStudents = {}; // תלמידים נבחרים לאזכור
  bool _isLoading = false;
  String? _whatsappGroupLink;
  bool _birthdayBlockAdded = false;
  static const String _birthdayPlaceholder = '{{BIRTHDAY_BLOCK}}';
  String? _birthdayGreetingCache;

  @override
  void initState() {
    super.initState();
    _checkTodayEvent();
    _loadWhatsappLink();
    // בדיקת ימי הולדת מעוכבת כדי לתת לתבנית להיטען
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBirthdays();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  /// בדיקה האם יש אירוע הודעה להיום
  Future<void> _checkTodayEvent() async {
    setState(() => _isLoading = true);

    final today = DateTime.now();
    final isMessageDay = today.weekday == DateTime.wednesday ||
                         today.weekday == DateTime.saturday;

    if (isMessageDay) {
      final event = await _firestoreService.getMessageEventByDate(today);

      if (event != null && !event.isSent) {
        setState(() {
          _currentEvent = event;
        });

        // אם האירוע לא נעול, הצג התראה
        if (!event.isLocked) {
          _showMessageDayAlert();
        }
      }
    }

    setState(() => _isLoading = false);
  }

  /// הצגת התראה ליום הודעה
  void _showMessageDayAlert() {
    final today = DateTime.now();
    final dayName = today.weekday == DateTime.wednesday ? 'רביעי' : 'מוצ"ש';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (context) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('הגיע הזמן לשלוח הודעה בקבוצה'),
            content: Text('היום $dayName - זמן לשלוח הודעת "היום ביילה"'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('אחר כך'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleLockEvent();
                },
                child: const Text('אני שולח!'),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// נעילת אירוע ויצירת הודעה
  Future<void> _handleLockEvent() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) return;

    setState(() => _isLoading = true);

    // אם אין אירוע, צור חדש
    if (_currentEvent == null) {
      final eventId = await _firestoreService.createMessageEvent(
        MessageEvent(
          id: '',
          scheduledDate: DateTime.now(),
          category: _selectedCategory,
        ),
      );

      _currentEvent = MessageEvent(
        id: eventId,
        scheduledDate: DateTime.now(),
        category: _selectedCategory,
      );
    }

    // נסה לנעול את האירוע
    final success = await _firestoreService.lockMessageEvent(
      _currentEvent!.id,
      user.id,
      user.name,
    );

    if (success) {
      await _generateRandomMessage();
      await _checkBirthdays();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('האירוע כבר נעול על ידי מדריך אחר'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  /// יצירת הודעה רנדומלית מהתבניות
  Future<void> _generateRandomMessage() async {
    final templates = await _firestoreService.getTemplatesByCategory(
      _selectedCategory,
    );

    if (templates.isEmpty) {
      setState(() {
        _messageController.text =
            'אין תבניות זמינות לקטגוריה זו.\nצור תבניות במסך הניהול.';
      });
      return;
    }

    // בחירה רנדומלית
    final random = Random();
    final template = templates[random.nextInt(templates.length)];

    setState(() {
      _messageController.text = template.content;
    });

    // בדוק ימי הולדת אחרי שטעינת התבנית
    await _checkBirthdays();
  }

  /// בדיקת ימי הולדת
  Future<void> _checkBirthdays() async {
    try {
      final students = await _firestoreService.getUpcomingBirthdayStudents();
      print('DEBUG: נמצאו ${students.length} תלמידים עם יום הולדת קרוב. שמות: ${students.map((s) => s.name).join(', ')}');

      setState(() {
        _birthdayStudents = students;
        _selectedBirthdayStudents = students.map((s) => s.id).toSet();
      });

      // רק הוסף placeholder אם כבר יש תוכן בהודעה (לא בהתחלה)
      if (students.isNotEmpty &&
          _messageController.text.trim().isNotEmpty &&
          !_messageController.text.contains(_birthdayPlaceholder) &&
          !_birthdayBlockAdded) {
        setState(() {
          _messageController.text = '${_messageController.text}\n\n$_birthdayPlaceholder';
        });
      } else if (students.isEmpty) {
        _removeBirthdayPlaceholder();
      }
    } catch (e) {
      print('Error checking birthdays: $e');
    }
  }

  /// הוספת ברכה ליום הולדת
  String _buildBirthdayGreeting() {
    final selectedStudents = _birthdayStudents
        .where((s) => _selectedBirthdayStudents.contains(s.id))
        .toList();

    if (selectedStudents.isEmpty) {
      return _birthdayPlaceholder;
    }

    final names = selectedStudents.map((s) => s.getBirthdayGreeting()).toList();
    if (names.length == 1) {
      return '\u05D4\u05D9\u05D5\u05DD \u05D7\u05D5\u05D2\u05D2\u05D9\u05DD \u05D9\u05D5\u05DD \u05D4\u05D5\u05DC\u05D3\u05EA \u05DC${names.first}, \u05DB\u05D5\u05DC\u05DD \u05E0\u05E9\u05D0\u05E8\u05D9\u05DD \u05DC\u05D4\u05E8\u05D9\u05DD \u05D1\u05DE\u05E2\u05D2\u05DC!!!';
    }
    final combinedNames = '${names[0]} \u05D5\u05DC${names[1]}';
    return '\u05D4\u05D9\u05D5\u05DD \u05D7\u05D5\u05D2\u05D2\u05D9\u05DD \u05D9\u05D5\u05DD \u05D4\u05D5\u05DC\u05D3\u05EA \u05DC$combinedNames, \u05DB\u05D5\u05DC\u05DD \u05E0\u05E9\u05D0\u05E8\u05D9\u05DD \u05DC\u05D4\u05E8\u05D9\u05DD \u05D1\u05DE\u05E2\u05D2\u05DC\u05D9\u05DD.';
  }

  void _addBirthdayGreeting() {
    if (_selectedBirthdayStudents.isEmpty) return;

    final greetingBlock = _buildBirthdayGreeting();

    setState(() {
      if (_messageController.text.contains(_birthdayPlaceholder)) {
        _messageController.text = _messageController.text.replaceAll(
          _birthdayPlaceholder,
          greetingBlock,
        );
      } else if (_birthdayGreetingCache != null &&
          _messageController.text.contains(_birthdayGreetingCache!)) {
        _messageController.text = _messageController.text.replaceAll(
          _birthdayGreetingCache!,
          greetingBlock,
        );
      } else {
        if (_messageController.text.trim().isNotEmpty) {
          _messageController.text =
              '${_messageController.text.trim()}\n\n$greetingBlock';
        } else {
          _messageController.text = greetingBlock;
        }
      }
      _birthdayGreetingCache = greetingBlock;
      _birthdayBlockAdded = true;
    });
  }

  /// הסרת ברכה ליום הולדת והוספת placeholder
  void _removeBirthdayGreeting() {
    setState(() {
      if (_birthdayGreetingCache != null &&
          _messageController.text.contains(_birthdayGreetingCache!)) {
        _messageController.text = _messageController.text.replaceAll(
          _birthdayGreetingCache!,
          _birthdayPlaceholder,
        );
      }
      if (!_messageController.text.contains(_birthdayPlaceholder)) {
        if (_messageController.text.trim().isNotEmpty) {
          _messageController.text =
              '${_messageController.text.trim()}\n\n$_birthdayPlaceholder';
        } else {
          _messageController.text = _birthdayPlaceholder;
        }
      }
      _birthdayGreetingCache = null;
      _birthdayBlockAdded = false;
    });
  }

  void _removeBirthdayPlaceholder() {
    setState(() {
      _messageController.text = _messageController.text.replaceAll(
        _birthdayPlaceholder,
        '',
      );
      _birthdayGreetingCache = null;
      _birthdayBlockAdded = false;
    });
  }


  /// יצירת טקסט הודעה סופי עם כל ה-placeholders
  String _getFinalMessageText() {
    final authProvider = context.read<AuthProvider>();
    final userName = authProvider.currentUser?.name ?? 'הצוות';

    return _messageController.text
        .replaceAll('{{SENDER_NAME}}', userName)
        .replaceAll(_birthdayPlaceholder, ''); // הסר placeholder אם נשאר
  }

  /// העתקת הודעה ללוח
  Future<void> _copyToClipboard() async {
    final finalText = _getFinalMessageText();
    await Clipboard.setData(ClipboardData(text: finalText));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ההודעה הועתקה ללוח'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// פתיחת WhatsApp (כללי - ללא הודעה)
  Future<void> _openWhatsApp() async {
    final finalText = _getFinalMessageText();
    final message = Uri.encodeComponent(finalText);
    final appUrl = Uri.parse('whatsapp://send?text=$message');
    final webUrl = Uri.parse('https://wa.me/?text=$message');

    if (await canLaunchUrl(appUrl)) {
      await launchUrl(appUrl, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(webUrl)) {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('לא ניתן לפתוח את WhatsApp'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// שליחה לקבוצה - העתקה + פתיחת קבוצת WhatsApp
  Future<void> _sendToGroup() async {
    if (_whatsappGroupLink == null || _whatsappGroupLink!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('לא הוגדר קישור לקבוצה. הגדר במסך הניהול.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // 1. העתק הודעה ללוח
    final finalText = _getFinalMessageText();
    await Clipboard.setData(ClipboardData(text: finalText));

    // 2. פתח קבוצת WhatsApp
    final url = Uri.parse(_whatsappGroupLink!);

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);

      // 3. הצג הודעה למשתמש
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ההודעה הועתקה. הדבק בקבוצה ב-WhatsApp 👌'),
            duration: Duration(seconds: 3),
            backgroundColor: Color(0xFF25D366),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('לא ניתן לפתוח את קבוצת WhatsApp'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// טעינת קישור לקבוצת WhatsApp מ-Firestore
  Future<void> _loadWhatsappLink() async {
    final link = await _whatsappSettingsService.getGroupLink();
    setState(() {
      _whatsappGroupLink = link;
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Scrollable content area
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                keyboardHeight + 100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step 1: בחירת סוג שיעור
                  _buildStepHeader('1', 'בחר סוג שיעור'),
                  const SizedBox(height: AppSpacing.md),
                  _LessonTypeChips(
                    selectedCategory: _selectedCategory,
                    onCategoryChanged: (category) {
                      setState(() => _selectedCategory = category);
                      _generateRandomMessage();
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Step 2: צור/ערוך הודעה
                  _buildStepHeader('2', 'צור/ערוך הודעה'),
                  const SizedBox(height: AppSpacing.md),
                  _MessageEditorCard(
                    messageController: _messageController,
                    isLoading: _isLoading,
                    currentEvent: _currentEvent,
                    onGenerateMessage: _handleLockEvent,
                    onClearMessage: () {
                      setState(() => _messageController.clear());
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Birthday section
                  if (_birthdayStudents.isNotEmpty) ...[
                    _BirthdayMentionChips(
                      birthdayStudents: _birthdayStudents,
                      selectedBirthdayStudents: _selectedBirthdayStudents,
                      birthdayBlockAdded: _birthdayBlockAdded,
                      onToggleStudent: (studentId) {
                        setState(() {
                          if (_selectedBirthdayStudents.contains(studentId)) {
                            _selectedBirthdayStudents.remove(studentId);
                          } else {
                            _selectedBirthdayStudents.add(studentId);
                          }
                          // אם הבלוק כבר נוסף, עדכן אותו אוטומטית
                          if (_birthdayBlockAdded) {
                            _removeBirthdayGreeting();
                            _addBirthdayGreeting();
                          }
                        });
                      },
                      onAddMention: _addBirthdayGreeting,
                      onRemoveMention: _removeBirthdayGreeting,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Step 3: שיתוף/שליחה
                  _buildStepHeader('3', 'שיתוף/שליחה'),
                  const SizedBox(height: AppSpacing.md),

                  // Info text
                  if (_whatsappGroupLink == null || _whatsappGroupLink!.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Text(
                        'לא הוגדר קישור קבוצה. הגדר במסך הניהול.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Add bottom padding so content isn't hidden by sticky bar
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // Sticky bottom action bar
          _StickyActionBar(
            hasMessage: _messageController.text.isNotEmpty,
            hasGroupLink: _whatsappGroupLink != null && _whatsappGroupLink!.isNotEmpty,
            onCopy: _copyToClipboard,
            onOpenWhatsApp: _openWhatsApp,
            onSendToGroup: _sendToGroup,
          ),
        ],
      ),
    );
  }

  Widget _buildStepHeader(String stepNumber, String title) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(
            stepNumber,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// COMPONENT: Lesson Type Chips
// ============================================================================
class _LessonTypeChips extends StatelessWidget {
  final MessageCategory selectedCategory;
  final ValueChanged<MessageCategory> onCategoryChanged;

  const _LessonTypeChips({
    required this.selectedCategory,
    required this.onCategoryChanged,
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
            children: MessageCategory.values.map((category) {
              final isSelected = category == selectedCategory;
              final template = MessageTemplate(
                id: '',
                content: '',
                category: category,
                createdAt: DateTime.now(),
              );

              return Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: ChoiceChip(
                  label: Text(template.categoryName),
                  selected: isSelected,
                  onSelected: (_) => onCategoryChanged(category),
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
// COMPONENT: Message Editor Card
// ============================================================================
class _MessageEditorCard extends StatelessWidget {
  final TextEditingController messageController;
  final bool isLoading;
  final MessageEvent? currentEvent;
  final VoidCallback onGenerateMessage;
  final VoidCallback onClearMessage;

  const _MessageEditorCard({
    required this.messageController,
    required this.isLoading,
    required this.currentEvent,
    required this.onGenerateMessage,
    required this.onClearMessage,
  });

  @override
  Widget build(BuildContext context) {
    final editorHeight = (MediaQuery.of(context).size.height * 0.25).clamp(160.0, 260.0);

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with actions
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'תוכן ההודעה',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                // Generate new message button (secondary)
                if (currentEvent == null || !currentEvent!.isLocked)
                  OutlinedButton.icon(
                    onPressed: isLoading ? null : onGenerateMessage,
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('צור הודעה'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                    ),
                  ),
                const SizedBox(width: AppSpacing.sm),
                // Clear button
                IconButton(
                  onPressed: messageController.text.isEmpty ? null : onClearMessage,
                  icon: const Icon(Icons.clear, size: 20),
                  tooltip: 'נקה הודעה',
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Text editor
          SizedBox(
            height: editorHeight.toDouble(),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TextField(
                controller: messageController,
                textDirection: TextDirection.rtl,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontSize: 15, height: 1.5),
                decoration: const InputDecoration(
                  hintText: 'ההודעה תופיע כאן...\nאו ערוך בעצמך',
                  hintStyle: TextStyle(color: AppColors.textHint),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
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
// COMPONENT: Birthday Mention Chips
// ============================================================================
class _BirthdayMentionChips extends StatelessWidget {
  final List<StudentModel> birthdayStudents;
  final Set<String> selectedBirthdayStudents;
  final bool birthdayBlockAdded;
  final ValueChanged<String> onToggleStudent;
  final VoidCallback onAddMention;
  final VoidCallback onRemoveMention;

  const _BirthdayMentionChips({
    required this.birthdayStudents,
    required this.selectedBirthdayStudents,
    required this.birthdayBlockAdded,
    required this.onToggleStudent,
    required this.onAddMention,
    required this.onRemoveMention,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.accent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primaryLight.withValues(alpha: 0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.cake,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: Text(
                    'ימי הולדת קרובים',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Student chips
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: birthdayStudents.map((student) {
                final isSelected = selectedBirthdayStudents.contains(student.id);

                return FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🎂'),
                      const SizedBox(width: AppSpacing.xs),
                      Text(student.name),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (_) => onToggleStudent(student.id),
                  selectedColor: AppColors.primaryLight,
                  backgroundColor: Colors.white,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: isSelected ? 2 : 1,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.md),

            // Action button
            SizedBox(
              width: double.infinity,
              child: birthdayBlockAdded
                  ? OutlinedButton.icon(
                      onPressed: onRemoveMention,
                      icon: const Icon(Icons.remove, size: 18),
                      label: const Text('הסר אזכור'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: selectedBirthdayStudents.isEmpty ? null : onAddMention,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('הוסף אזכור'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
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
// COMPONENT: Sticky Action Bar
// ============================================================================
class _StickyActionBar extends StatelessWidget {
  final bool hasMessage;
  final bool hasGroupLink;
  final VoidCallback onCopy;
  final VoidCallback onOpenWhatsApp;
  final VoidCallback onSendToGroup;

  const _StickyActionBar({
    required this.hasMessage,
    required this.hasGroupLink,
    required this.onCopy,
    required this.onOpenWhatsApp,
    required this.onSendToGroup,
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
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Secondary actions row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: hasMessage ? onCopy : null,
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('העתק'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: hasMessage ? onOpenWhatsApp : null,
                      icon: const Icon(Icons.chat, size: 18),
                      label: const Text('WhatsApp'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // Primary CTA button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (hasMessage && hasGroupLink) ? onSendToGroup : null,
                  icon: const Icon(Icons.send, size: 20),
                  label: const Text(
                    'שלח ב-WhatsApp',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.whatsapp,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
