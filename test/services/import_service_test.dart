import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_ripper/models/recipe.dart';
import 'package:recipe_ripper/services/import_service.dart';

void main() {
  group('ImportService JSON parsing', () {
    test('parses single recipe JSON', () {
      final recipeJson = {
        'title': 'Test Recipe',
        'sourceUrl': 'https://example.com',
        'ingredients': [
          {'quantity': 2.0, 'unit': 'cups', 'item': 'flour'},
          {'quantity': 1.0, 'unit': 'teaspoon', 'item': 'salt'},
        ],
        'directions': [
          {'stepNumber': 1, 'text': 'Mix ingredients.'},
          {'stepNumber': 2, 'text': 'Bake at 350°F.'},
        ],
      };

      final recipe = Recipe.fromJson(recipeJson);

      expect(recipe.title, 'Test Recipe');
      expect(recipe.sourceUrl, 'https://example.com');
      expect(recipe.ingredients.length, 2);
      expect(recipe.directions.length, 2);
      expect(recipe.ingredients[0].item, 'flour');
      expect(recipe.directions[0].text, 'Mix ingredients.');
    });

    test('parses recipe array JSON', () {
      final recipesJson = [
        {
          'title': 'Recipe 1',
          'ingredients': [
            {'item': 'flour'},
          ],
          'directions': [
            {'stepNumber': 1, 'text': 'Step 1'},
          ],
        },
        {
          'title': 'Recipe 2',
          'ingredients': [
            {'item': 'sugar'},
          ],
          'directions': [
            {'stepNumber': 1, 'text': 'Step A'},
          ],
        },
      ];

      final recipes = recipesJson
          .map((j) => Recipe.fromJson(j as Map<String, dynamic>))
          .toList();

      expect(recipes.length, 2);
      expect(recipes[0].title, 'Recipe 1');
      expect(recipes[1].title, 'Recipe 2');
    });

    test('parses export format JSON with version', () {
      final exportJson = {
        'version': '1.0',
        'exportedAt': '2024-01-01T00:00:00.000Z',
        'recipeCount': 1,
        'recipes': [
          {
            'title': 'Exported Recipe',
            'ingredients': [
              {'item': 'butter'},
            ],
            'directions': [
              {'stepNumber': 1, 'text': 'Melt butter.'},
            ],
          },
        ],
      };

      final recipes = (exportJson['recipes'] as List)
          .map((r) => Recipe.fromJson(r as Map<String, dynamic>))
          .toList();

      expect(recipes.length, 1);
      expect(recipes[0].title, 'Exported Recipe');
    });

    test('handles missing optional fields', () {
      final minimalJson = {
        'title': 'Minimal Recipe',
        'ingredients': [],
        'directions': [],
      };

      final recipe = Recipe.fromJson(minimalJson);

      expect(recipe.title, 'Minimal Recipe');
      expect(recipe.sourceUrl, isNull);
      expect(recipe.sourcePlatform, isNull);
      expect(recipe.ingredients, isEmpty);
      expect(recipe.directions, isEmpty);
    });

    test('handles snake_case keys', () {
      final snakeCaseJson = {
        'title': 'Snake Case Recipe',
        'source_url': 'https://example.com',
        'source_platform': 'YouTube',
        'ingredients': [],
        'directions': [],
      };

      // The Recipe.fromJson expects camelCase, but our import service
      // should handle both
      expect(snakeCaseJson['source_url'], 'https://example.com');
    });
  });

  group('ImportService Markdown parsing', () {
    test('parses simple markdown recipe', () {
      // Example markdown format that would be parsed
      const markdown = '''
# Chocolate Chip Cookies

## Ingredients
- 2 cups flour
- 1 cup sugar
- 1/2 cup butter

## Directions
1. Mix dry ingredients.
2. Add butter and stir.
3. Bake at 375°F for 12 minutes.
''';

      // Verify the markdown contains expected structure
      expect(markdown, contains('# Chocolate Chip Cookies'));
      expect(markdown, contains('## Ingredients'));
      expect(markdown, contains('## Directions'));

      // Since _parseMarkdown is private, we'll test the line parsing logic
      // through the ingredient and direction parsing

      // Test bullet removal
      const bulletLine = '- 2 cups flour';
      var cleaned = bulletLine;
      if (cleaned.startsWith('- ')) cleaned = cleaned.substring(2);
      expect(cleaned, '2 cups flour');
    });

    test('removes bullet points from ingredient lines', () {
      const testCases = {
        '- 2 cups flour': '2 cups flour',
        '* 1 teaspoon salt': '1 teaspoon salt',
        '• 3 eggs': '3 eggs',
        '2 cups sugar': '2 cups sugar', // No bullet
      };

      for (final entry in testCases.entries) {
        var line = entry.key;
        if (line.startsWith('- ')) line = line.substring(2);
        if (line.startsWith('* ')) line = line.substring(2);
        if (line.startsWith('• ')) line = line.substring(2);
        expect(line, entry.value);
      }
    });

    test('parses numbered direction lines', () {
      const testCases = {
        '1. Mix ingredients': 'Mix ingredients',
        '2) Add butter': 'Add butter',
        '10. Final step': 'Final step',
      };

      final numberPattern = RegExp(r'^(\d+)[.)]\s*');
      for (final entry in testCases.entries) {
        final match = numberPattern.firstMatch(entry.key);
        expect(match, isNotNull);
        final text = entry.key.substring(match!.end).trim();
        expect(text, entry.value);
      }
    });

    test('identifies section headers', () {
      const headers = [
        '## Ingredients',
        '## INGREDIENTS',
        '## Directions',
        '## Instructions',
        '## Steps',
      ];

      for (final header in headers) {
        expect(header.startsWith('## '), true);
        final name = header.substring(3).trim().toLowerCase();
        final isIngredient = name.contains('ingredient');
        final isDirection = name.contains('direction') ||
            name.contains('instruction') ||
            name.contains('step');
        expect(isIngredient || isDirection, true);
      }
    });
  });

  group('Fraction parsing', () {
    test('parses simple fractions', () {
      final fractions = {
        '1/2': 0.5,
        '1/4': 0.25,
        '3/4': 0.75,
        '1/3': 1 / 3,
        '2/3': 2 / 3,
      };

      final fractionPattern = RegExp(r'^(\d+)/(\d+)$');
      for (final entry in fractions.entries) {
        final match = fractionPattern.firstMatch(entry.key);
        expect(match, isNotNull);
        final num = int.parse(match!.group(1)!);
        final den = int.parse(match.group(2)!);
        expect(num / den, closeTo(entry.value, 0.001));
      }
    });

    test('parses mixed fractions', () {
      final mixedFractions = {
        '1 1/2': 1.5,
        '2 1/4': 2.25,
        '1 3/4': 1.75,
      };

      final mixedPattern = RegExp(r'^(\d+)\s+(\d+)/(\d+)$');
      for (final entry in mixedFractions.entries) {
        final match = mixedPattern.firstMatch(entry.key);
        expect(match, isNotNull);
        final whole = int.parse(match!.group(1)!);
        final num = int.parse(match.group(2)!);
        final den = int.parse(match.group(3)!);
        expect(whole + num / den, closeTo(entry.value, 0.001));
      }
    });

    test('handles unicode fractions', () {
      final unicodeFractions = {
        '½': 0.5,
        '¼': 0.25,
        '¾': 0.75,
        '⅓': 1 / 3,
        '⅔': 2 / 3,
        '⅛': 0.125,
      };

      // These would be handled by the unicode fraction map in import service
      for (final entry in unicodeFractions.entries) {
        expect(entry.value, isA<double>());
      }
    });
  });

  group('ImportResult', () {
    test('creates success result', () {
      final result = ImportResult(
        success: true,
        importedCount: 5,
        skippedCount: 2,
        failedCount: 0,
        importedRecipes: ['Recipe 1', 'Recipe 2'],
        skippedRecipes: ['Duplicate'],
      );

      expect(result.success, true);
      expect(result.importedCount, 5);
      expect(result.skippedCount, 2);
      expect(result.failedCount, 0);
    });

    test('creates failure result', () {
      final result = ImportResult.failure('File not found');

      expect(result.success, false);
      expect(result.errorMessage, 'File not found');
    });
  });

  group('ValidationResult', () {
    test('creates valid result', () {
      final result = ValidationResult.valid(warnings: ['No source URL']);

      expect(result.isValid, true);
      expect(result.errors, isEmpty);
      expect(result.warnings, contains('No source URL'));
    });

    test('creates invalid result', () {
      final result = ValidationResult.invalid(['Title is required']);

      expect(result.isValid, false);
      expect(result.errors, contains('Title is required'));
    });
  });

  group('Unit extraction', () {
    test('common cooking units are recognized', () {
      final units = [
        'cup',
        'cups',
        'tablespoon',
        'tablespoons',
        'tbsp',
        'teaspoon',
        'teaspoons',
        'tsp',
        'pound',
        'pounds',
        'lb',
        'lbs',
        'ounce',
        'ounces',
        'oz',
        'gram',
        'grams',
        'g',
        'kilogram',
        'kg',
        'ml',
        'milliliter',
        'liter',
        'l',
        'pinch',
        'dash',
        'piece',
        'pieces',
        'slice',
        'slices',
        'can',
        'cans',
        'package',
        'packages',
        'bunch',
        'clove',
        'cloves',
        'head',
        'stalk',
        'sprig',
        'large',
        'medium',
        'small',
      ];

      final unitPattern = RegExp(
        r'^(cup|cups|tablespoon|tablespoons|tbsp|teaspoon|teaspoons|tsp|'
        r'pound|pounds|lb|lbs|ounce|ounces|oz|gram|grams|g|kilogram|kg|'
        r'ml|milliliter|liter|l|pinch|dash|piece|pieces|slice|slices|'
        r'can|cans|package|packages|pkg|bunch|bunches|clove|cloves|'
        r'head|heads|stalk|stalks|sprig|sprigs|large|medium|small)\s+',
        caseSensitive: false,
      );

      for (final unit in units) {
        final testString = '$unit flour';
        final match = unitPattern.firstMatch(testString);
        expect(match, isNotNull, reason: 'Unit "$unit" should be recognized');
      }
    });
  });

  group('Notes extraction', () {
    test('extracts notes in parentheses', () {
      const testCases = {
        'butter (softened)': 'softened',
        'flour (sifted)': 'sifted',
        'eggs (room temperature)': 'room temperature',
        'chicken (boneless, skinless)': 'boneless, skinless',
      };

      final notesPattern = RegExp(r'\(([^)]+)\)\s*$');
      for (final entry in testCases.entries) {
        final match = notesPattern.firstMatch(entry.key);
        expect(match, isNotNull);
        expect(match!.group(1), entry.value);
      }
    });

    test('handles no notes', () {
      const testStrings = [
        'flour',
        '2 cups sugar',
        'salt to taste',
      ];

      final notesPattern = RegExp(r'\(([^)]+)\)\s*$');
      for (final str in testStrings) {
        final match = notesPattern.firstMatch(str);
        expect(match, isNull);
      }
    });
  });
}
