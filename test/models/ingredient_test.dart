import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_ripper/models/ingredient.dart';

void main() {
  group('Ingredient', () {
    test('creates ingredient with required fields', () {
      final ingredient = Ingredient(item: 'flour');

      expect(ingredient.item, equals('flour'));
      expect(ingredient.quantity, isNull);
      expect(ingredient.unit, isNull);
      expect(ingredient.notes, isNull);
      expect(ingredient.order, equals(0));
    });

    test('creates ingredient with all fields', () {
      final ingredient = Ingredient(
        item: 'flour',
        quantity: 2,
        unit: 'cups',
        notes: 'all-purpose',
        order: 1,
      );

      expect(ingredient.item, equals('flour'));
      expect(ingredient.quantity, equals(2));
      expect(ingredient.unit, equals('cups'));
      expect(ingredient.notes, equals('all-purpose'));
      expect(ingredient.order, equals(1));
    });

    test('toDisplayString() formats correctly with quantity and unit', () {
      final ingredient = Ingredient(item: 'flour', quantity: 2, unit: 'cups');

      expect(ingredient.toDisplayString(), equals('2 cups flour'));
    });

    test('toDisplayString() formats correctly with fractional quantity', () {
      final ingredient = Ingredient(item: 'sugar', quantity: 0.5, unit: 'cup');

      expect(ingredient.toDisplayString(), equals('0.5 cup sugar'));
    });

    test('toDisplayString() formats correctly with notes', () {
      final ingredient = Ingredient(
        item: 'flour',
        quantity: 2,
        unit: 'cups',
        notes: 'sifted',
      );

      expect(ingredient.toDisplayString(), equals('2 cups flour (sifted)'));
    });

    test('toDisplayString() formats correctly without quantity', () {
      final ingredient = Ingredient(item: 'salt', unit: 'pinch');

      expect(ingredient.toDisplayString(), equals('pinch salt'));
    });

    test('toDisplayString() formats correctly with only item', () {
      final ingredient = Ingredient(item: 'eggs');

      expect(ingredient.toDisplayString(), equals('eggs'));
    });

    test('toJson() and fromJson() work correctly', () {
      final ingredient = Ingredient(
        item: 'flour',
        quantity: 2,
        unit: 'cups',
        notes: 'all-purpose',
        order: 1,
      );

      final json = ingredient.toJson();
      final restored = Ingredient.fromJson(json);

      expect(restored.item, equals(ingredient.item));
      expect(restored.quantity, equals(ingredient.quantity));
      expect(restored.unit, equals(ingredient.unit));
      expect(restored.notes, equals(ingredient.notes));
      expect(restored.order, equals(ingredient.order));
    });

    test('copyWith() updates only specified fields', () {
      final original = Ingredient(item: 'flour', quantity: 2, unit: 'cups');

      final updated = original.copyWith(quantity: 3);

      expect(updated.item, equals('flour'));
      expect(updated.quantity, equals(3));
      expect(updated.unit, equals('cups'));
    });

    test('equality works correctly', () {
      final ingredient1 = Ingredient(
        id: '1',
        item: 'flour',
        quantity: 2,
        unit: 'cups',
      );

      final ingredient2 = Ingredient(
        id: '1',
        item: 'flour',
        quantity: 2,
        unit: 'cups',
      );

      final ingredient3 = Ingredient(
        id: '2',
        item: 'flour',
        quantity: 2,
        unit: 'cups',
      );

      expect(ingredient1, equals(ingredient2));
      expect(ingredient1, isNot(equals(ingredient3)));
    });
  });
}
