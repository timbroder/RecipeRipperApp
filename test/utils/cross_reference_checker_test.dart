import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_ripper/models/ingredient.dart';
import 'package:recipe_ripper/models/direction.dart';
import 'package:recipe_ripper/utils/cross_reference_checker.dart';

void main() {
  group('CrossReferenceChecker', () {
    group('check', () {
      test('returns empty result for empty inputs', () {
        final result = CrossReferenceChecker.check(
          ingredients: [],
          directions: [],
        );
        expect(result.unusedIngredients, isEmpty);
        expect(result.missingIngredients, isEmpty);
        expect(result.warnings, isEmpty);
        expect(result.autoAddedIngredients, isEmpty);
      });

      test('finds unused ingredients', () {
        final ingredients = [
          Ingredient(item: 'flour', order: 0),
          Ingredient(item: 'sugar', order: 1),
          Ingredient(item: 'cinnamon', order: 2),
        ];
        final directions = [
          Direction(stepNumber: 1, text: 'Mix the flour and sugar together'),
        ];

        final result = CrossReferenceChecker.check(
          ingredients: ingredients,
          directions: directions,
        );

        expect(result.unusedIngredients, contains('cinnamon'));
        expect(result.unusedIngredients, isNot(contains('flour')));
        expect(result.unusedIngredients, isNot(contains('sugar')));
      });

      test('finds missing ingredients mentioned in directions', () {
        final ingredients = [
          Ingredient(item: 'flour', order: 0),
        ];
        final directions = [
          Direction(
            stepNumber: 1,
            text: 'Mix the flour with butter and salt',
          ),
        ];

        final result = CrossReferenceChecker.check(
          ingredients: ingredients,
          directions: directions,
        );

        expect(result.missingIngredients, contains('butter'));
        expect(result.missingIngredients, contains('salt'));
      });

      test('auto-adds missing ingredients', () {
        final ingredients = [
          Ingredient(item: 'flour', order: 0),
        ];
        final directions = [
          Direction(stepNumber: 1, text: 'Add butter to the flour'),
        ];

        final result = CrossReferenceChecker.check(
          ingredients: ingredients,
          directions: directions,
        );

        expect(result.autoAddedIngredients, hasLength(1));
        expect(result.autoAddedIngredients.first.item, equals('butter'));
        expect(result.autoAddedIngredients.first.quantity, isNull);
        expect(result.autoAddedIngredients.first.unit, isNull);
      });

      test('handles plural normalization', () {
        final ingredients = [
          Ingredient(item: 'tomatoes', order: 0),
          Ingredient(item: 'berries', order: 1),
        ];
        final directions = [
          Direction(
            stepNumber: 1,
            text: 'Dice the tomato and add the berry compote',
          ),
        ];

        final result = CrossReferenceChecker.check(
          ingredients: ingredients,
          directions: directions,
        );

        // Tomatoes/tomato and berries/berry should match
        expect(result.unusedIngredients, isEmpty);
      });

      test('handles multi-word food items', () {
        final ingredients = [
          Ingredient(item: 'olive oil', order: 0),
          Ingredient(item: 'soy sauce', order: 1),
        ];
        final directions = [
          Direction(
            stepNumber: 1,
            text: 'Heat olive oil in a pan and add soy sauce',
          ),
        ];

        final result = CrossReferenceChecker.check(
          ingredients: ingredients,
          directions: directions,
        );

        expect(result.unusedIngredients, isEmpty);
      });

      test('generates proper warnings', () {
        final ingredients = [
          Ingredient(item: 'flour', order: 0),
          Ingredient(item: 'nutmeg', order: 1),
        ];
        final directions = [
          Direction(
            stepNumber: 1,
            text: 'Mix the flour and sugar together',
          ),
        ];

        final result = CrossReferenceChecker.check(
          ingredients: ingredients,
          directions: directions,
        );

        expect(
          result.warnings,
          anyElement(contains('Unused ingredient: nutmeg')),
        );
        expect(
          result.warnings,
          anyElement(contains('Missing ingredient: sugar')),
        );
      });

      test('handles all ingredients used', () {
        final ingredients = [
          Ingredient(item: 'flour', order: 0),
          Ingredient(item: 'sugar', order: 1),
          Ingredient(item: 'butter', order: 2),
        ];
        final directions = [
          Direction(
            stepNumber: 1,
            text: 'Mix flour and sugar, then add melted butter',
          ),
        ];

        final result = CrossReferenceChecker.check(
          ingredients: ingredients,
          directions: directions,
        );

        expect(result.unusedIngredients, isEmpty);
      });
    });
  });
}
