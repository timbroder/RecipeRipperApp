import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_ripper/models/recipe.dart';
import 'package:recipe_ripper/models/ingredient.dart';
import 'package:recipe_ripper/models/direction.dart';

void main() {
  group('Recipe', () {
    test('creates recipe with required fields', () {
      final recipe = Recipe(title: 'Test Recipe');

      expect(recipe.title, equals('Test Recipe'));
      expect(recipe.ingredients, isEmpty);
      expect(recipe.directions, isEmpty);
      expect(recipe.createdAt, isNotNull);
      expect(recipe.updatedAt, isNotNull);
    });

    test('toJson() serializes correctly', () {
      final recipe = Recipe(
        title: 'Test Recipe',
        sourceUrl: 'https://example.com/video',
        sourcePlatform: 'YouTube',
        ingredients: [
          Ingredient(item: 'flour', quantity: 2, unit: 'cups'),
        ],
        directions: [
          Direction(stepNumber: 1, text: 'Mix ingredients'),
        ],
      );

      final json = recipe.toJson();

      expect(json['title'], equals('Test Recipe'));
      expect(json['sourceUrl'], equals('https://example.com/video'));
      expect(json['sourcePlatform'], equals('YouTube'));
      expect(json['ingredients'], hasLength(1));
      expect(json['directions'], hasLength(1));
    });

    test('fromJson() deserializes correctly', () {
      final json = {
        'title': 'Test Recipe',
        'sourceUrl': 'https://example.com/video',
        'sourcePlatform': 'YouTube',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'ingredients': [
          {
            'item': 'flour',
            'quantity': 2.0,
            'unit': 'cups',
            'order': 0,
          },
        ],
        'directions': [
          {
            'stepNumber': 1,
            'text': 'Mix ingredients',
          },
        ],
      };

      final recipe = Recipe.fromJson(json);

      expect(recipe.title, equals('Test Recipe'));
      expect(recipe.sourceUrl, equals('https://example.com/video'));
      expect(recipe.sourcePlatform, equals('YouTube'));
      expect(recipe.ingredients, hasLength(1));
      expect(recipe.directions, hasLength(1));
    });

    test('copyWith() updates only specified fields', () {
      final original = Recipe(
        title: 'Original Title',
        sourceUrl: 'https://example.com/video',
      );

      final updated = original.copyWith(title: 'Updated Title');

      expect(updated.title, equals('Updated Title'));
      expect(updated.sourceUrl, equals('https://example.com/video'));
      expect(updated.id, equals(original.id));
    });
  });

  group('RecipeMetadata', () {
    test('toJson() and fromJson() work correctly', () {
      final metadata = RecipeMetadata(
        transcript: 'Test transcript',
        ocrText: 'Test OCR text',
        processingTimeSeconds: 120,
        videoDuration: '10:30',
        frameCount: 180,
      );

      final json = metadata.toJson();
      final restored = RecipeMetadata.fromJson(json);

      expect(restored.transcript, equals(metadata.transcript));
      expect(restored.ocrText, equals(metadata.ocrText));
      expect(
        restored.processingTimeSeconds,
        equals(metadata.processingTimeSeconds),
      );
      expect(restored.videoDuration, equals(metadata.videoDuration));
      expect(restored.frameCount, equals(metadata.frameCount));
    });
  });
}
