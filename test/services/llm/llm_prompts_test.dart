import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_ripper/services/llm/llm_prompts.dart';

void main() {
  group('LlmPrompts', () {
    group('fullExtractionPrompt', () {
      test('generates prompt with text', () {
        final prompt = LlmPrompts.fullExtractionPrompt('Mix flour and sugar');
        expect(prompt, contains('Mix flour and sugar'));
        expect(prompt, contains('JSON'));
        expect(prompt, contains('ingredients'));
        expect(prompt, contains('directions'));
      });

      test('includes video title when provided', () {
        final prompt = LlmPrompts.fullExtractionPrompt(
          'Mix flour and sugar',
          videoTitle: 'Best Cake Recipe',
        );
        expect(prompt, contains('Best Cake Recipe'));
      });
    });

    group('descriptionOnlyPrompt', () {
      test('generates prompt for description', () {
        final prompt = LlmPrompts.descriptionOnlyPrompt(
          'Ingredients: 2 cups flour, 1 cup sugar',
        );
        expect(prompt, contains('2 cups flour'));
        expect(prompt, contains('description'));
      });
    });

    group('parseResponse', () {
      test('parses direct JSON', () {
        const response =
            '{"title":"Cake","ingredients":[{"item":"flour"}],"directions":["Mix"]}';
        final result = LlmPrompts.parseResponse(response);
        expect(result, isNotNull);
        expect(result!['title'], equals('Cake'));
      });

      test('parses JSON with markdown fences', () {
        const response = '''```json
{"title":"Cake","ingredients":[{"item":"flour"}],"directions":["Mix"]}
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
