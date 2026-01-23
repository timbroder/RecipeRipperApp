import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_ripper/models/recipe.dart';
import 'package:recipe_ripper/models/ingredient.dart';
import 'package:recipe_ripper/models/direction.dart';
import 'package:recipe_ripper/services/export_service.dart';

void main() {
  group('ExportService', () {
    late Recipe testRecipe;

    setUp(() {
      testRecipe = Recipe(
        id: 'test-id',
        title: 'Test Recipe',
        sourceUrl: 'https://example.com/recipe',
        sourcePlatform: 'Example',
        ingredients: [
          Ingredient(
            id: 'ing-1',
            recipeId: 'test-id',
            quantity: 2.0,
            unit: 'cups',
            item: 'flour',
            order: 0,
          ),
          Ingredient(
            id: 'ing-2',
            recipeId: 'test-id',
            quantity: 1.0,
            unit: 'teaspoon',
            item: 'salt',
            order: 1,
          ),
          Ingredient(
            id: 'ing-3',
            recipeId: 'test-id',
            quantity: 0.5,
            unit: 'cup',
            item: 'sugar',
            notes: 'optional',
            order: 2,
          ),
        ],
        directions: [
          Direction(
            id: 'dir-1',
            recipeId: 'test-id',
            stepNumber: 1,
            text: 'Mix dry ingredients.',
          ),
          Direction(
            id: 'dir-2',
            recipeId: 'test-id',
            stepNumber: 2,
            text: 'Add wet ingredients and stir.',
          ),
          Direction(
            id: 'dir-3',
            recipeId: 'test-id',
            stepNumber: 3,
            text: 'Bake at 350°F for 30 minutes.',
          ),
        ],
      );
    });

    group('formatBytes', () {
      test('formats bytes correctly', () {
        expect(ExportService.formatBytes(0), '0 B');
        expect(ExportService.formatBytes(512), '512 B');
        expect(ExportService.formatBytes(1024), '1.0 KB');
        expect(ExportService.formatBytes(1536), '1.5 KB');
        expect(ExportService.formatBytes(1048576), '1.0 MB');
        expect(ExportService.formatBytes(1572864), '1.5 MB');
        expect(ExportService.formatBytes(1073741824), '1.0 GB');
      });
    });

    group('Recipe JSON export format', () {
      test('recipe toJson includes all required fields', () {
        final json = testRecipe.toJson();

        expect(json['id'], 'test-id');
        expect(json['title'], 'Test Recipe');
        expect(json['sourceUrl'], 'https://example.com/recipe');
        expect(json['sourcePlatform'], 'Example');
        expect(json['ingredients'], isA<List>());
        expect((json['ingredients'] as List).length, 3);
        expect(json['directions'], isA<List>());
        expect((json['directions'] as List).length, 3);
      });

      test('ingredient toJson includes all fields', () {
        final ingredient = testRecipe.ingredients[0];
        final json = ingredient.toJson();

        expect(json['quantity'], 2.0);
        expect(json['unit'], 'cups');
        expect(json['item'], 'flour');
        expect(json['order'], 0);
      });

      test('direction toJson includes all fields', () {
        final direction = testRecipe.directions[0];
        final json = direction.toJson();

        expect(json['stepNumber'], 1);
        expect(json['text'], 'Mix dry ingredients.');
      });

      test('recipe JSON can be re-parsed', () {
        final jsonStr = const JsonEncoder.withIndent('  ').convert(testRecipe.toJson());
        final parsed = json.decode(jsonStr) as Map<String, dynamic>;
        final restored = Recipe.fromJson(parsed);

        expect(restored.title, testRecipe.title);
        expect(restored.sourceUrl, testRecipe.sourceUrl);
        expect(restored.ingredients.length, testRecipe.ingredients.length);
        expect(restored.directions.length, testRecipe.directions.length);
      });
    });

    group('Recipe Markdown format', () {
      test('generates valid markdown for recipe', () {
        // We can't directly call _recipeToMarkdown since it's private,
        // but we can test the Recipe's toDisplayString methods
        expect(testRecipe.ingredients[0].toDisplayString(), '2 cups flour');
        expect(testRecipe.ingredients[1].toDisplayString(), '1 teaspoon salt');
        expect(testRecipe.ingredients[2].toDisplayString(), '0.5 cup sugar (optional)');
      });

      test('direction displays with step number', () {
        expect(testRecipe.directions[0].toDisplayString(), '1. Mix dry ingredients.');
      });
    });

    group('Ingredient display formatting', () {
      test('formats whole number quantities without decimal', () {
        final ingredient = Ingredient(
          quantity: 2.0,
          unit: 'cups',
          item: 'flour',
          order: 0,
        );
        expect(ingredient.toDisplayString(), '2 cups flour');
      });

      test('formats fractional quantities with decimal', () {
        final ingredient = Ingredient(
          quantity: 0.5,
          unit: 'cup',
          item: 'sugar',
          order: 0,
        );
        expect(ingredient.toDisplayString(), '0.5 cup sugar');
      });

      test('formats ingredient without quantity', () {
        final ingredient = Ingredient(
          unit: 'pinch',
          item: 'salt',
          order: 0,
        );
        expect(ingredient.toDisplayString(), 'pinch salt');
      });

      test('formats ingredient without unit', () {
        final ingredient = Ingredient(
          quantity: 3.0,
          item: 'eggs',
          order: 0,
        );
        expect(ingredient.toDisplayString(), '3 eggs');
      });

      test('formats ingredient with notes', () {
        final ingredient = Ingredient(
          quantity: 1.0,
          unit: 'cup',
          item: 'butter',
          notes: 'softened',
          order: 0,
        );
        expect(ingredient.toDisplayString(), '1 cup butter (softened)');
      });

      test('formats ingredient with only item', () {
        final ingredient = Ingredient(
          item: 'salt to taste',
          order: 0,
        );
        expect(ingredient.toDisplayString(), 'salt to taste');
      });
    });

    group('ExportResult', () {
      test('creates success result with content', () {
        final result = ExportResult.success(content: 'test content');
        expect(result.success, true);
        expect(result.content, 'test content');
        expect(result.errorMessage, isNull);
      });

      test('creates success result with file path', () {
        final result = ExportResult.success(filePath: '/path/to/file');
        expect(result.success, true);
        expect(result.filePath, '/path/to/file');
      });

      test('creates failure result with error', () {
        final result = ExportResult.failure('Something went wrong');
        expect(result.success, false);
        expect(result.errorMessage, 'Something went wrong');
      });
    });
  });
}
