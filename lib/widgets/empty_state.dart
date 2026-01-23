import 'package:flutter/material.dart';

/// A reusable empty state widget with customizable icon, title, and message.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double iconSize;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.iconSize = 120,
  });

  /// Creates an empty state for no recipes.
  factory EmptyState.noRecipes({VoidCallback? onAddRecipe}) {
    return EmptyState(
      icon: Icons.restaurant_menu,
      title: 'No Recipes Yet',
      message: 'Tap the + button to add your first recipe from a cooking video',
      actionLabel: onAddRecipe != null ? 'Add Recipe' : null,
      onAction: onAddRecipe,
    );
  }

  /// Creates an empty state for no ingredients.
  factory EmptyState.noIngredients({VoidCallback? onAddIngredient}) {
    return EmptyState(
      icon: Icons.shopping_basket_outlined,
      title: 'No Ingredients',
      message: 'This recipe has no ingredients yet',
      actionLabel: onAddIngredient != null ? 'Add Ingredient' : null,
      onAction: onAddIngredient,
      iconSize: 80,
    );
  }

  /// Creates an empty state for no directions.
  factory EmptyState.noDirections({VoidCallback? onAddDirection}) {
    return EmptyState(
      icon: Icons.format_list_numbered,
      title: 'No Directions',
      message: 'This recipe has no directions yet',
      actionLabel: onAddDirection != null ? 'Add Step' : null,
      onAction: onAddDirection,
      iconSize: 80,
    );
  }

  /// Creates an empty state for no search results.
  factory EmptyState.noSearchResults({String? query}) {
    return EmptyState(
      icon: Icons.search_off,
      title: 'No Results Found',
      message: query != null
          ? 'No recipes found matching "$query"'
          : 'Try a different search term',
      iconSize: 80,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withAlpha(77),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: colorScheme.primary.withAlpha(128),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withAlpha(153),
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
