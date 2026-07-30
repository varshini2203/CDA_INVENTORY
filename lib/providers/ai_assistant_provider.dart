// lib/providers/ai_assistant_provider.dart
//
// Same ChangeNotifierProvider pattern as BillsProvider/ThemeProvider —
// add this one to the existing MultiProvider list in main.dart alongside
// the others (that's the one line of main.dart this feature needs; no
// routes are touched).

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../services/ai_assistant_service.dart';

class AiAssistantProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _error;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isLoading) return;

    _messages.add(ChatMessage(role: ChatRole.user, content: trimmed, timestamp: DateTime.now()));
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await AiAssistantService.ask(
        message: trimmed,
        history: _messages,
      );
      _messages.add(ChatMessage(
        role: ChatRole.assistant,
        content: response.reply,
        timestamp: DateTime.now(),
        navigateTo: response.navigateTo,
        navigateReason: response.navigateReason,
      ));
    } on AiAssistantException catch (e) {
      _error = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _messages.clear();
    _error = null;
    notifyListeners();
  }
}