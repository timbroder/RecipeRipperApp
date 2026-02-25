import 'dart:io';
import 'package:flutter/services.dart';
import 'llm_service.dart';
import 'llm_prompts.dart';

/// LLM service using llama.cpp on Android for on-device inference.
class AndroidLlmService extends LlmService {
  static const _channel = MethodChannel('com.reciperipperapp/llama_cpp');

  @override
  String get name => 'llama.cpp (Android)';

  @override
  Future<bool> isAvailable() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Check if the model file has been downloaded.
  Future<bool> isModelDownloaded() async {
    try {
      final result = await _channel.invokeMethod<bool>('isModelDownloaded');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Download the model file. Returns true on success.
  Future<bool> downloadModel({
    void Function(double progress)? onProgress,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('downloadModel');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<LlmExtractionResult> extractRecipe(
    String text, {
    String? videoTitle,
  }) async {
    final prompt =
        LlmPrompts.fullExtractionPrompt(text, videoTitle: videoTitle);
    return _generate(prompt);
  }

  @override
  Future<LlmExtractionResult> extractRecipeFromDescription(
    String description, {
    String? videoTitle,
  }) async {
    final prompt = LlmPrompts.descriptionOnlyPrompt(
      description,
      videoTitle: videoTitle,
    );
    return _generate(prompt);
  }

  Future<LlmExtractionResult> _generate(String prompt) async {
    try {
      final response = await _channel.invokeMethod<String>(
        'generateText',
        {'prompt': prompt},
      );

      if (response == null || response.isEmpty) {
        return LlmExtractionResult.failed('Empty response from model');
      }

      return _parseResponse(response);
    } on PlatformException catch (e) {
      return LlmExtractionResult.failed('Platform error: ${e.message}');
    }
  }

  LlmExtractionResult _parseResponse(String response) {
    final json = LlmPrompts.parseResponse(response);
    if (json == null) {
      return LlmExtractionResult.failed('Failed to parse JSON response');
    }

    return LlmExtractionResult.fromJson(json);
  }
}
