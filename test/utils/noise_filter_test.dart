import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_ripper/utils/noise_filter.dart';

void main() {
  group('NoiseFilter', () {
    group('filterLine', () {
      test('returns null for empty lines', () {
        expect(NoiseFilter.filterLine(''), isNull);
        expect(NoiseFilter.filterLine('   '), isNull);
      });

      test('returns null for very short lines', () {
        expect(NoiseFilter.filterLine('a'), isNull);
        expect(NoiseFilter.filterLine('OK'), isNull);
      });

      test('returns null for symbol-only lines', () {
        expect(NoiseFilter.filterLine('---'), isNull);
        expect(NoiseFilter.filterLine('***'), isNull);
        expect(NoiseFilter.filterLine('123'), isNull);
      });

      test('returns null for single common words', () {
        expect(NoiseFilter.filterLine('and'), isNull);
        expect(NoiseFilter.filterLine('the'), isNull);
        expect(NoiseFilter.filterLine('or'), isNull);
      });

      test('returns null for empty section headers', () {
        expect(NoiseFilter.filterLine('Ingredients:'), isNull);
        expect(NoiseFilter.filterLine('Directions'), isNull);
        expect(NoiseFilter.filterLine('Steps:'), isNull);
        expect(NoiseFilter.filterLine('Instructions'), isNull);
      });

      test('returns null for YouTube UI patterns', () {
        expect(NoiseFilter.filterLine('@chefjohn'), isNull);
        expect(NoiseFilter.filterLine('1.2M views'), isNull);
        expect(NoiseFilter.filterLine('500K subscribers'), isNull);
        expect(NoiseFilter.filterLine('1:23'), isNull);
        expect(NoiseFilter.filterLine('1:23:45'), isNull);
        expect(NoiseFilter.filterLine('#cooking'), isNull);
      });

      test('returns null for engagement patterns', () {
        expect(
          NoiseFilter.filterLine('Hit the like button and subscribe'),
          isNull,
        );
        expect(
          NoiseFilter.filterLine("Don't forget to subscribe"),
          isNull,
        );
        expect(
          NoiseFilter.filterLine('Smash that like button'),
          isNull,
        );
        expect(
          NoiseFilter.filterLine('Turn on notifications'),
          isNull,
        );
      });

      test('returns null for promotional patterns', () {
        expect(
          NoiseFilter.filterLine('Use my discount code CHEF20'),
          isNull,
        );
        expect(
          NoiseFilter.filterLine('Check out the affiliate link below'),
          isNull,
        );
        expect(
          NoiseFilter.filterLine('Shop now at https://example.com'),
          isNull,
        );
        expect(
          NoiseFilter.filterLine('Link in the bio'),
          isNull,
        );
      });

      test('returns null for commentary patterns', () {
        expect(
          NoiseFilter.filterLine('Hey guys welcome to my channel'),
          isNull,
        );
        expect(
          NoiseFilter.filterLine('Thanks for watching'),
          isNull,
        );
        expect(
          NoiseFilter.filterLine('Let me know in the comments'),
          isNull,
        );
        expect(
          NoiseFilter.filterLine('See you in the next video'),
          isNull,
        );
      });

      test('returns null for nutrition patterns', () {
        expect(NoiseFilter.filterLine('Calories: 250'), isNull);
        expect(NoiseFilter.filterLine('Total fat 12g'), isNull);
        expect(NoiseFilter.filterLine('Protein: 8g'), isNull);
        expect(NoiseFilter.filterLine('Serving size'), isNull);
        expect(NoiseFilter.filterLine('Nutrition facts'), isNull);
      });

      test('returns null for ALL CAPS short non-food phrases', () {
        expect(NoiseFilter.filterLine('SUBSCRIBE NOW'), isNull);
        expect(NoiseFilter.filterLine('NEW VIDEO'), isNull);
      });

      test('keeps ALL CAPS food words', () {
        expect(NoiseFilter.filterLine('FLOUR'), equals('FLOUR'));
        expect(NoiseFilter.filterLine('SUGAR'), equals('SUGAR'));
      });

      test('returns null for long words without spaces', () {
        expect(
          NoiseFilter.filterLine('abcdefghijklmnopqrstuvwxyz'),
          isNull,
        );
      });

      test('keeps valid recipe lines', () {
        expect(
          NoiseFilter.filterLine('2 cups all-purpose flour'),
          equals('2 cups all-purpose flour'),
        );
        expect(
          NoiseFilter.filterLine('Preheat oven to 350 degrees'),
          equals('Preheat oven to 350 degrees'),
        );
        expect(
          NoiseFilter.filterLine('Mix the dry ingredients together'),
          equals('Mix the dry ingredients together'),
        );
      });
    });

    group('filterText', () {
      test('filters multiple lines and joins result', () {
        const input = '''Hey guys welcome to my channel
2 cups flour
1 teaspoon salt
Hit the like button
Preheat oven to 350F
Thanks for watching''';

        final result = NoiseFilter.filterText(input);
        expect(result, contains('2 cups flour'));
        expect(result, contains('1 teaspoon salt'));
        expect(result, contains('Preheat oven to 350F'));
        expect(result, isNot(contains('Hey guys')));
        expect(result, isNot(contains('like button')));
        expect(result, isNot(contains('Thanks for watching')));
      });

      test('handles empty input', () {
        expect(NoiseFilter.filterText(''), equals(''));
      });
    });
  });
}
