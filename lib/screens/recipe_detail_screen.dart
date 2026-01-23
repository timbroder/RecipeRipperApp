import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/recipe.dart';
import '../providers/recipe_provider.dart';
import '../providers/sync_provider.dart';
import '../services/export_service.dart';
import '../widgets/widgets.dart';
import 'recipe_edit_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late Recipe _recipe;
  bool _cookingMode = false;
  Set<int> _checkedIngredients = {};
  Set<int> _checkedDirections = {};
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
  }

  Future<void> _deleteRecipe() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recipe'),
        content: const Text(
          'Are you sure you want to delete this recipe? This action cannot be undone.',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<RecipeProvider>();
      final success = await provider.deleteRecipe(_recipe.id!);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipe deleted')),
        );
        Navigator.pop(context);
      }
    }
  }

  void _toggleCookingMode() {
    setState(() {
      _cookingMode = !_cookingMode;
      if (!_cookingMode) {
        // Reset checked items when exiting cooking mode
        _checkedIngredients = {};
        _checkedDirections = {};
        _currentStep = 0;
      }
    });
  }

  void _toggleIngredient(int index) {
    setState(() {
      if (_checkedIngredients.contains(index)) {
        _checkedIngredients.remove(index);
      } else {
        _checkedIngredients.add(index);
      }
    });
  }

  void _toggleDirection(int index) {
    setState(() {
      if (_checkedDirections.contains(index)) {
        _checkedDirections.remove(index);
      } else {
        _checkedDirections.add(index);
        // Auto-advance to next step
        if (index == _currentStep &&
            _currentStep < _recipe.directions.length - 1) {
          _currentStep++;
        }
      }
    });
  }

  Future<void> _shareRecipe() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withAlpha(77),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Share Recipe',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.share,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              title: const Text('Share'),
              subtitle: const Text('Send to other apps'),
              onTap: () {
                Navigator.pop(context);
                _shareAsText();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.file_download,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
              ),
              title: const Text('Export as File'),
              subtitle: const Text('Save as JSON or Markdown file'),
              onTap: () {
                Navigator.pop(context);
                _showExportDialog();
              },
            ),
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.copy,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              title: const Text('Copy as Markdown'),
              subtitle: const Text('Human-readable format'),
              onTap: () {
                Navigator.pop(context);
                _copyAsText();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.code,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              title: const Text('Copy as JSON'),
              subtitle: const Text('For importing elsewhere'),
              onTap: () {
                Navigator.pop(context);
                _copyAsJson();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _shareAsText() async {
    try {
      final syncProvider = context.read<SyncProvider>();
      await syncProvider.exportService.shareRecipeAsText(_recipe);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: $e')),
        );
      }
    }
  }

  Future<void> _showExportDialog() async {
    final format = await showDialog<ExportFormat>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Export Format'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ExportFormat.json),
            child: const ListTile(
              leading: Icon(Icons.code),
              title: Text('JSON'),
              subtitle: Text('Can be re-imported into the app'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ExportFormat.markdown),
            child: const ListTile(
              leading: Icon(Icons.description),
              title: Text('Markdown'),
              subtitle: Text('Human-readable format'),
            ),
          ),
        ],
      ),
    );

    if (format == null) return;

    try {
      final syncProvider = context.read<SyncProvider>();
      final result = await syncProvider.exportService.exportAndShareRecipe(
        _recipe,
        format,
      );

      if (mounted && !result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ${result.errorMessage}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    }
  }

  void _copyAsText() {
    final buffer = StringBuffer();
    buffer.writeln('# ${_recipe.title}');
    buffer.writeln();

    if (_recipe.sourceUrl != null) {
      buffer.writeln('Source: ${_recipe.sourceUrl}');
      buffer.writeln();
    }

    if (_recipe.ingredients.isNotEmpty) {
      buffer.writeln('## Ingredients');
      for (final ingredient in _recipe.ingredients) {
        buffer.writeln('- ${ingredient.toDisplayString()}');
      }
      buffer.writeln();
    }

    if (_recipe.directions.isNotEmpty) {
      buffer.writeln('## Directions');
      for (final direction in _recipe.directions) {
        buffer.writeln('${direction.stepNumber}. ${direction.text}');
      }
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recipe copied to clipboard')),
    );
  }

  void _copyAsJson() {
    final jsonStr =
        const JsonEncoder.withIndent('  ').convert(_recipe.toJson());
    Clipboard.setData(ClipboardData(text: jsonStr));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('JSON copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(colorScheme),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                if (_cookingMode) _buildCookingModeIndicator(),
                _buildIngredientsSection(),
                _buildDirectionsSection(),
                if (_recipe.metadata != null) _buildMetadataSection(),
                const SizedBox(height: 100), // Bottom padding for FAB
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _cookingMode
          ? FloatingActionButton.extended(
              onPressed: _toggleCookingMode,
              icon: const Icon(Icons.check),
              label: const Text('Exit Cooking Mode'),
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
            )
          : FloatingActionButton.extended(
              onPressed: _toggleCookingMode,
              icon: const Icon(Icons.restaurant),
              label: const Text('Start Cooking'),
            ),
    );
  }

  Widget _buildSliverAppBar(ColorScheme colorScheme) {
    return SliverAppBar(
      expandedHeight: _recipe.thumbnailPath != null ? 250 : 0,
      pinned: true,
      flexibleSpace: _recipe.thumbnailPath != null
          ? FlexibleSpaceBar(
              background: Hero(
                tag: 'recipe_thumbnail_${_recipe.id ?? _recipe.title}',
                child: _buildThumbnail(),
              ),
            )
          : null,
      actions: [
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: _shareRecipe,
        ),
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () async {
            final editedRecipe = await Navigator.push<Recipe>(
              context,
              MaterialPageRoute(
                builder: (context) => RecipeEditScreen(recipe: _recipe),
              ),
            );

            if (editedRecipe != null) {
              setState(() => _recipe = editedRecipe);
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete),
          onPressed: _deleteRecipe,
        ),
      ],
    );
  }

  Widget _buildThumbnail() {
    if (_recipe.thumbnailPath != null) {
      final file = File(_recipe.thumbnailPath!);
      if (file.existsSync()) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              file,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholderImage();
              },
            ),
            // Gradient overlay for text visibility
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(128),
                  ],
                ),
              ),
            ),
          ],
        );
      }
    }
    return _buildPlaceholderImage();
  }

  Widget _buildPlaceholderImage() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.restaurant,
          size: 80,
          color: colorScheme.onPrimaryContainer.withAlpha(128),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _recipe.title,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_recipe.sourcePlatform != null || _recipe.sourceUrl != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_recipe.sourcePlatform != null)
                  Chip(
                    avatar: Icon(
                      _getPlatformIcon(_recipe.sourcePlatform!),
                      size: 18,
                    ),
                    label: Text(_recipe.sourcePlatform!),
                    visualDensity: VisualDensity.compact,
                  ),
                if (_recipe.ingredients.isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.shopping_basket, size: 18),
                    label: Text('${_recipe.ingredients.length} ingredients'),
                    visualDensity: VisualDensity.compact,
                  ),
                if (_recipe.directions.isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.format_list_numbered, size: 18),
                    label: Text('${_recipe.directions.length} steps'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCookingModeIndicator() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final ingredientProgress = _recipe.ingredients.isEmpty
        ? 0.0
        : _checkedIngredients.length / _recipe.ingredients.length;
    final directionProgress = _recipe.directions.isEmpty
        ? 0.0
        : _checkedDirections.length / _recipe.directions.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withAlpha(77),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withAlpha(77),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.restaurant,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Cooking Mode',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ingredients',
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: ingredientProgress,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_checkedIngredients.length}/${_recipe.ingredients.length}',
                      style: textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Steps',
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: directionProgress,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_checkedDirections.length}/${_recipe.directions.length}',
                      style: textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shopping_basket,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Ingredients',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_recipe.ingredients.isEmpty)
            EmptyState.noIngredients()
          else
            ...List.generate(_recipe.ingredients.length, (index) {
              final ingredient = _recipe.ingredients[index];
              return IngredientItem(
                ingredient: ingredient,
                showCheckbox: _cookingMode,
                isChecked: _checkedIngredients.contains(index),
                onCheckChanged: (value) => _toggleIngredient(index),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDirectionsSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.format_list_numbered,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Directions',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_recipe.directions.isEmpty)
            EmptyState.noDirections()
          else
            ...List.generate(_recipe.directions.length, (index) {
              final direction = _recipe.directions[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: DirectionStep(
                  direction: direction,
                  showCheckbox: _cookingMode,
                  isChecked: _checkedDirections.contains(index),
                  isActive: _cookingMode && index == _currentStep,
                  onCheckChanged: (value) => _toggleDirection(index),
                  onTap: _cookingMode
                      ? () {
                          setState(() => _currentStep = index);
                        }
                      : null,
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMetadataSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final metadata = _recipe.metadata!;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'Processing Info',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface.withAlpha(179),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (metadata.processingTimeSeconds != null)
                    _buildMetadataRow(
                      Icons.timer,
                      'Processing Time',
                      _formatDuration(metadata.processingTimeSeconds!),
                    ),
                  if (metadata.videoDuration != null)
                    _buildMetadataRow(
                      Icons.video_library,
                      'Video Duration',
                      metadata.videoDuration!,
                    ),
                  if (metadata.frameCount != null)
                    _buildMetadataRow(
                      Icons.image,
                      'Frames Analyzed',
                      '${metadata.frameCount}',
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(IconData icon, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    }
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (remainingSeconds == 0) {
      return '${minutes}m';
    }
    return '${minutes}m ${remainingSeconds}s';
  }

  IconData _getPlatformIcon(String platform) {
    final lower = platform.toLowerCase();
    if (lower.contains('youtube')) return Icons.play_circle_outline;
    if (lower.contains('vimeo')) return Icons.ondemand_video;
    if (lower.contains('tiktok')) return Icons.music_note;
    if (lower.contains('instagram')) return Icons.camera_alt;
    if (lower.contains('local')) return Icons.folder;
    return Icons.link;
  }
}
