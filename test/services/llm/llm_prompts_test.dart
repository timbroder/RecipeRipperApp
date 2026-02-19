import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_ripper/services/llm/llm_prompts.dart';

void main() {
  group('LlmPrompts', () {
    group('fullExtractionInstructions', () {
      test('contains extraction rules', () {
        final instructions = LlmPrompts.fullExtractionInstructions();
        expect(instructions, contains('recipe extraction'));
        expect(instructions, contains('JSON'));
        expect(instructions, contains('ingredients'));
        expect(instructions, contains('directions'));
      });
    });

    group('fullExtractionUserPrompt', () {
      test('generates prompt with text', () {
        final prompt =
            LlmPrompts.fullExtractionUserPrompt('Mix flour and sugar');
        expect(prompt, contains('Mix flour and sugar'));
      });

      test('includes video title when provided', () {
        final prompt = LlmPrompts.fullExtractionUserPrompt(
          'Mix flour and sugar',
          videoTitle: 'Best Cake Recipe',
        );
        expect(prompt, contains('Best Cake Recipe'));
      });
    });

    group('fullExtractionPrompt (combined)', () {
      test('combines instructions and user prompt', () {
        final prompt = LlmPrompts.fullExtractionPrompt('Mix flour and sugar');
        expect(prompt, contains('recipe extraction'));
        expect(prompt, contains('Mix flour and sugar'));
      });
    });

    group('descriptionOnlyInstructions', () {
      test('contains description-specific rules', () {
        final instructions = LlmPrompts.descriptionOnlyInstructions();
        expect(instructions, contains('video description'));
        expect(instructions, contains('JSON'));
      });
    });

    group('descriptionOnlyUserPrompt', () {
      test('generates prompt for description', () {
        final prompt = LlmPrompts.descriptionOnlyUserPrompt(
          'Ingredients: 2 cups flour, 1 cup sugar',
        );
        expect(prompt, contains('2 cups flour'));
      });
    });

    group('descriptionOnlyPrompt (combined)', () {
      test('combines instructions and user prompt', () {
        final prompt = LlmPrompts.descriptionOnlyPrompt(
          'Ingredients: 2 cups flour, 1 cup sugar',
        );
        expect(prompt, contains('video description'));
        expect(prompt, contains('2 cups flour'));
      });
    });

    group('parseResponse', () {
      test('parses direct JSON', () {
        const response =
            '{"title":"Cake","ingredients":["2 cups flour"],"directions":["Mix"]}';
        final result = LlmPrompts.parseResponse(response);
        expect(result, isNotNull);
        expect(result!['title'], equals('Cake'));
      });

      test('parses JSON with markdown fences', () {
        const response = '''```json
{"title":"Cake","ingredients":["2 cups flour"],"directions":["Mix"]}
```''';
        final result = LlmPrompts.parseResponse(response);
        expect(result, isNotNull);
        expect(result!['title'], equals('Cake'));
      });

      test('parses JSON embedded in text', () {
        const response =
            'Here is the recipe: {"title":"Cake","ingredients":[],"directions":[]} Hope this helps!';
        final result = LlmPrompts.parseResponse(response);
        expect(result, isNotNull);
        expect(result!['title'], equals('Cake'));
      });

      test('returns null for invalid JSON', () {
        const response = 'This is not JSON at all';
        final result = LlmPrompts.parseResponse(response);
        expect(result, isNull);
      });

      test('returns null for empty string', () {
        final result = LlmPrompts.parseResponse('');
        expect(result, isNull);
      });
    });
  });
}
