import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_ripper/services/llm/llm_service.dart';

void main() {
  group('LlmExtractionResult', () {
    test('meetsMinimumQuality returns true with sufficient data', () {
      final result = LlmExtractionResult(
        title: 'Test Recipe',
        ingredients: [
          LlmIngredient(item: 'flour', quantity: '2', unit: 'cups'),
          LlmIngredient(item: 'sugar', quantity: '1', unit: 'cup'),
        ],
        directions: ['Mix together'],
        success: true,
      );
      expect(result.meetsMinimumQuality, isTrue);
    });

    test('meetsMinimumQuality returns false with too few ingredients', () {
      final result = LlmExtractionResult(
        title: 'Test Recipe',
        ingredients: [
          LlmIngredient(item: 'flour'),
        ],
        directions: ['Mix together'],
        success: true,
      );
      expect(result.meetsMinimumQuality, isFalse);
    });

    test('meetsMinimumQuality returns false with no directions', () {
      final result = LlmExtractionResult(
        title: 'Test Recipe',
        ingredients: [
          LlmIngredient(item: 'flour'),
          LlmIngredient(item: 'sugar'),
        ],
        directions: [],
        success: true,
      );
      expect(result.meetsMinimumQuality, isFalse);
    });

    test('failed constructor creates failed result', () {
      final result = LlmExtractionResult.failed('Something went wrong');
      expect(result.success, isFalse);
      expect(result.error, equals('Something went wrong'));
      expect(result.meetsMinimumQuality, isFalse);
    });

    group('fromJson', () {
      test('parses flat string ingredients', () {
        final result = LlmExtractionResult.fromJson({
          'title': 'Test',
          'ingredients': ['2 cups flour', '1 tsp salt'],
          'directions': ['Mix together'],
        });
        expect(result.success, isTrue);
        expect(result.ingredients.length, equals(2));
        expect(result.ingredients[0].item, equals('2 cups flour'));
        expect(result.ingredients[0].quantity, isNull);
        expect(result.ingredients[0].unit, isNull);
      });

      test('parses structured ingredients', () {
        final result = LlmExtractionResult.fromJson({
          'title': 'Test',
          'ingredients': [
            {'quantity': '2', 'unit': 'cups', 'item': 'flour', 'notes': null},
          ],
          'directions': ['Mix'],
        });
        expect(result.success, isTrue);
        expect(result.ingredients[0].quantity, equals('2'));
        expect(result.ingredients[0].unit, equals('cups'));
        expect(result.ingredients[0].item, equals('flour'));
      });

      test('handles missing fields gracefully', () {
        final result = LlmExtractionResult.fromJson({
          'title': null,
          'ingredients': [],
          'directions': [],
        });
        expect(result.success, isTrue);
        expect(result.title, isNull);
        expect(result.ingredients, isEmpty);
        expect(result.directions, isEmpty);
      });

      test('handles invalid data with failed result', () {
        final result = LlmExtractionResult.fromJson({
          'ingredients': 'not a list',
        });
        expect(result.success, isFalse);
      });
    });
  });

  group('LlmIngredient', () {
    test('creates ingredient with all fields', () {
      final ingredient = LlmIngredient(
        quantity: '2',
        unit: 'cups',
        item: 'flour',
        notes: 'sifted',
      );
      expect(ingredient.quantity, equals('2'));
      expect(ingredient.unit, equals('cups'));
      expect(ingredient.item, equals('flour'));
      expect(ingredient.notes, equals('sifted'));
    });

    test('creates ingredient with only item', () {
      final ingredient = LlmIngredient(item: 'salt');
      expect(ingredient.quantity, isNull);
      expect(ingredient.unit, isNull);
      expect(ingredient.item, equals('salt'));
      expect(ingredient.notes, isNull);
    });
  });
}
