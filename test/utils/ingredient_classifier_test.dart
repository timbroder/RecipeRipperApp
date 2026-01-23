import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_ripper_app/utils/ingredient_classifier.dart';

void main() {
  group('IngredientClassifier', () {
    group('classifyAsIngredient', () {
      test('should score high for typical ingredient lines', () {
        expect(
          IngredientClassifier.classifyAsIngredient('2 cups flour'),
          greaterThan(0.5),
        );
        expect(
          IngredientClassifier.classifyAsIngredient('1 tablespoon salt'),
          greaterThan(0.5),
        );
        expect(
          IngredientClassifier.classifyAsIngredient('3 large eggs'),
          greaterThan(0.5),
        );
        expect(
          IngredientClassifier.classifyAsIngredient('½ cup sugar'),
          greaterThan(0.5),
        );
      });

      test('should score low for direction-like lines', () {
        expect(
          IngredientClassifier.classifyAsIngredient('Mix the flour and sugar'),
          lessThan(0.5),
        );
        expect(
          IngredientClassifier.classifyAsIngredient('Bake at 350°F for 30 minutes'),
          lessThan(0.5),
        );
        expect(
          IngredientClassifier.classifyAsIngredient('Add the eggs one at a time'),
          lessThan(0.5),
        );
      });

      test('should handle lines with ingredient keywords', () {
        expect(
          IngredientClassifier.classifyAsIngredient('butter'),
          greaterThan(0.3),
        );
        expect(
          IngredientClassifier.classifyAsIngredient('salt and pepper'),
          greaterThan(0.3),
        );
      });

      test('should score low for very short or empty lines', () {
        expect(
          IngredientClassifier.classifyAsIngredient(''),
          0.0,
        );
        expect(
          IngredientClassifier.classifyAsIngredient('a'),
          0.0,
        );
      });

      test('should penalize very long text', () {
        final longText = 'This is a very long line that contains way too much '
            'text to be a simple ingredient and is probably a direction or '
            'some other type of content that should not be classified as an '
            'ingredient in any reasonable recipe parsing scenario';
        expect(
          IngredientClassifier.classifyAsIngredient(longText),
          lessThan(0.5),
        );
      });
    });

    group('parseIngredient', () {
      test('should parse quantity and unit', () {
        final result = IngredientClassifier.parseIngredient('2 cups flour');
        expect(result['quantity'], 2.0);
        expect(result['unit'], 'cup');
        expect(result['item'], 'flour');
      });

      test('should parse fractional quantities', () {
        final result = IngredientClassifier.parseIngredient('½ cup sugar');
        expect(result['quantity'], 0.5);
        expect(result['unit'], 'cup');
        expect(result['item'], 'sugar');
      });

      test('should parse mixed numbers', () {
        final result = IngredientClassifier.parseIngredient('1 1/2 tablespoons vanilla');
        expect(result['quantity'], closeTo(1.5, 0.01));
        expect(result['unit'], 'tablespoon');
        expect(result['item'], 'vanilla');
      });

      test('should handle ingredients without units', () {
        final result = IngredientClassifier.parseIngredient('3 large eggs');
        expect(result['quantity'], 3.0);
        expect(result['item'], 'large eggs');
      });

      test('should extract notes in parentheses', () {
        final result =
            IngredientClassifier.parseIngredient('2 cups flour (sifted)');
        expect(result['quantity'], 2.0);
        expect(result['unit'], 'cup');
        expect(result['item'], 'flour');
        expect(result['notes'], 'sifted');
      });

      test('should handle ingredients without quantity', () {
        final result = IngredientClassifier.parseIngredient('salt and pepper to taste');
        expect(result['quantity'], null);
        expect(result['item'], 'salt and pepper to taste');
      });

      test('should normalize units', () {
        final result = IngredientClassifier.parseIngredient('2 tbsp butter');
        expect(result['unit'], 'tablespoon');
      });

      test('should handle complex ingredient descriptions', () {
        final result = IngredientClassifier.parseIngredient(
          '1 cup fresh strawberries (hulled and sliced)',
        );
        expect(result['quantity'], 1.0);
        expect(result['unit'], 'cup');
        expect(result['item'], 'fresh strawberries');
        expect(result['notes'], 'hulled and sliced');
      });
    });
  });
}
