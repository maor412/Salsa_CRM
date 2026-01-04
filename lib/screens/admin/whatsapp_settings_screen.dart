import 'package:flutter/material.dart';
import '../../services/whatsapp_settings_service.dart';

/// מסך ניהול הגדרות WhatsApp (Admin בלבד)
class WhatsAppSettingsScreen extends StatefulWidget {
  const WhatsAppSettingsScreen({super.key});

  @override
  State<WhatsAppSettingsScreen> createState() => _WhatsAppSettingsScreenState();
}

class _WhatsAppSettingsScreenState extends State<WhatsAppSettingsScreen> {
  final WhatsAppSettingsService _whatsappSettingsService = WhatsAppSettingsService();
  final TextEditingController _groupLinkController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isSaving = false;
  String? _currentLink;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  @override
  void dispose() {
    _groupLinkController.dispose();
    super.dispose();
  }

  /// טעינת הגדרות נוכחיות
  Future<void> _loadCurrentSettings() async {
    setState(() => _isLoading = true);

    try {
      final link = await _whatsappSettingsService.getGroupLink();
      setState(() {
        _currentLink = link;
        _groupLinkController.text = link ?? '';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בטעינת הגדרות: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// שמירת קישור חדש
  Future<void> _saveGroupLink() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final newLink = _groupLinkController.text.trim();
      await _whatsappSettingsService.updateGroupLink(newLink);

      setState(() => _currentLink = newLink);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('קישור הקבוצה נשמר בהצלחה!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בשמירה: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  /// בדיקת תקינות הקישור
  String? _validateGroupLink(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'יש להזין קישור לקבוצת WhatsApp';
    }

    if (!WhatsAppSettingsService.isValidGroupLink(value.trim())) {
      return 'פורמט הקישור אינו תקין.\nדוגמה: https://chat.whatsapp.com/XXXXX';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('הגדרות WhatsApp'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // כרטיס הסבר
                    Card(
                      color: Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue[700],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'מידע חשוב',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'הזן כאן את קישור ה-Invite לקבוצת WhatsApp של הסטודיו.',
                              style: TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'הקישור ישמש במסך ההודעות לפתיחה מהירה של הקבוצה.',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // הוראות
                    const Text(
                      'איך למצוא את הקישור?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInstructionStep(
                      1,
                      'פתח את קבוצת WhatsApp',
                    ),
                    _buildInstructionStep(
                      2,
                      'לחץ על שם הקבוצה למעלה',
                    ),
                    _buildInstructionStep(
                      3,
                      'בחר "הזמן באמצעות קישור"',
                    ),
                    _buildInstructionStep(
                      4,
                      'העתק את הקישור והדבק כאן למטה',
                    ),

                    const SizedBox(height: 24),

                    // שדה טקסט לקישור
                    TextFormField(
                      controller: _groupLinkController,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        labelText: 'קישור קבוצת WhatsApp',
                        hintText: 'https://chat.whatsapp.com/XXXXX',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link),
                      ),
                      validator: _validateGroupLink,
                      maxLines: 2,
                    ),

                    const SizedBox(height: 8),

                    // דוגמה
                    Text(
                      'דוגמה: https://chat.whatsapp.com/ABC123xyz',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // כפתור שמירה
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveGroupLink,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_isSaving ? 'שומר...' : 'שמור קישור'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),

                    // סטטוס נוכחי
                    if (_currentLink != null && _currentLink!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Card(
                          color: Colors.green[50],
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green[700],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'קישור פעיל',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'הקישור הנוכחי: $_currentLink',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  /// יצירת שלב בהוראות
  Widget _buildInstructionStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(text),
            ),
          ),
        ],
      ),
    );
  }
}
