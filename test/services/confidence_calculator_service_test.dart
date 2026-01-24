import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_ripper/models/confidence_score.dart';
import 'package:recipe_ripper/models/ingredient.dart';
import 'package:recipe_ripper/models/direction.dart';
import 'package:recipe_ripper/models/recipe.dart';
import 'package:recipe_ripper/services/confidence_calculator_service.dart';

void main() {
  group('ConfidenceCalculatorService', () {
    group('calculate', () {
      test('returns low confidence for empty recipe', () {
        final recipe = Recipe(
          title: 'Untitled Recipe',
          ingredients: [],
          directions: [],
        );

        final score = ConfidenceCalculatorService.calculate(recipe);

        expect(score.level, ConfidenceLevel.low);
        expect(score.overall, lessThan(0.40));
      });

      test('returns higher confidence for recipe with many ingredients', () {
        final recipe = Recipe(
          title: 'Test Recipe',
          ingredients: [
            Ingredient(item: 'flour', quantity: 2.0, unit: 'cups', order: 0),
            Ingredient(item: 'sugar', quantity: 1.0, unit: 'cup', order: 1),
            Ingredient(item: 'butter', quantity: 0.5, unit: 'cup', order: 2),
            Ingredient(item: 'eggs', quantity: 2.0, order: 3),
            Ingredient(item: 'vanilla', quantity: 1.0, unit: 'tsp', order: 4),
            Ingredient(item: 'salt', quantity: 0.5, unit: 'tsp', order: 5),
          ],
          directions: [],
        );

        final score = ConfidenceCalculatorService.calculate(recipe);

        expect(score.ingredientScore, greaterThan(0.5));
      });

      test('returns higher confidence for recipe with quality directions', () {
        final recipe = Recipe(
          title: 'Test Recipe',
          ingredients: [],
          directions: [
            Direction(stepNumber: 1, text: 'Preheat the oven to 350°F.'),
            Direction(
                stepNumber: 2, text: 'Mix the dry ingredients in a bowl.'),
            Direction(
                stepNumber: 3, text: 'Beat the eggs and sugar for 5 minutes.'),
            Direction(stepNumber: 4, text: 'Fold in the flour mixture gently.'),
            Direction(stepNumber: 5, text: 'Bake for 25 to 30 minutes.'),
          ],
        );

        final score = ConfidenceCalculatorService.calculate(recipe);

        expect(score.directionScore, greaterThan(0.5));
      });

      test('returns very high confidence for complete recipe with metadata',
          () {
        final recipe = Recipe(
          title: 'Chocolate Chip Cookies',
          ingredients: [
            Ingredient(item: 'flour', quantity: 2.0, unit: 'cups', order: 0),
            Ingredient(item: 'sugar', quantity: 1.0, unit: 'cup', order: 1),
            Ingredient(item: 'butter', quantity: 0.5, unit: 'cup', order: 2),
            Ingredient(item: 'eggs', quantity: 2.0, order: 3),
            Ingredient(item: 'vanilla', quantity: 1.0, unit: 'tsp', order: 4),
            Ingredient(item: 'salt', quantity: 0.5, unit: 'tsp', order: 5),
            Ingredient(
                item: 'chocolate chips', quantity: 2.0, unit: 'cups', order: 6),
          ],
          directions: [
            Direction(stepNumber: 1, text: 'Preheat the oven to 375°F.'),
            Direction(stepNumber: 2, text: 'Mix flour, baking soda, and salt.'),
            Direction(
                stepNumber: 3, text: 'Beat butter and sugar until fluffy.'),
            Direction(stepNumber: 4, text: 'Add eggs and vanilla extract.'),
            Direction(stepNumber: 5, text: 'Fold in chocolate chips.'),
            Direction(stepNumber: 6, text: 'Bake for 10 to 12 minutes.'),
          ],
          metadata: RecipeMetadata(
            transcript: 'A' * 600, // Long transcript
            ocrText: 'B' * 300, // Good OCR text
            frameCount: 60,
          ),
        );

        final score = ConfidenceCalculatorService.calculate(recipe);

        expect(
            score.level, anyOf(ConfidenceLevel.high, ConfidenceLevel.veryHigh));
        expect(score.overall, greaterThan(0.65));
      });

      test('explanation includes ingredient count', () {
        final recipe = Recipe(
          title: 'Test Recipe',
          ingredients: [
            Ingredient(item: 'flour', quantity: 2.0, unit: 'cups', order: 0),
            Ingredient(item: 'sugar', quantity: 1.0, unit: 'cup', order: 1),
            Ingredient(item: 'butter', quantity: 0.5, unit: 'cup', order: 2),
            Ingredient(item: 'eggs', quantity: 2.0, order: 3),
            Ingredient(item: 'vanilla', quantity: 1.0, unit: 'tsp', order: 4),
          ],
          directions: [
            Direction(stepNumber: 1, text: 'Mix all ingredients together.'),
            Direction(stepNumber: 2, text: 'Bake at 350°F for 20 minutes.'),
          ],
        );

        final score = ConfidenceCalculatorService.calculate(recipe);

        expect(score.explanation, contains('5 ingredients'));
      });

      test('explanation mentions limited extraction for empty recipe', () {
        final recipe = Recipe(
          title: 'Untitled Recipe',
          ingredients: [],
          directions: [],
        );

        final score = ConfidenceCalculatorService.calculate(recipe);

        expect(score.explanation.toLowerCase(), contains('no ingredients'));
      });

      test('data quality score considers metadata', () {
        final recipeWithMetadata = Recipe(
          title: 'Test Recipe',
          ingredients: [],
          directions: [],
          metadata: RecipeMetadata(
            transcript: 'A' * 1000,
            ocrText: 'B' * 500,
            frameCount: 100,
          ),
        );

        final recipeWithoutMetadata = Recipe(
          title: 'Untitled Recipe',
          ingredients: [],
          directions: [],
        );

        final scoreWith =
            ConfidenceCalculatorService.calculate(recipeWithMetadata);
        final scoreWithout =
            ConfidenceCalculatorService.calculate(recipeWithoutMetadata);

        expect(scoreWith.dataQualityScore,
            greaterThan(scoreWithout.dataQualityScore));
      });

      test('ingredients with quantities score higher', () {
        final recipeWithQuantities = Recipe(
          title: 'Test Recipe',
          ingredients: [
            Ingredient(item: 'flour', quantity: 2.0, unit: 'cups', order: 0),
            Ingredient(item: 'sugar', quantity: 1.0, unit: 'cup', order: 1),
          ],
          directions: [],
        );

        final recipeWithoutQuantities = Recipe(
          title: 'Test Recipe',
          ingredients: [
            Ingredient(item: 'flour', order: 0),
            Ingredient(item: 'sugar', order: 1),
          ],
          directions: [],
        );

        final scoreWith =
            ConfidenceCalculatorService.calculate(recipeWithQuantities);
        final scoreWithout =
            ConfidenceCalculatorService.calculate(recipeWithoutQuantities);

        expect(scoreWith.ingredientScore,
            greaterThan(scoreWithout.ingredientScore));
      });

      test('directions with time/temp references score higher', () {
        final recipeWithRefs = Recipe(
          title: 'Test Recipe',
          ingredients: [],
          directions: [
            Direction(stepNumber: 1, text: 'Bake at 350°F for 30 minutes.'),
            Direction(stepNumber: 2, text: 'Let cool for 10 minutes.'),
          ],
        );

        final recipeWithoutRefs = Recipe(
          title: 'Test Recipe',
          ingredients: [],
          directions: [
            Direction(stepNumber: 1, text: 'Mix ingredients.'),
            Direction(stepNumber: 2, text: 'Stir well.'),
          ],
        );

        final scoreWith = ConfidenceCalculatorService.calculate(recipeWithRefs);
        final scoreWithout =
            ConfidenceCalculatorService.calculate(recipeWithoutRefs);

        expect(
            scoreWith.directionScore, greaterThan(scoreWithout.directionScore));
      });
    });
  });
}
