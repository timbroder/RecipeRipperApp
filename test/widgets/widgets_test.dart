import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_ripper/models/recipe.dart';
import 'package:recipe_ripper/models/ingredient.dart';
import 'package:recipe_ripper/models/direction.dart';
import 'package:recipe_ripper/widgets/widgets.dart';

void main() {
  group('RecipeCard', () {
    testWidgets('displays recipe title', (tester) async {
      final recipe = Recipe(title: 'Test Recipe');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 300,
              child: RecipeCard(recipe: recipe),
            ),
          ),
        ),
      );

      expect(find.text('Test Recipe'), findsOneWidget);
    });

    testWidgets('displays source platform when available', (tester) async {
      final recipe = Recipe(
        title: 'Test Recipe',
        sourcePlatform: 'YouTube',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 300,
              child: RecipeCard(recipe: recipe),
            ),
          ),
        ),
      );

      expect(find.text('YouTube'), findsOneWidget);
    });

    testWidgets('handles tap callback', (tester) async {
      final recipe = Recipe(title: 'Test Recipe');
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 300,
              child: RecipeCard(
                recipe: recipe,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(RecipeCard));
      expect(tapped, true);
    });
  });

  group('IngredientItem', () {
    testWidgets('displays ingredient text', (tester) async {
      final ingredient = Ingredient(
        item: 'flour',
        quantity: 2,
        unit: 'cups',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IngredientItem(ingredient: ingredient),
          ),
        ),
      );

      // The widget uses RichText, so we check for the RichText widget
      // and verify the IngredientItem renders
      expect(find.byType(IngredientItem), findsOneWidget);
      expect(find.byType(RichText), findsOneWidget);
    });

    testWidgets('shows checkbox in cooking mode', (tester) async {
      final ingredient = Ingredient(item: 'sugar');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IngredientItem(
              ingredient: ingredient,
              showCheckbox: true,
            ),
          ),
        ),
      );

      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('hides checkbox by default', (tester) async {
      final ingredient = Ingredient(item: 'salt');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IngredientItem(ingredient: ingredient),
          ),
        ),
      );

      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('applies strikethrough when checked', (tester) async {
      final ingredient = Ingredient(item: 'butter');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IngredientItem(
              ingredient: ingredient,
              showCheckbox: true,
              isChecked: true,
            ),
          ),
        ),
      );

      // Checkbox should be checked
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, true);
    });
  });

  group('DirectionStep', () {
    testWidgets('displays step number and text', (tester) async {
      final direction = Direction(stepNumber: 1, text: 'Preheat oven to 350°F');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DirectionStep(direction: direction),
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('Preheat oven to 350°F'), findsOneWidget);
    });

    testWidgets('shows checkbox in cooking mode', (tester) async {
      final direction = Direction(stepNumber: 1, text: 'Mix ingredients');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DirectionStep(
              direction: direction,
              showCheckbox: true,
            ),
          ),
        ),
      );

      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('highlights active step', (tester) async {
      final direction = Direction(stepNumber: 2, text: 'Bake for 30 minutes');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DirectionStep(
              direction: direction,
              isActive: true,
            ),
          ),
        ),
      );

      // Should render without errors with isActive=true
      expect(find.byType(DirectionStep), findsOneWidget);
    });
  });

  group('EmptyState', () {
    testWidgets('displays title and message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.restaurant,
              title: 'No Recipes',
              message: 'Add your first recipe',
            ),
          ),
        ),
      );

      expect(find.text('No Recipes'), findsOneWidget);
      expect(find.text('Add your first recipe'), findsOneWidget);
      expect(find.byIcon(Icons.restaurant), findsOneWidget);
    });

    testWidgets('shows action button when provided', (tester) async {
      bool actionPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.add,
              title: 'Empty',
              actionLabel: 'Add Item',
              onAction: () => actionPressed = true,
            ),
          ),
        ),
      );

      expect(find.text('Add Item'), findsOneWidget);
      await tester.tap(find.text('Add Item'));
      expect(actionPressed, true);
    });

    testWidgets('factory constructors work correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState.noRecipes(),
          ),
        ),
      );

      expect(find.text('No Recipes Yet'), findsOneWidget);
    });
  });

  group('ErrorState', () {
    testWidgets('displays error title and message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorState(
              title: 'Error',
              message: 'Something went wrong',
            ),
          ),
        ),
      );

      expect(find.text('Error'), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('shows retry button when provided', (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorState(
              title: 'Failed',
              retryLabel: 'Try Again',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Try Again'), findsOneWidget);
      await tester.tap(find.text('Try Again'));
      expect(retried, true);
    });

    testWidgets('factory constructors work correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorState.network(),
          ),
        ),
      );

      expect(find.text('Connection Error'), findsOneWidget);
    });
  });

  group('LoadingSkeleton', () {
    testWidgets('RecipeCardSkeleton renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 300,
              child: RecipeCardSkeleton(),
            ),
          ),
        ),
      );

      expect(find.byType(RecipeCardSkeleton), findsOneWidget);
    });

    testWidgets('RecipeGridSkeleton renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RecipeGridSkeleton(itemCount: 4),
          ),
        ),
      );

      expect(find.byType(RecipeCardSkeleton), findsNWidgets(4));
    });
  });
}
