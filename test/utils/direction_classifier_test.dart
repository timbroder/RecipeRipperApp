import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_ripper_app/utils/direction_classifier.dart';

void main() {
  group('DirectionClassifier', () {
    group('classifyAsDirection', () {
      test('should score high for typical direction lines', () {
        expect(
          DirectionClassifier.classifyAsDirection('Mix the flour and sugar together'),
          greaterThan(0.5),
        );
        expect(
          DirectionClassifier.classifyAsDirection('Bake at 350°F for 30 minutes'),
          greaterThan(0.5),
        );
        expect(
          DirectionClassifier.classifyAsDirection('Add the eggs one at a time'),
          greaterThan(0.5),
        );
        expect(
          DirectionClassifier.classifyAsDirection('Preheat the oven to 375 degrees'),
          greaterThan(0.5),
        );
      });

      test('should score high for numbered steps', () {
        expect(
          DirectionClassifier.classifyAsDirection('1. Mix the ingredients'),
          greaterThan(0.7),
        );
        expect(
          DirectionClassifier.classifyAsDirection('Step 2: Add the eggs'),
          greaterThan(0.7),
        );
      });

      test('should score high for lines with cooking verbs', () {
        expect(
          DirectionClassifier.classifyAsDirection('Stir constantly until thickened'),
          greaterThan(0.5),
        );
        expect(
          DirectionClassifier.classifyAsDirection('Whisk together in a large bowl'),
          greaterThan(0.5),
        );
      });

      test('should score high for lines with temperature or time', () {
        expect(
          DirectionClassifier.classifyAsDirection('Cook for 20 minutes'),
          greaterThan(0.5),
        );
        expect(
          DirectionClassifier.classifyAsDirection('Heat to 180°C'),
          greaterThan(0.5),
        );
      });

      test('should score low for ingredient-like lines', () {
        expect(
          DirectionClassifier.classifyAsDirection('2 cups flour'),
          lessThan(0.5),
        );
        expect(
          DirectionClassifier.classifyAsDirection('1 tablespoon salt'),
          lessThan(0.5),
        );
        expect(
          DirectionClassifier.classifyAsDirection('3 large eggs'),
          lessThan(0.5),
        );
      });

      test('should score low for very short text', () {
        expect(
          DirectionClassifier.classifyAsDirection('Mix'),
          lessThan(0.5),
        );
        expect(
          DirectionClassifier.classifyAsDirection('Bake'),
          lessThan(0.5),
        );
      });

      test('should score high for complex sentences', () {
        expect(
          DirectionClassifier.classifyAsDirection(
            'Mix the dry ingredients together, then add the wet ingredients and stir until just combined',
          ),
          greaterThan(0.6),
        );
      });
    });

    group('cleanDirection', () {
      test('should remove step numbers', () {
        expect(
          DirectionClassifier.cleanDirection('1. Mix the ingredients'),
          'Mix the ingredients',
        );
        expect(
          DirectionClassifier.cleanDirection('2. Add eggs'),
          'Add eggs',
        );
      });

      test('should remove "Step X" prefix', () {
        expect(
          DirectionClassifier.cleanDirection('Step 1: Mix together'),
          'Mix together',
        );
        expect(
          DirectionClassifier.cleanDirection('Step 2 Add eggs'),
          'Add eggs',
        );
      });

      test('should capitalize first letter', () {
        expect(
          DirectionClassifier.cleanDirection('mix the ingredients'),
          'Mix the ingredients',
        );
        expect(
          DirectionClassifier.cleanDirection('1. add eggs'),
          'Add eggs',
        );
      });

      test('should clean whitespace', () {
        expect(
          DirectionClassifier.cleanDirection('  Mix   ingredients  '),
          'Mix ingredients',
        );
      });
    });

    group('assignStepNumbers', () {
      test('should assign sequential step numbers', () {
        final directions = [
          'Mix the ingredients',
          'Add eggs',
          'Bake for 30 minutes',
        ];
        final result = DirectionClassifier.assignStepNumbers(directions);

        expect(result.length, 3);
        expect(result[0]['stepNumber'], 1);
        expect(result[0]['text'], 'Mix the ingredients');
        expect(result[1]['stepNumber'], 2);
        expect(result[1]['text'], 'Add eggs');
        expect(result[2]['stepNumber'], 3);
        expect(result[2]['text'], 'Bake for 30 minutes');
      });

      test('should clean directions while assigning numbers', () {
        final directions = [
          '1. Mix the ingredients',
          'Step 2: Add eggs',
          '3. bake for 30 minutes',
        ];
        final result = DirectionClassifier.assignStepNumbers(directions);

        expect(result[0]['stepNumber'], 1);
        expect(result[0]['text'], 'Mix the ingredients');
        expect(result[1]['stepNumber'], 2);
        expect(result[1]['text'], 'Add eggs');
        expect(result[2]['stepNumber'], 3);
        expect(result[2]['text'], 'Bake for 30 minutes');
      });

      test('should handle empty list', () {
        final result = DirectionClassifier.assignStepNumbers([]);
        expect(result, isEmpty);
      });
    });
  });
}
