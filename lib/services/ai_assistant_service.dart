// lib/services/ai_assistant_service.dart
//
// Thin wrapper around the `aiAssistant` callable Cloud Function
// (functions/index.js). No OpenAI key or Firestore query logic here —
// both live server-side. This mirrors how every other *_service.dart in
// the app is a thin, static-method wrapper around one Firestore concern;
// this one just wraps one callable instead.

import 'package:cloud_functions/cloud_functions.dart';

import '../models/chat_message.dart';

class AiAssistantResponse {
  final String reply;
  final String? navigateTo;
  final String? navigateReason;

  const AiAssistantResponse({required this.reply, this.navigateTo, this.navigateReason});
}

class AiAssistantException implements Exception {
  final String message;
  AiAssistantException(this.message);
  @override
  String toString() => message;
}

class AiAssistantService {
  AiAssistantService._internal();
  static final AiAssistantService _instance = AiAssistantService._internal();
  factory AiAssistantService() => _instance;

  static final HttpsCallable _callable =
  FirebaseFunctions.instance.httpsCallable(
    'aiAssistant',
    options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
  );

  static Future<AiAssistantResponse> ask({
    required String message,
    required List<ChatMessage> history,
  }) async {
    try {
      final result = await _callable.call<Map<String, dynamic>>({
        'message': message,
        'history': history.map((m) => m.toHistoryEntry()).toList(),
      });
      final data = result.data;
      return AiAssistantResponse(
        reply: data['reply'] as String? ?? '',
        navigateTo: data['navigateTo'] as String?,
        navigateReason: data['navigateReason'] as String?,
      );
    } on FirebaseFunctionsException catch (e) {
      throw AiAssistantException(e.message ?? 'The assistant is unavailable right now.');
    } catch (e) {
      throw AiAssistantException('Something went wrong: $e');
    }
  }
}