import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_ripper/models/direction.dart';

void main() {
  group('Direction', () {
    test('creates direction with required fields', () {
      final direction = Direction(
        stepNumber: 1,
        text: 'Preheat oven to 350°F',
      );

      expect(direction.stepNumber, equals(1));
      expect(direction.text, equals('Preheat oven to 350°F'));
      expect(direction.id, isNull);
      expect(direction.recipeId, isNull);
    });

    test('toDisplayString() formats correctly', () {
      final direction = Direction(
        stepNumber: 1,
        text: 'Mix all ingredients',
      );

      expect(direction.toDisplayString(), equals('1. Mix all ingredients'));
    });

    test('toJson() and fromJson() work correctly', () {
      final direction = Direction(
        stepNumber: 2,
        text: 'Bake for 30 minutes',
      );

      final json = direction.toJson();
      final restored = Direction.fromJson(json);

      expect(restored.stepNumber, equals(direction.stepNumber));
      expect(restored.text, equals(direction.text));
    });

    test('toMap() and fromMap() work correctly', () {
      final direction = Direction(
        id: '123',
        recipeId: '456',
        stepNumber: 3,
        text: 'Let cool',
      );

      final map = direction.toMap();
      final restored = Direction.fromMap(map);

      expect(restored.id, equals(direction.id));
      expect(restored.recipeId, equals(direction.recipeId));
      expect(restored.stepNumber, equals(direction.stepNumber));
      expect(restored.text, equals(direction.text));
    });

    test('copyWith() updates only specified fields', () {
      final original = Direction(
        stepNumber: 1,
        text: 'Original text',
      );

      final updated = original.copyWith(text: 'Updated text');

      expect(updated.stepNumber, equals(1));
      expect(updated.text, equals('Updated text'));
    });

    test('equality works correctly', () {
      final direction1 = Direction(
        id: '1',
        stepNumber: 1,
        text: 'Mix ingredients',
      );

      final direction2 = Direction(
        id: '1',
        stepNumber: 1,
        text: 'Mix ingredients',
      );

      final direction3 = Direction(
        id: '2',
        stepNumber: 1,
        text: 'Mix ingredients',
      );

      expect(direction1, equals(direction2));
      expect(direction1, isNot(equals(direction3)));
    });
  });
}
