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

    group('title-based cross-referencing', () {
      test('auto-adds food words from title missing in ingredients', () {
        final ingredients = [
          Ingredient(item: 'cream', order: 0),
          Ingredient(item: 'cheese', order: 1),
        ];
        final directions = [
          Direction(stepNumber: 1, text: 'Melt cream and cheese together'),
        ];

        final result = CrossReferenceChecker.check(
          ingredients: ingredients,
          directions: directions,
          title: 'Cream of Broccoli Pasta',
        );

        expect(result.missingIngredients, contains('broccoli'));
        expect(result.missingIngredients, contains('pasta'));
        expect(result.autoAddedIngredients.length, greaterThanOrEqualTo(2));
        expect(
          result.autoAddedIngredients.map((i) => i.item),
          contains('broccoli'),
        );
        expect(
          result.autoAddedIngredients.map((i) => i.item),
          contains('pasta'),
        );
      });

      test('does not duplicate ingredients already in the list', () {
        final ingredients = [
          Ingredient(item: 'broccoli', order: 0),
          Ingredient(item: 'pasta', order: 1),
          Ingredient(item: 'cream', order: 2),
        ];
        final directions = [
          Direction(stepNumber: 1, text: 'Cook the broccoli and pasta'),
          Direction(stepNumber: 2, text: 'Add cream'),
        ];

        final result = CrossReferenceChecker.check(
          ingredients: ingredients,
          directions: directions,
          title: 'Cream of Broccoli Pasta',
        );

        expect(result.missingIngredients, isEmpty);
        expect(result.autoAddedIngredients, isEmpty);
      });

      test('handles null or empty title gracefully', () {
        final ingredients = [
          Ingredient(item: 'flour', order: 0),
        ];
        final directions = [
          Direction(stepNumber: 1, text: 'Mix the flour'),
        ];

        final resultNull = CrossReferenceChecker.check(
          ingredients: ingredients,
          directions: directions,
          title: null,
        );
        expect(resultNull.missingIngredients, isEmpty);

        final resultEmpty = CrossReferenceChecker.check(
          ingredients: ingredients,
          directions: directions,
          title: '',
        );
        expect(resultEmpty.missingIngredients, isEmpty);
      });

      test('detects multi-word items from title', () {
        final ingredients = [
          Ingredient(item: 'chicken', order: 0),
        ];
        final directions = [
          Direction(stepNumber: 1, text: 'Cook the chicken'),
        ];

        final result = CrossReferenceChecker.check(
          ingredients: ingredients,
          directions: directions,
          title: 'Chicken with Green Beans',
        );

        expect(result.missingIngredients, contains('green beans'));
        expect(
          result.autoAddedIngredients.map((i) => i.item),
          contains('green beans'),
        );
      });
    });

    group('deduplication', () {
      test('skips multi-word item when keyword component is in ingredient text',
          () {
        // "lemon juice" in directions should not be auto-added when
        // "Juice of 1 lemon" already covers it (ingredient text contains "lemon")
        final ingredients = [
          Ingredient(item: 'Juice of 1 lemon', order: 0),
          Ingredient(item: 'flour', order: 1),
        ];
        final directions = [
          Direction(
            stepNumber: 1,
            text: 'Add the lemon juice to the flour',
          ),
        ];

        final result = CrossReferenceChecker.check(
          ingredients: ingredients,
          directions: directions,
        );

        expect(
          result.autoAddedIngredients.map((i) => i.item),
          isNot(contains('lemon juice')),
        );
        expect(
          result.autoAddedIngredients.map((i) => i.item),
          isNot(contains('lemon')),
        );
      });

      test('removes single-word items covered by auto-added multi-word items',
          () {
        // If "edamame pasta" is auto-added, "edamame" and "pasta" should
        // not also be added separately
        final ingredients = [
          Ingredient(item: 'broccoli', order: 0),
        ];
        final directions = [
          Direction(
            stepNumber: 1,
            text: 'Cook edamame pasta and add broccoli',
          ),
        ];

        final result = CrossReferenceChecker.check(
          ingredients: ingredients,
          directions: directions,
        );

        final addedItems = result.autoAddedIngredients.map((i) => i.item);
        expect(addedItems, contains('edamame pasta'));
        // Single-word components should be suppressed
        expect(addedItems, isNot(contains('edamame')));
        expect(addedItems, isNot(contains('pasta')));
      });

      test('skips food word that appears in existing ingredient text', () {
        // "cream" should not be auto-added if an ingredient is "cream cheese"
        final ingredients = [
          Ingredient(item: 'cream cheese', order: 0),
        ];
        final directions = [
          Direction(stepNumber: 1, text: 'Spread the cream cheese'),
        ];

        final result = CrossReferenceChecker.check(
          ingredients: ingredients,
          directions: directions,
          title: 'Cream Cheese Dip',
        );

        expect(
          result.autoAddedIngredients.map((i) => i.item),
          isNot(contains('cream')),
        );
      });
    });

    group('sourceText cross-referencing', () {
      test('auto-adds food words from raw source text', () {
        // The transcript may mention "beans" even if the LLM directions
        // only say "edamame pasta"
        final ingredients = [
          Ingredient(item: 'edamame pasta', order: 0),
          Ingredient(item: 'broccoli', order: 1),
        ];
        final directions = [
          Direction(stepNumber: 1, text: 'Cook the edamame pasta'),
          Direction(stepNumber: 2, text: 'Add broccoli'),
        ];

        final result = CrossReferenceChecker.check(
          ingredients: ingredients,
          directions: directions,
          sourceText:
              'I have some beans and broccoli. Using edamame pasta today.',
        );

        expect(
          result.autoAddedIngredients.map((i) => i.item),
          contains('bean'),
        );
      });

      test('does not duplicate ingredients already present', () {
        final ingredients = [
          Ingredient(item: 'broccoli', order: 0),
          Ingredient(item: 'pasta', order: 1),
        ];
        final directions = [
          Direction(stepNumber: 1, text: 'Cook the broccoli and pasta'),
        ];

        final result = CrossReferenceChecker.check(
          ingredients: ingredients,
          directions: directions,
          sourceText: 'I love broccoli and pasta together',
        );

        expect(result.autoAddedIngredients, isEmpty);
      });

      test('handles null sourceText gracefully', () {
        final ingredients = [
          Ingredient(item: 'flour', order: 0),
        ];
        final directions = [
          Direction(stepNumber: 1, text: 'Mix the flour'),
        ];

        final result = CrossReferenceChecker.check(
          ingredients: ingredients,
          directions: directions,
          sourceText: null,
        );
        expect(result.missingIngredients, isEmpty);
      });
    });
  });
}
