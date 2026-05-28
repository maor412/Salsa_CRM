import 'package:cloud_functions/cloud_functions.dart';

import '../models/message_model.dart';

class AiMessageService {
  final FirebaseFunctions _functions;

  AiMessageService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  Future<String> generateSalsaMessage({
    required MessageCategory category,
    required String categoryName,
    required String senderName,
    required List<String> birthdayNames,
  }) async {
    final callable = _functions.httpsCallable(
      'generateSalsaMessage',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );

    final result = await callable.call<Map<String, dynamic>>({
      'category': category.name,
      'categoryName': categoryName,
      'senderName': senderName,
      'birthdayNames': birthdayNames,
      'tone': 'קליל, אנרגטי, חברי, ישראלי',
      'minLength': 260,
      'maxLength': 550,
    });

    final data = result.data;
    final message = data['message'] as String?;
    if (message == null || message.trim().isEmpty) {
      throw Exception('Gemini returned an empty message');
    }

    return message.trim();
  }
}
