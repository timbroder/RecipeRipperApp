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
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
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

    try {
      final title = json['title'] as String?;
      final ingredientsList = json['ingredients'] as List<dynamic>? ?? [];
      final directionsList = json['directions'] as List<dynamic>? ?? [];

      final ingredients = ingredientsList.map((item) {
        final map = item as Map<String, dynamic>;
        return LlmIngredient(
          quantity: map['quantity']?.toString(),
          unit: map['unit'] as String?,
          item: map['item'] as String? ?? '',
          notes: map['notes'] as String?,
        );
      }).toList();

      final directions = directionsList.map((d) => d.toString()).toList();

      return LlmExtractionResult(
        title: title,
        ingredients: ingredients,
        directions: directions,
        success: true,
      );
    } catch (e) {
      return LlmExtractionResult.failed('Error parsing result: $e');
    }
  }
}
