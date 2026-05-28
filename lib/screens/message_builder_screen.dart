import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/message_model.dart';
import '../models/student_model.dart';
import '../services/ai_message_service.dart';
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
  final AiMessageService _aiMessageService = AiMessageService();
  final WhatsAppSettingsService _whatsappSettingsService =
      WhatsAppSettingsService();
  final TextEditingController _messageController = TextEditingController();

  MessageCategory _selectedCategory = MessageCategory.regular;
  MessageEvent? _currentEvent;
  List<StudentModel> _birthdayStudents = [];
  Set<String> _selectedBirthdayStudents = {}; // תלמידים נבחרים לאזכור
  bool _isLoading = false;
  String? _whatsappGroupLink;
  static const String _birthdayPlaceholder = '{{BIRTHDAY_BLOCK}}';

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
      await _generateAiMessageWithFallback();
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

  String _getCategoryName(MessageCategory category) {
    return MessageTemplate(
      id: '',
      content: '',
      category: category,
      createdAt: DateTime.now(),
    ).categoryName;
  }

  Future<void> _generateAiMessageWithFallback() async {
    final authProvider = context.read<AuthProvider>();
    final userName = authProvider.currentUser?.name ?? 'הצוות';

    await _checkBirthdays(addPlaceholder: false);

    final birthdayNames = _birthdayStudents
        .where((student) => _selectedBirthdayStudents.contains(student.id))
        .map((student) => _getFirstName(student.name))
        .toList();

    try {
      final aiMessage = await _aiMessageService.generateSalsaMessage(
        category: _selectedCategory,
        categoryName: _getCategoryName(_selectedCategory),
        senderName: userName,
        birthdayNames: birthdayNames,
      );

      setState(() {
        _messageController.text = _ensureBirthdayMention(
          aiMessage,
          birthdayNames,
        );
      });
    } catch (e) {
      debugPrint('AI message generation failed, falling back to templates: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('יצירת AI נכשלה. נטענה תבנית קיימת במקום.'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      await _generateRandomMessage();
    }
  }

  /// יצירת הודעה רנדומלית מהתבניות
  String _getFirstName(String fullName) {
    final trimmedName = fullName.trim();
    if (trimmedName.isEmpty) return trimmedName;
    return trimmedName.split(RegExp(r'\s+')).first;
  }

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
    await _checkBirthdays(addPlaceholder: false);
    final birthdayNames = _birthdayStudents
        .where((student) => _selectedBirthdayStudents.contains(student.id))
        .map((student) => _getFirstName(student.name))
        .toList();

    setState(() {
      _messageController.text = _ensureBirthdayMention(
        template.content,
        birthdayNames,
      );
    });
  }

  /// בדיקת ימי הולדת
  Future<void> _checkBirthdays({bool addPlaceholder = false}) async {
    try {
      final students = await _firestoreService.getUpcomingBirthdayStudents();
      print(
          'DEBUG: נמצאו ${students.length} תלמידים עם יום הולדת קרוב. שמות: ${students.map((s) => s.name).join(', ')}');

      setState(() {
        _birthdayStudents = students;
        _selectedBirthdayStudents = students.map((s) => s.id).toSet();
      });

      if (students.isEmpty || !addPlaceholder) {
        _removeBirthdayPlaceholder();
      }
    } catch (e) {
      print('Error checking birthdays: $e');
    }
  }

  /// הוספת ברכה ליום הולדת
  String _buildBirthdayGreeting([List<String>? birthdayNames]) {
    final names = birthdayNames ??
        _birthdayStudents
            .where((s) => _selectedBirthdayStudents.contains(s.id))
            .map((s) => _getFirstName(s.name))
            .toList();

    if (names.isEmpty) {
      return _birthdayPlaceholder;
    }

    if (names.length == 1) {
      return 'היום חוגגים יום הולדת ל${names.first}, עושים מעגל ומרימים באנרגיות. תבואו בכל הכוח!';
    }
    final combinedNames = names.length == 2
        ? '${names[0]} ו${names[1]}'
        : '${names.take(names.length - 1).join(', ')} ו${names.last}';
    return 'היום חוגגים יום הולדת ל$combinedNames, עושים מעגלים ומרימים באנרגיות. תבואו בכל הכוח!';
  }

  String _ensureBirthdayMention(String message, List<String> birthdayNames) {
    final cleanMessage = message.replaceAll(_birthdayPlaceholder, '').trim();
    if (birthdayNames.isEmpty) {
      return cleanMessage;
    }

    final mentionsBirthday = cleanMessage.contains('יום הולדת');
    if (mentionsBirthday) {
      return cleanMessage;
    }

    return '$cleanMessage\n\n${_buildBirthdayGreeting(birthdayNames)}'.trim();
  }

  void _removeBirthdayPlaceholder() {
    setState(() {
      _messageController.text = _messageController.text.replaceAll(
        _birthdayPlaceholder,
        '',
      );
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
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // Scrollable content area
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  keyboardHeight + AppSpacing.md,
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
                      onCopyMessage: _copyToClipboard,
                      onClearMessage: () {
                        setState(() => _messageController.clear());
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Step 3: שיתוף/שליחה
                    _buildStepHeader('3', 'שיתוף/שליחה'),
                    const SizedBox(height: AppSpacing.md),

                    // Info text
                    if (_whatsappGroupLink == null ||
                        _whatsappGroupLink!.isEmpty)
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: AppSpacing.md),
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

                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),

            // Sticky bottom action bar
            _StickyActionBar(
              hasMessage: _messageController.text.isNotEmpty,
              hasGroupLink:
                  _whatsappGroupLink != null && _whatsappGroupLink!.isNotEmpty,
              onSendToGroup: _sendToGroup,
            ),
          ],
        ),
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
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
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
  final VoidCallback onCopyMessage;
  final VoidCallback onClearMessage;

  const _MessageEditorCard({
    required this.messageController,
    required this.isLoading,
    required this.currentEvent,
    required this.onGenerateMessage,
    required this.onCopyMessage,
    required this.onClearMessage,
  });

  @override
  Widget build(BuildContext context) {
    final editorHeight =
        (MediaQuery.of(context).size.height * 0.25).clamp(160.0, 260.0);

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
                    label: const Text('צור עם AI'),
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
                  onPressed:
                      messageController.text.isEmpty ? null : onClearMessage,
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
              child: Stack(
                children: [
                  TextField(
                    controller: messageController,
                    textDirection: TextDirection.rtl,
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
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
                  Positioned(
                    top: 0,
                    left: 0,
                    child: IconButton(
                      onPressed: onCopyMessage,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'העתק הודעה',
                      color: AppColors.primary,
                      style: IconButton.styleFrom(
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.08),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: const Size(34, 34),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
  final VoidCallback onSendToGroup;

  const _StickyActionBar({
    required this.hasMessage,
    required this.hasGroupLink,
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
              // Primary CTA button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      (hasMessage && hasGroupLink) ? onSendToGroup : null,
                  icon: const Icon(Icons.send, size: 20),
                  label: const Text(
                    'שלח ב-WhatsApp',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.whatsapp,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.lg),
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
