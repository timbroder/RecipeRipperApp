import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_ripper/services/llm/llm_service.dart';
import 'package:recipe_ripper/services/llm_recipe_extraction_service.dart';

/// Mock LLM service for testing.
class MockLlmService extends LlmService {
  LlmExtractionResult? descriptionResult;
  LlmExtractionResult? fullResult;

  @override
  String get name => 'Mock LLM';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<LlmExtractionResult> extractRecipe(
    String text, {
    String? videoTitle,
  }) async {
    return fullResult ?? LlmExtractionResult.failed('Not configured');
  }

  @override
  Future<LlmExtractionResult> extractRecipeFromDescription(
    String description, {
    String? videoTitle,
  }) async {
    return descriptionResult ?? LlmExtractionResult.failed('Not configured');
  }
}

void main() {
  group('LlmRecipeExtractionService', () {
    late MockLlmService mockLlm;

    setUp(() {
      mockLlm = MockLlmService();
    });

    group('tryDescriptionOnly', () {
      test('returns recipe when LLM succeeds with quality result', () async {
        mockLlm.descriptionResult = LlmExtractionResult(
          title: 'Chocolate Cake',
          ingredients: [
            LlmIngredient(quantity: '2', unit: 'cups', item: 'flour'),
            LlmIngredient(quantity: '1', unit: 'cup', item: 'sugar'),
            LlmIngredient(quantity: '3', item: 'eggs'),
          ],
          directions: [
            'Preheat oven to 350F',
            'Mix dry ingredients together',
            'Add eggs and mix until smooth',
          ],
          success: true,
        );

        final recipe = await LlmRecipeExtractionService.tryDescriptionOnly(
          description: 'Ingredients: 2 cups flour, 1 cup sugar, 3 eggs\n'
              'Directions: Preheat oven. Mix dry ingredients. Add eggs.',
          llmService: mockLlm,
          videoTitle: 'Best Cake Ever',
        );

        expect(recipe, isNotNull);
        expect(recipe!.title, equals('Chocolate Cake'));
        expect(recipe.ingredients.length, greaterThanOrEqualTo(3));
        expect(recipe.directions, isNotEmpty);
        expect(recipe.metadata?.processingMethod, equals('description_only'));
      });

      test('returns null when LLM fails', () async {
        mockLlm.descriptionResult = LlmExtractionResult.failed('Model error');

        final recipe = await LlmRecipeExtractionService.tryDescriptionOnly(
          description: 'Some description',
          llmService: mockLlm,
        );

        expect(recipe, isNull);
      });

      test('returns null when result below quality threshold', () async {
        mockLlm.descriptionResult = LlmExtractionResult(
          title: 'Test',
          ingredients: [LlmIngredient(item: 'flour')],
          directions: [],
          success: true,
        );

        final recipe = await LlmRecipeExtractionService.tryDescriptionOnly(
          description: 'Some description',
          llmService: mockLlm,
        );

        expect(recipe, isNull);
      });

      test('returns null for empty description after filtering', () async {
        final recipe = await LlmRecipeExtractionService.tryDescriptionOnly(
          description: '@username\n#cooking\nhttps://link.com',
          llmService: mockLlm,
        );

        expect(recipe, isNull);
      });
    });

    group('tryFullLlm', () {
      test('returns recipe when LLM succeeds', () async {
        mockLlm.fullResult = LlmExtractionResult(
          title: 'Pasta Recipe',
          ingredients: [
            LlmIngredient(quantity: '1', unit: 'lb', item: 'pasta'),
            LlmIngredient(quantity: '2', unit: 'cups', item: 'tomato sauce'),
          ],
          directions: [
            'Boil water and cook pasta',
            'Add sauce and serve',
          ],
          success: true,
        );

        final recipe = await LlmRecipeExtractionService.tryFullLlm(
          transcript: 'so now we boil the water and cook the pasta',
          ocrText: 'INGREDIENTS\npasta\ntomato sauce',
          description: null,
          llmService: mockLlm,
        );

        expect(recipe, isNotNull);
        expect(recipe!.title, equals('Pasta Recipe'));
        expect(recipe.metadata?.processingMethod, equals('llm_full'));
      });

      test('returns null when LLM fails', () async {
        mockLlm.fullResult = LlmExtractionResult.failed('Error');

        final recipe = await LlmRecipeExtractionService.tryFullLlm(
          transcript: 'Some transcript',
          ocrText: 'Some OCR text',
          description: null,
          llmService: mockLlm,
        );

        expect(recipe, isNull);
      });

      test('returns null for empty inputs', () async {
        final recipe = await LlmRecipeExtractionService.tryFullLlm(
          transcript: null,
          ocrText: null,
          description: null,
          llmService: mockLlm,
        );

        expect(recipe, isNull);
      });

      test('applies spoken-to-imperative conversion to directions', () async {
        mockLlm.fullResult = LlmExtractionResult(
          title: 'Test',
          ingredients: [
            LlmIngredient(item: 'flour'),
            LlmIngredient(item: 'sugar'),
          ],
          directions: [
            "I'm gonna add the flour",
            'go ahead and mix it well',
          ],
          success: true,
        );

        final recipe = await LlmRecipeExtractionService.tryFullLlm(
          transcript: 'test',
          ocrText: null,
          description: null,
          llmService: mockLlm,
        );

        expect(recipe, isNotNull);
        expect(recipe!.directions[0].text, equals('Add the flour'));
        expect(recipe.directions[1].text, equals('Mix it well'));
      });

      test('runs cross-reference check and adds warnings', () async {
        mockLlm.fullResult = LlmExtractionResult(
          title: 'Test',
          ingredients: [
            LlmIngredient(item: 'flour'),
            LlmIngredient(item: 'nutmeg'),
          ],
          directions: [
            'Mix flour and sugar together',
          ],
          success: true,
        );

        final recipe = await LlmRecipeExtractionService.tryFullLlm(
          transcript: 'test',
          ocrText: null,
          description: null,
          llmService: mockLlm,
        );

        expect(recipe, isNotNull);
        // nutmeg is unused, sugar is missing
        expect(recipe!.metadata?.warnings, isNotNull);
        expect(
          recipe.metadata!.warnings!,
          anyElement(contains('Unused ingredient: nutmeg')),
        );
      });
    });
  });
}
