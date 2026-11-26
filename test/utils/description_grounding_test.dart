import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_ripper/models/ingredient.dart';
import 'package:recipe_ripper/utils/description_grounding.dart';

Ingredient _ing(String item, [double? quantity]) =>
    Ingredient(item: item, quantity: quantity);

// From https://www.youtube.com/shorts/-xQJKP3mne8: a dish name and macros,
// but no ingredient list.
const _promoDescription = '''
🍗🥓 Chicken Bacon Fried Rice
A high-protein twist on a takeout classic — packed with flavor, easy to prep in bulk.
Per Serving Macros:
530 Calories
56g Protein
37g Carbs
14g Fats
Makes 5 Servings''';

const _recipeDescription = '''
Ingredients:
2 cups all-purpose flour
1 cup sugar
3 large eggs
1/2 cup butter, melted
Bake at 350F for 30 minutes.''';

void main() {
  group('DescriptionGrounding', () {
    test('rejects ingredients invented from the dish name', () {
      // What Foundation Models returned for the promo description.
      final result = DescriptionGrounding.check([
        _ing('chicken'),
        _ing('bacon'),
        _ing('rice'),
        _ing('egg'),
        _ing('green onions'),
        _ing('soy sauce'),
        _ing('sesame oil'),
      ], _promoDescription);

      expect(result.isGrounded, isFalse);
      expect(result.grounded, 3);
      expect(result.total, 7);
      expect(result.ungrounded,
          ['egg', 'green onions', 'soy sauce', 'sesame oil']);
    });

    test('rejects dish-name words without quantities', () {
      final result = DescriptionGrounding.check(
        [_ing('chicken'), _ing('bacon'), _ing('rice')],
        _promoDescription,
      );

      expect(result.grounded, 3);
      expect(result.quantified, 0);
      expect(result.isGrounded, isFalse);
      expect(result.rejectionReason, contains('quantities'));
    });

    test('accepts a recipe listed in the description', () {
      final result = DescriptionGrounding.check([
        _ing('all-purpose flour', 2),
        _ing('sugar', 1),
        _ing('eggs', 3),
        _ing('butter', 0.5),
      ], _recipeDescription);

      expect(result.isGrounded, isTrue);
      expect(result.grounded, 4);
      expect(result.quantified, 4);
      expect(result.rejectionReason, isNull);
    });

    test('tolerates one unlisted ingredient out of five', () {
      final result = DescriptionGrounding.check([
        _ing('flour', 2),
        _ing('sugar', 1),
        _ing('eggs', 3),
        _ing('butter', 0.5),
        _ing('vanilla extract', 1),
      ], _recipeDescription);

      expect(result.grounded, 4);
      expect(result.isGrounded, isTrue);
    });

    test('matches plurals and ignores descriptors', () {
      final result = DescriptionGrounding.check(
        [_ing('tomato', 2), _ing('fresh chopped berry', 1)],
        '2 tomatoes and 1 cup berries',
      );

      expect(result.grounded, 2);
      expect(result.isGrounded, isTrue);
    });

    test('rejects an empty ingredient list', () {
      final result = DescriptionGrounding.check([], _recipeDescription);
      expect(result.isGrounded, isFalse);
      expect(result.rejectionReason, 'no ingredients');
    });
  });
}
