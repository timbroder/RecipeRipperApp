import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_ripper/utils/parsing_utils.dart';

void main() {
  group('ParsingUtils', () {
    group('normalizeUnit', () {
      test('should normalize common abbreviations', () {
        expect(ParsingUtils.normalizeUnit('tbsp'), 'tablespoon');
        expect(ParsingUtils.normalizeUnit('tsp'), 'teaspoon');
        expect(ParsingUtils.normalizeUnit('c'), 'cup');
        expect(ParsingUtils.normalizeUnit('oz'), 'ounce');
        expect(ParsingUtils.normalizeUnit('lb'), 'pound');
      });

      test('should handle case insensitive input', () {
        expect(ParsingUtils.normalizeUnit('TBSP'), 'tablespoon');
        expect(ParsingUtils.normalizeUnit('Tsp'), 'teaspoon');
      });

      test('should return original if no mapping found', () {
        expect(ParsingUtils.normalizeUnit('pinch'), 'pinch');
        expect(ParsingUtils.normalizeUnit('handful'), 'handful');
      });
    });

    group('parseFraction', () {
      test('should parse unicode fractions', () {
        expect(ParsingUtils.parseFraction('½'), 0.5);
        expect(ParsingUtils.parseFraction('¼'), 0.25);
        expect(ParsingUtils.parseFraction('¾'), 0.75);
        expect(ParsingUtils.parseFraction('⅓'), closeTo(0.333, 0.01));
        expect(ParsingUtils.parseFraction('⅔'), closeTo(0.667, 0.01));
      });

      test('should parse slash fractions', () {
        expect(ParsingUtils.parseFraction('1/2'), 0.5);
        expect(ParsingUtils.parseFraction('1/4'), 0.25);
        expect(ParsingUtils.parseFraction('3/4'), 0.75);
        expect(ParsingUtils.parseFraction('2/3'), closeTo(0.667, 0.01));
      });

      test('should parse mixed numbers', () {
        expect(ParsingUtils.parseFraction('1 1/2'), 1.5);
        expect(ParsingUtils.parseFraction('2 1/4'), 2.25);
        expect(ParsingUtils.parseFraction('1½'), 1.5);
        expect(ParsingUtils.parseFraction('2¾'), 2.75);
      });

      test('should parse decimals', () {
        expect(ParsingUtils.parseFraction('1.5'), 1.5);
        expect(ParsingUtils.parseFraction('2.25'), 2.25);
        expect(ParsingUtils.parseFraction('0.5'), 0.5);
      });

      test('should return null for invalid input', () {
        expect(ParsingUtils.parseFraction('abc'), null);
        expect(ParsingUtils.parseFraction(''), null);
        expect(ParsingUtils.parseFraction('1/0'), null); // Division by zero
      });
    });

    group('parseQuantity', () {
      test('should parse simple numbers', () {
        expect(ParsingUtils.parseQuantity('1'), 1.0);
        expect(ParsingUtils.parseQuantity('2.5'), 2.5);
        expect(ParsingUtils.parseQuantity('0.5'), 0.5);
      });

      test('should parse fractions', () {
        expect(ParsingUtils.parseQuantity('1/2'), 0.5);
        expect(ParsingUtils.parseQuantity('1½'), 1.5);
      });

      test('should parse ranges by averaging', () {
        expect(ParsingUtils.parseQuantity('1-2'), 1.5);
        expect(ParsingUtils.parseQuantity('2-4'), 3.0);
        expect(ParsingUtils.parseQuantity('1 to 2'), 1.5);
      });
    });

    group('cleanText', () {
      test('should remove excessive whitespace', () {
        expect(
          ParsingUtils.cleanText('hello   world'),
          'hello world',
        );
        expect(
          ParsingUtils.cleanText('  hello  world  '),
          'hello world',
        );
      });

      test('should remove OCR artifacts', () {
        expect(ParsingUtils.cleanText('• hello'), 'hello');
        expect(ParsingUtils.cleanText('| hello'), 'hello');
        expect(ParsingUtils.cleanText('● hello'), 'hello');
      });

      test('should normalize quotes and dashes', () {
        expect(ParsingUtils.cleanText('\u201Chello\u201D'), '"hello"');
        expect(ParsingUtils.cleanText('\u2018hello\u2019'), "'hello'");
        expect(ParsingUtils.cleanText('hello\u2014world'), 'hello-world');
      });
    });

    group('normalizeForComparison', () {
      test('should lowercase and remove punctuation', () {
        expect(
          ParsingUtils.normalizeForComparison('Hello, World!'),
          'hello world',
        );
        expect(
          ParsingUtils.normalizeForComparison('Test-Case'),
          'testcase',
        );
      });

      test('should normalize whitespace', () {
        expect(
          ParsingUtils.normalizeForComparison('  hello   world  '),
          'hello world',
        );
      });
    });

    group('stringSimilarity', () {
      test('should return 1.0 for identical strings', () {
        expect(ParsingUtils.stringSimilarity('hello', 'hello'), 1.0);
        expect(
          ParsingUtils.stringSimilarity('test case', 'test case'),
          1.0,
        );
      });

      test('should return 0.0 for completely different strings', () {
        expect(ParsingUtils.stringSimilarity('hello', 'world'), 0.0);
      });

      test('should return value between 0 and 1 for partial matches', () {
        final similarity =
            ParsingUtils.stringSimilarity('hello world', 'hello there');
        expect(similarity, greaterThan(0.0));
        expect(similarity, lessThan(1.0));
      });

      test('should handle empty strings', () {
        expect(ParsingUtils.stringSimilarity('', ''), 1.0);
        expect(ParsingUtils.stringSimilarity('hello', ''), 0.0);
        expect(ParsingUtils.stringSimilarity('', 'world'), 0.0);
      });
    });

    group('findTemperature', () {
      test('should find temperature in text', () {
        expect(
          ParsingUtils.findTemperature('Bake at 350°F'),
          isNotNull,
        );
        expect(
          ParsingUtils.findTemperature('Heat to 180°C'),
          isNotNull,
        );
        expect(
          ParsingUtils.findTemperature('350 degrees'),
          isNotNull,
        );
        expect(
          ParsingUtils.findTemperature('Preheat to 425F'),
          isNotNull,
        );
      });

      test('should return null if no temperature found', () {
        expect(ParsingUtils.findTemperature('Add flour'), null);
        expect(ParsingUtils.findTemperature('Mix well'), null);
      });
    });

    group('findTimeDuration', () {
      test('should find time duration in text', () {
        expect(
          ParsingUtils.findTimeDuration('Bake for 30 minutes'),
          isNotNull,
        );
        expect(
          ParsingUtils.findTimeDuration('Cook 2 hours'),
          isNotNull,
        );
        expect(
          ParsingUtils.findTimeDuration('Wait 10 mins'),
          isNotNull,
        );
        expect(
          ParsingUtils.findTimeDuration('Rest for 1hr'),
          isNotNull,
        );
      });

      test('should return null if no time duration found', () {
        expect(ParsingUtils.findTimeDuration('Add flour'), null);
        expect(ParsingUtils.findTimeDuration('Mix well'), null);
      });
    });

    group('splitIntoLines', () {
      test('should split text into lines', () {
        final result = ParsingUtils.splitIntoLines('Line 1\nLine 2\nLine 3');
        expect(result, ['Line 1', 'Line 2', 'Line 3']);
      });

      test('should remove empty lines', () {
        final result =
            ParsingUtils.splitIntoLines('Line 1\n\nLine 2\n  \nLine 3');
        expect(result, ['Line 1', 'Line 2', 'Line 3']);
      });

      test('should clean each line', () {
        final result =
            ParsingUtils.splitIntoLines('  Line 1  \n  Line 2  \n  Line 3  ');
        expect(result, ['Line 1', 'Line 2', 'Line 3']);
      });
    });

    group('containsNumber', () {
      test('should return true if text contains number', () {
        expect(ParsingUtils.containsNumber('2 cups'), true);
        expect(ParsingUtils.containsNumber('Step 1'), true);
        expect(ParsingUtils.containsNumber('350°F'), true);
      });

      test('should return false if text has no number', () {
        expect(ParsingUtils.containsNumber('flour'), false);
        expect(ParsingUtils.containsNumber('Mix well'), false);
      });
    });

    group('isValidCookingUnit', () {
      test('should validate common cooking units', () {
        expect(ParsingUtils.isValidCookingUnit('cup'), true);
        expect(ParsingUtils.isValidCookingUnit('cups'), true);
        expect(ParsingUtils.isValidCookingUnit('tablespoon'), true);
        expect(ParsingUtils.isValidCookingUnit('teaspoon'), true);
        expect(ParsingUtils.isValidCookingUnit('ounce'), true);
        expect(ParsingUtils.isValidCookingUnit('pound'), true);
      });

      test('should handle case insensitive', () {
        expect(ParsingUtils.isValidCookingUnit('CUP'), true);
        expect(ParsingUtils.isValidCookingUnit('Tablespoon'), true);
      });

      test('should return false for invalid units', () {
        expect(ParsingUtils.isValidCookingUnit('blah'), false);
        expect(ParsingUtils.isValidCookingUnit('xyz'), false);
      });
    });
  });
}
