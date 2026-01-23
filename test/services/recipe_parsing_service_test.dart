import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_ripper/services/recipe_parsing_service.dart';

void main() {
  group('RecipeParsingService', () {
    group('parseRecipe', () {
      test('should parse a complete recipe from transcript and OCR', () async {
        const transcript = '''
        Chocolate Chip Cookies

        2 cups all-purpose flour
        1 teaspoon baking soda
        1/2 teaspoon salt
        1 cup butter, softened
        3/4 cup sugar
        2 large eggs
        2 teaspoons vanilla extract
        2 cups chocolate chips

        Preheat oven to 375°F.
        Mix flour, baking soda, and salt in a bowl.
        Beat butter and sugar until fluffy.
        Add eggs and vanilla, beat well.
        Stir in flour mixture.
        Fold in chocolate chips.
        Drop by spoonfuls onto baking sheet.
        Bake for 10-12 minutes.
        ''';

        const ocrText = '''
        Chocolate Chip Cookies Recipe
        375°F oven temperature
        Bake 10-12 minutes
        ''';

        final recipe = await RecipeParsingService.parseRecipe(
          transcript: transcript,
          ocrText: ocrText,
          videoTitle: 'How to Make Chocolate Chip Cookies',
        );

        // Should extract title
        expect(recipe.title, isNotEmpty);
        expect(recipe.title, isNot('Untitled Recipe'));

        // Should extract ingredients
        expect(recipe.ingredients.length, greaterThanOrEqualTo(5));

        // Should have flour ingredient with quantity and unit
        final flourIngredient = recipe.ingredients.firstWhere(
          (i) => i.item.toLowerCase().contains('flour'),
        );
        expect(flourIngredient.quantity, 2.0);
        expect(flourIngredient.unit, anyOf('cup', 'cups'));

        // Should extract directions
        expect(recipe.directions.length, greaterThanOrEqualTo(5));

        // Directions should have step numbers
        for (int i = 0; i < recipe.directions.length; i++) {
          expect(recipe.directions[i].stepNumber, i + 1);
        }

        // Should have metadata
        expect(recipe.metadata, isNotNull);
        expect(recipe.metadata?.transcript, transcript);
        expect(recipe.metadata?.ocrText, ocrText);
      });

      test('should handle transcript-only recipe', () async {
        const transcript = '''
        Simple Pasta

        1 pound pasta
        2 tablespoons olive oil
        4 cloves garlic, minced
        Salt and pepper to taste

        Cook pasta according to package directions.
        Heat oil in a pan.
        Add garlic and sauté for 1 minute.
        Toss with cooked pasta.
        Season with salt and pepper.
        ''';

        final recipe = await RecipeParsingService.parseRecipe(
          transcript: transcript,
          ocrText: null,
        );

        expect(recipe.ingredients.length, greaterThanOrEqualTo(2));
        expect(recipe.directions.length, greaterThanOrEqualTo(3));
      });

      test('should handle OCR-only recipe', () async {
        const ocrText = '''
        Quick Salad

        2 cups lettuce
        1 tomato, diced
        1/2 cucumber, sliced
        2 tablespoons dressing

        Combine lettuce, tomato, and cucumber in a bowl.
        Drizzle with dressing.
        Toss to combine.
        ''';

        final recipe = await RecipeParsingService.parseRecipe(
          transcript: null,
          ocrText: ocrText,
        );

        expect(recipe.ingredients.length, greaterThanOrEqualTo(2));
        expect(recipe.directions.length, greaterThanOrEqualTo(1));
      });

      test('should deduplicate ingredients from transcript and OCR', () async {
        const transcript = '''
        2 cups flour
        1 teaspoon salt
        ''';

        const ocrText = '''
        2 cups flour
        1 tsp salt
        ''';

        final recipe = await RecipeParsingService.parseRecipe(
          transcript: transcript,
          ocrText: ocrText,
        );

        // Should have only 2 ingredients, not 4 (deduplication)
        expect(recipe.ingredients.length, lessThanOrEqualTo(2));
      });

      test('should handle empty input gracefully', () async {
        final recipe = await RecipeParsingService.parseRecipe(
          transcript: null,
          ocrText: null,
        );

        expect(recipe.title, 'Untitled Recipe');
        expect(recipe.ingredients, isEmpty);
        expect(recipe.directions, isEmpty);
      });

      test('should extract video metadata', () async {
        const transcript = 'Simple recipe with no details';

        final recipe = await RecipeParsingService.parseRecipe(
          transcript: transcript,
          ocrText: null,
          videoTitle: 'My Cooking Video',
          sourceUrl: 'https://youtube.com/watch?v=test',
          sourcePlatform: 'YouTube',
          thumbnailPath: '/path/to/thumb.jpg',
        );

        expect(recipe.sourceUrl, 'https://youtube.com/watch?v=test');
        expect(recipe.sourcePlatform, 'YouTube');
        expect(recipe.thumbnailPath, '/path/to/thumb.jpg');
      });
    });

    group('validateRecipe', () {
      test('should return no warnings for valid recipe', () async {
        const transcript = '''
        Test Recipe

        2 cups flour
        1 teaspoon salt

        Mix flour and salt.
        Bake for 30 minutes.
        ''';

        final recipe = await RecipeParsingService.parseRecipe(
          transcript: transcript,
          ocrText: null,
        );

        final warnings = RecipeParsingService.validateRecipe(recipe);
        expect(warnings, isEmpty);
      });

      test('should warn about missing ingredients', () async {
        const transcript = '''
        Test Recipe

        Mix everything together.
        Bake for 30 minutes.
        ''';

        final recipe = await RecipeParsingService.parseRecipe(
          transcript: transcript,
          ocrText: null,
        );

        final warnings = RecipeParsingService.validateRecipe(recipe);
        expect(
          warnings.any((w) => w.contains('no ingredients')),
          true,
        );
      });

      test('should warn about missing directions', () async {
        const transcript = '''
        Test Recipe

        2 cups flour
        1 teaspoon salt
        ''';

        final recipe = await RecipeParsingService.parseRecipe(
          transcript: transcript,
          ocrText: null,
        );

        final warnings = RecipeParsingService.validateRecipe(recipe);
        expect(
          warnings.any((w) => w.contains('no directions')),
          true,
        );
      });
    });

    group('getParsingStats', () {
      test('should return parsing statistics', () async {
        const transcript = '''
        Test Recipe

        2 cups flour
        1 tablespoon salt
        3 eggs

        Preheat oven to 350°F.
        Mix ingredients.
        Bake for 30 minutes.
        ''';

        final recipe = await RecipeParsingService.parseRecipe(
          transcript: transcript,
          ocrText: null,
        );

        final stats = RecipeParsingService.getParsingStats(recipe);

        expect(stats['totalIngredients'], greaterThan(0));
        expect(stats['totalDirections'], greaterThan(0));
        expect(stats['ingredientsWithQuantity'], greaterThan(0));
        expect(stats['ingredientsWithUnit'], greaterThan(0));
        expect(stats['directionsWithTimeRef'], greaterThan(0));
        expect(stats['directionsWithTempRef'], greaterThan(0));
        expect(stats['hasTitle'], true);
      });
    });
  });
}
