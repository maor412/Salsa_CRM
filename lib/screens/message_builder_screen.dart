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

  /// ?"?\-?"?x ?`?"?>?" ???T?\?\? ?"?\?\?"?x ?\?"?-?-?"?x placeholder
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

  /// החלפת placeholder של שם השולח
  void _replaceSenderName() {
    final authProvider = context.read<AuthProvider>();
    final userName = authProvider.currentUser?.name ?? 'הצוות';

    setState(() {
      _messageController.text = _messageController.text.replaceAll(
        '{{SENDER_NAME}}',
        userName,
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
    final editorHeight = (MediaQuery.of(context).size.height * 0.25).clamp(160.0, 260.0);
    return ListView(
      padding: const EdgeInsets.all(16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
          // בחירת קטגוריה
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'סוג שיעור',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<MessageCategory>(
                    isExpanded: true,
                    value: _selectedCategory,
                    items: MessageCategory.values.map((category) {
                      final template = MessageTemplate(
                        id: '',
                        content: '',
                        category: category,
                        createdAt: DateTime.now(),
                      );
                      return DropdownMenuItem(
                        value: category,
                        child: Text(template.categoryName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedCategory = value);
                        _generateRandomMessage();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // כפתור יצירת הודעה
          if (_currentEvent == null || !_currentEvent!.isLocked)
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _handleLockEvent,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('צור הודעה חדשה'),
            ),

          const SizedBox(height: 16),

          // תיבת טקסט הודעה
          SizedBox(
            height: editorHeight.toDouble(),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _messageController,
                  textDirection: TextDirection.rtl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: 'ההודעה תופיע כאן...',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // הצעה אינטראקטיבית ליום הולדת
          if (_birthdayStudents.isNotEmpty) ...[
            Card(
              color: Colors.purple[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.cake, color: Colors.purple),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '🎂 ימי הולדת קרובים (בחר להוספה):',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // רשימת תלמידים עם Checkboxes
                    ..._birthdayStudents.map((student) => CheckboxListTile(
                          title: Text(
                            student.name,
                            style: const TextStyle(fontSize: 14),
                          ),
                          value: _selectedBirthdayStudents.contains(student.id),
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                _selectedBirthdayStudents.add(student.id);
                              } else {
                                _selectedBirthdayStudents.remove(student.id);
                              }
                              // אם הבלוק כבר נוסף, עדכן אותו אוטומטית
                              if (_birthdayBlockAdded) {
                                _removeBirthdayGreeting();
                                _addBirthdayGreeting();
                              }
                            });
                          },
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        )),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (!_birthdayBlockAdded)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _selectedBirthdayStudents.isEmpty
                                  ? null
                                  : _addBirthdayGreeting,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('הוסף אזכור'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        if (_birthdayBlockAdded)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _removeBirthdayGreeting,
                              icon: const Icon(Icons.remove, size: 18),
                              label: const Text('הסר אזכור'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.purple,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // כפתורי פעולה - שורה ראשונה
          Row(
            children: [
              // כפתור העתקה
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _messageController.text.isEmpty ? null : _copyToClipboard,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text(
                    'העתק',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // כפתור פתיחת WhatsApp כללי
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _messageController.text.isEmpty ? null : _openWhatsApp,
                  icon: const Icon(Icons.chat, size: 18),
                  label: const Text(
                    'WhatsApp',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),

          // כפתור שליחה לקבוצה - שורה שנייה
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_messageController.text.isEmpty ||
                      _whatsappGroupLink == null ||
                      _whatsappGroupLink!.isEmpty)
                  ? null
                  : _sendToGroup,
              icon: const Icon(Icons.send, size: 20),
              label: const Text(
                'שלח לקבוצה',
                style: TextStyle(fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          // הודעה אם אין קישור קבוצה
          if (_whatsappGroupLink == null || _whatsappGroupLink!.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'לא הוגדר קישור קבוצה. הגדר במסך הניהול.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
    );
  }
}
