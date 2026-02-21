import 'dart:io';
import 'package:flutter/services.dart';
import 'llm_service.dart';
import 'llm_prompts.dart';

/// LLM service using Apple Foundation Models (iOS 26+).
class AppleLlmService extends LlmService {
  static const _channel =
      MethodChannel('com.reciperipperapp/foundation_models');

  @override
  String get name => 'Apple Foundation Models';

  @override
  Future<bool> isAvailable() async {
    if (!Platform.isIOS) return false;
    try {
      final result = await _channel.invokeMethod<Map>('isAvailable');
      if (result == null) return false;
      return result['available'] == true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<LlmExtractionResult> extractRecipe(
    String text, {
    String? videoTitle,
  }) async {
    return _generate(
      instructions: LlmPrompts.fullExtractionInstructions(),
      prompt: LlmPrompts.fullExtractionUserPrompt(text, videoTitle: videoTitle),
    );
  }

  @override
  Future<LlmExtractionResult> extractRecipeFromDescription(
    String description, {
    String? videoTitle,
  }) async {
    return _generate(
      instructions: LlmPrompts.descriptionOnlyInstructions(),
      prompt: LlmPrompts.descriptionOnlyUserPrompt(
        description,
        videoTitle: videoTitle,
      ),
    );
  }

  Future<LlmExtractionResult> _generate({
    required String instructions,
    required String prompt,
  }) async {
    try {
      final response = await _channel.invokeMethod<String>(
        'generateText',
        {
          'prompt': prompt,
          'instructions': instructions,
        },
      );

      if (response == null || response.isEmpty) {
        return LlmExtractionResult.failed('Empty response from model');
      }

      return _parseResponse(response);
    } on PlatformException catch (e) {
      if (e.code == 'CONTEXT_OVERFLOW') {
        return LlmExtractionResult.failed('context_overflow');
      }
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
