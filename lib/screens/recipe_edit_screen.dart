import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../models/ingredient.dart';
import '../models/direction.dart';
import '../services/database_service.dart';

class RecipeEditScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeEditScreen({
    super.key,
    required this.recipe,
  });

  @override
  State<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends State<RecipeEditScreen> {
  late TextEditingController _titleController;
  late List<Ingredient> _ingredients;
  late List<Direction> _directions;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.recipe.title);
    _ingredients = List.from(widget.recipe.ingredients);
    _directions = List.from(widget.recipe.directions);

    _titleController.addListener(() => _markChanged());
  }

  @override
  void dispose() {
    _titleController.dispose();
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

    final updatedRecipe = widget.recipe.copyWith(
      title: _titleController.text.trim(),
      ingredients: _ingredients,
      directions: _directions,
      updatedAt: DateTime.now(),
    );

    final databaseService = context.read<DatabaseService>();
    await databaseService.updateRecipe(updatedRecipe);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipe saved')),
      );
      Navigator.pop(context, updatedRecipe);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
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
            TextButton.icon(
              onPressed: _saveRecipe,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return TextField(
      controller: _titleController,
      decoration: const InputDecoration(
        labelText: 'Recipe Title',
        border: OutlineInputBorder(),
      ),
      style: Theme.of(context).textTheme.titleLarge,
    );
  }

  Widget _buildIngredientsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ingredients',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                setState(() {
                  _ingredients.add(
                    Ingredient(
                      item: '',
                      order: _ingredients.length,
                    ),
                  );
                  _markChanged();
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_ingredients.isEmpty)
          Center(
            child: Text(
              'No ingredients yet. Tap + to add one.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
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
    );
  }

  Widget _buildIngredientTile(int index) {
    final ingredient = _ingredients[index];

    return Card(
      key: ValueKey('ingredient_$index'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            const Icon(Icons.drag_handle),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: TextEditingController(text: ingredient.item),
                decoration: const InputDecoration(
                  labelText: 'Item',
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (value) {
                  _ingredients[index] = ingredient.copyWith(item: value);
                  _markChanged();
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                setState(() {
                  _ingredients.removeAt(index);
                  _markChanged();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Directions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                setState(() {
                  _directions.add(
                    Direction(
                      stepNumber: _directions.length + 1,
                      text: '',
                    ),
                  );
                  _markChanged();
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_directions.isEmpty)
          Center(
            child: Text(
              'No directions yet. Tap + to add one.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
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
                // Renumber all directions
                for (var i = 0; i < _directions.length; i++) {
                  _directions[i] = _directions[i].copyWith(stepNumber: i + 1);
                }
                _markChanged();
              });
            },
            itemBuilder: (context, index) {
              return _buildDirectionTile(index);
            },
          ),
      ],
    );
  }

  Widget _buildDirectionTile(int index) {
    final direction = _directions[index];

    return Card(
      key: ValueKey('direction_$index'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.drag_handle),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              child: Text('${index + 1}'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: TextEditingController(text: direction.text),
                decoration: const InputDecoration(
                  labelText: 'Step',
                  border: InputBorder.none,
                  isDense: true,
                ),
                maxLines: null,
                onChanged: (value) {
                  _directions[index] = direction.copyWith(text: value);
                  _markChanged();
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                setState(() {
                  _directions.removeAt(index);
                  // Renumber remaining directions
                  for (var i = 0; i < _directions.length; i++) {
                    _directions[i] = _directions[i].copyWith(stepNumber: i + 1);
                  }
                  _markChanged();
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
