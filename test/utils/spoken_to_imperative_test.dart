import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_ripper/utils/spoken_to_imperative.dart';

void main() {
  group('SpokenToImperative', () {
    group('convert', () {
      test('converts "I\'m gonna add X"', () {
        expect(
          SpokenToImperative.convert("I'm gonna add the flour"),
          equals('Add the flour'),
        );
        expect(
          SpokenToImperative.convert("I'm going to add the flour"),
          equals('Add the flour'),
        );
      });

      test('converts "you\'re gonna wanna stir"', () {
        expect(
          SpokenToImperative.convert("you're gonna wanna stir this"),
          equals('Stir this'),
        );
        expect(
          SpokenToImperative.convert("you're going to want to mix it"),
          equals('Mix it'),
        );
      });

      test('converts "we\'re going to cook this"', () {
        expect(
          SpokenToImperative.convert("we're going to cook this for 10 minutes"),
          equals('Cook this for 10 minutes'),
        );
        expect(
          SpokenToImperative.convert("we're gonna let it simmer"),
          equals('Let it simmer'),
        );
      });

      test('converts "go ahead and mix"', () {
        expect(
          SpokenToImperative.convert('go ahead and mix the ingredients'),
          equals('Mix the ingredients'),
        );
      });

      test('converts "make sure you/to preheat"', () {
        expect(
          SpokenToImperative.convert('make sure you preheat the oven'),
          equals('Preheat the oven'),
        );
        expect(
          SpokenToImperative.convert('make sure to preheat the oven'),
          equals('Preheat the oven'),
        );
      });

      test('converts "what you do is blend"', () {
        expect(
          SpokenToImperative.convert('what you do is blend until smooth'),
          equals('Blend until smooth'),
        );
      });

      test('converts "so now we add"', () {
        expect(
          SpokenToImperative.convert('so now we add the eggs'),
          equals('Add the eggs'),
        );
      });

      test('converts "I like to let it sit"', () {
        expect(
          SpokenToImperative.convert('I like to let it sit for 5 minutes'),
          equals('Let it sit for 5 minutes'),
        );
      });

      test('converts "you just" prefix', () {
        expect(
          SpokenToImperative.convert('you just pour it over the top'),
          equals('Pour it over the top'),
        );
      });

      test('converts "now we/you" prefix', () {
        expect(
          SpokenToImperative.convert('now we fold in the cheese'),
          equals('Fold in the cheese'),
        );
      });

      test('converts "then we/you" prefix', () {
        expect(
          SpokenToImperative.convert('and then you bake for 20 minutes'),
          equals('Bake for 20 minutes'),
        );
      });

      test('strips trailing filler', () {
        expect(
          SpokenToImperative.convert('mix it well and then...'),
          equals('Mix it well'),
        );
        expect(
          SpokenToImperative.convert('stir the batter you know'),
          equals('Stir the batter'),
        );
      });

      test('capitalizes first letter', () {
        expect(
          SpokenToImperative.convert('go ahead and mix well'),
          equals('Mix well'),
        );
      });

      test('preserves already imperative text', () {
        expect(
          SpokenToImperative.convert('Preheat oven to 350F'),
          equals('Preheat oven to 350F'),
        );
        expect(
          SpokenToImperative.convert('Mix dry ingredients together'),
          equals('Mix dry ingredients together'),
        );
      });

      test('handles empty string', () {
        expect(SpokenToImperative.convert(''), equals(''));
      });

      test('cleans multiple spaces', () {
        expect(
          SpokenToImperative.convert('go ahead and  mix   well'),
          equals('Mix well'),
        );
      });
    });

    group('convertAll', () {
      test('converts list of texts', () {
        final result = SpokenToImperative.convertAll([
          "I'm gonna add flour",
          'Preheat oven to 350F',
          'go ahead and mix well',
        ]);
        expect(result, [
          'Add flour',
          'Preheat oven to 350F',
          'Mix well',
        ]);
      });

      test('filters out empty results', () {
        final result = SpokenToImperative.convertAll([
          "I'm gonna add flour",
          '',
          'Mix well',
        ]);
        expect(result, ['Add flour', 'Mix well']);
      });
    });
  });
}
