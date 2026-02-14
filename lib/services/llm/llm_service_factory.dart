import 'dart:io';
import 'llm_service.dart';
import 'apple_llm_service.dart';
import 'android_llm_service.dart';

/// Factory for creating the appropriate LLM service for the current platform.
class LlmServiceFactory {
  /// Create an LLM service for the current platform.
  /// Returns null if no LLM service is available.
  // TODO: Premium feature — add CloudLlmService as alternative/fallback
  static LlmService? create() {
    if (Platform.isIOS) return AppleLlmService();
    if (Platform.isAndroid) return AndroidLlmService();
    return null;
  }
}
