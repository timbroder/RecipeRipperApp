import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../models/ingredient.dart';
import '../models/direction.dart';
import '../providers/recipe_provider.dart';
import '../widgets/widgets.dart';

class RecipeEditScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeEditScreen({super.key, required this.recipe});

  @override
  State<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends State<RecipeEditScreen> {
  late TextEditingController _titleController;
  late List<_IngredientEditItem> _ingredients;
  late List<_DirectionEditItem> _directions;
  bool _hasChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.recipe.title);
    _ingredients = widget.recipe.ingredients.map((i) => _IngredientEditItem(
      ingredient: i,
      controller: TextEditingController(text: i.toDisplayString()),
    )).toList();
    _directions = widget.recipe.directions.map((d) => _DirectionEditItem(
      direction: d,
      controller: TextEditingController(text: d.text),
    )).toList();

    _titleController.addListener(_markChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final item in _ingredients) {
      item.controller.dispose();
    }
    for (final item in _directions) {
      item.controller.dispose();
    }
    super.dispose();
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _saveRecipe() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipe title cannot be empty')),
      );
      return;
    }

    setState(() => _isSaving = true);

    // Parse ingredients from controllers
    final ingredients = <Ingredient>[];
    for (var i = 0; i < _ingredients.length; i++) {
      final text = _ingredients[i].controller.text.trim();
      if (text.isNotEmpty) {
        ingredients.add(Ingredient(
          id: _ingredients[i].ingredient.id,
          recipeId: widget.recipe.id,
          item: text,
          order: i,
        ));
      }
    }

    // Parse directions from controllers
    final directions = <Direction>[];
    for (var i = 0; i < _directions.length; i++) {
      final text = _directions[i].controller.text.trim();
      if (text.isNotEmpty) {
        directions.add(Direction(
          id: _directions[i].direction.id,
          recipeId: widget.recipe.id,
          stepNumber: i + 1,
          text: text,
        ));
      }
    }

    final updatedRecipe = widget.recipe.copyWith(
      title: _titleController.text.trim(),
      ingredients: ingredients,
      directions: directions,
      updatedAt: DateTime.now(),
    );

    final provider = context.read<RecipeProvider>();
    final success = await provider.updateRecipe(updatedRecipe);

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipe saved')),
        );
        Navigator.pop(context, updatedRecipe);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to save recipe'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _addIngredient() {
    setState(() {
      _ingredients.add(_IngredientEditItem(
        ingredient: Ingredient(item: '', order: _ingredients.length),
        controller: TextEditingController(),
      ));
      _markChanged();
    });
    // Focus the new field
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_ingredients.isNotEmpty) {
        _ingredients.last.controller.selection = TextSelection.collapsed(
          offset: _ingredients.last.controller.text.length,
        );
      }
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients[index].controller.dispose();
      _ingredients.removeAt(index);
      _markChanged();
    });
  }

  void _addDirection() {
    setState(() {
      _directions.add(_DirectionEditItem(
        direction: Direction(stepNumber: _directions.length + 1, text: ''),
        controller: TextEditingController(),
      ));
      _markChanged();
    });
  }

  void _removeDirection(int index) {
    setState(() {
      _directions[index].controller.dispose();
      _directions.removeAt(index);
      _markChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Recipe'),
          actions: [
            if (_hasChanges)
              TextButton(
                onPressed: _isSaving ? null : _saveRecipe,
                child: _isSaving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      )
                    : const Text('Save'),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitleField(),
              const SizedBox(height: 24),
              _buildIngredientsSection(),
              const SizedBox(height: 24),
              _buildDirectionsSection(),
              const SizedBox(height: 100), // Bottom padding for keyboard
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _isSaving ? null : _saveRecipe,
          icon: _isSaving
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onPrimary,
                  ),
                )
              : const Icon(Icons.save),
          label: Text(_isSaving ? 'Saving...' : 'Save Recipe'),
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.title, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Recipe Title',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Enter recipe title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientsSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_basket, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Ingredients',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: _addIngredient,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_ingredients.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.shopping_basket_outlined,
                        size: 48,
                        color: colorScheme.onSurface.withAlpha(77),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No ingredients yet',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withAlpha(153),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap "Add" to add your first ingredient',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withAlpha(102),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _ingredients.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _ingredients.removeAt(oldIndex);
                    _ingredients.insert(newIndex, item);
                    _markChanged();
                  });
                },
                itemBuilder: (context, index) {
                  return _buildIngredientTile(index);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientTile(int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final item = _ingredients[index];

    return Container(
      key: ValueKey('ingredient_${item.ingredient.id ?? index}'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(128),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.drag_handle,
                color: colorScheme.onSurface.withAlpha(128),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: item.controller,
              decoration: InputDecoration(
                hintText: 'e.g., 2 cups flour',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
              ),
              onChanged: (_) => _markChanged(),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              color: colorScheme.error,
              size: 20,
            ),
            onPressed: () => _removeIngredient(index),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionsSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.format_list_numbered, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Directions',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: _addDirection,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_directions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.format_list_numbered,
                        size: 48,
                        color: colorScheme.onSurface.withAlpha(77),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No directions yet',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withAlpha(153),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap "Add" to add your first step',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withAlpha(102),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _directions.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _directions.removeAt(oldIndex);
                    _directions.insert(newIndex, item);
                    _markChanged();
                  });
                },
                itemBuilder: (context, index) {
                  return _buildDirectionTile(index);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectionTile(int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final item = _directions[index];

    return Container(
      key: ValueKey('direction_${item.direction.id ?? index}'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(128),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.drag_handle,
                color: colorScheme.onSurface.withAlpha(128),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                '${index + 1}',
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: item.controller,
              decoration: InputDecoration(
                hintText: 'Describe this step...',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              onChanged: (_) => _markChanged(),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              color: colorScheme.error,
              size: 20,
            ),
            onPressed: () => _removeDirection(index),
          ),
        ],
      ),
    );
  }
}

/// Helper class to hold ingredient with its controller
class _IngredientEditItem {
  final Ingredient ingredient;
  final TextEditingController controller;

  _IngredientEditItem({
    required this.ingredient,
    required this.controller,
  });
}

/// Helper class to hold direction with its controller
class _DirectionEditItem {
  final Direction direction;
  final TextEditingController controller;

  _DirectionEditItem({
    required this.direction,
    required this.controller,
  });
}
