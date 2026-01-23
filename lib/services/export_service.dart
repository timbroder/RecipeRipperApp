import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/recipe.dart';
import 'database_service.dart';

/// Supported export formats
enum ExportFormat {
  json,
  markdown,
}

/// Result of an export operation
class ExportResult {
  final bool success;
  final String? filePath;
  final String? content;
  final String? errorMessage;

  ExportResult({
    required this.success,
    this.filePath,
    this.content,
    this.errorMessage,
  });

  factory ExportResult.success({String? filePath, String? content}) {
    return ExportResult(success: true, filePath: filePath, content: content);
  }

  factory ExportResult.failure(String errorMessage) {
    return ExportResult(success: false, errorMessage: errorMessage);
  }
}

/// Service for exporting recipes to JSON and Markdown formats
class ExportService {
  final DatabaseService _databaseService;

  ExportService(this._databaseService);

  /// Export a single recipe to the specified format
  Future<ExportResult> exportRecipe(
    Recipe recipe,
    ExportFormat format,
  ) async {
    try {
      final content = format == ExportFormat.json
          ? _recipeToJson(recipe)
          : _recipeToMarkdown(recipe);

      return ExportResult.success(content: content);
    } catch (e) {
      return ExportResult.failure('Failed to export recipe: $e');
    }
  }

  /// Export a single recipe to a file and share it
  Future<ExportResult> exportAndShareRecipe(
    Recipe recipe,
    ExportFormat format,
  ) async {
    try {
      final content = format == ExportFormat.json
          ? _recipeToJson(recipe)
          : _recipeToMarkdown(recipe);

      final extension = format == ExportFormat.json ? 'json' : 'md';
      final sanitizedTitle = _sanitizeFileName(recipe.title);
      final fileName = '$sanitizedTitle.$extension';

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(content);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: recipe.title,
        text: 'Recipe: ${recipe.title}',
      );

      return ExportResult.success(filePath: file.path, content: content);
    } catch (e) {
      return ExportResult.failure('Failed to export and share recipe: $e');
    }
  }

  /// Export all recipes to a single JSON file
  Future<ExportResult> exportAllRecipesToJson() async {
    try {
      final recipes = await _databaseService.getAllRecipes();
      if (recipes.isEmpty) {
        return ExportResult.failure('No recipes to export');
      }

      final exportData = {
        'version': '1.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'recipeCount': recipes.length,
        'recipes': recipes.map((r) => r.toJson()).toList(),
      };

      final content = const JsonEncoder.withIndent('  ').convert(exportData);
      return ExportResult.success(content: content);
    } catch (e) {
      return ExportResult.failure('Failed to export recipes: $e');
    }
  }

  /// Export all recipes to a JSON file and share it
  Future<ExportResult> exportAllRecipesAndShare() async {
    try {
      final result = await exportAllRecipesToJson();
      if (!result.success) return result;

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/recipes_export_$timestamp.json');
      await file.writeAsString(result.content!);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'My Recipes Export',
        text: 'All recipes exported from RecipeRipper',
      );

      return ExportResult.success(filePath: file.path, content: result.content);
    } catch (e) {
      return ExportResult.failure('Failed to export and share recipes: $e');
    }
  }

  /// Export all recipes to a combined Markdown file
  Future<ExportResult> exportAllRecipesToMarkdown() async {
    try {
      final recipes = await _databaseService.getAllRecipes();
      if (recipes.isEmpty) {
        return ExportResult.failure('No recipes to export');
      }

      final buffer = StringBuffer();
      buffer.writeln('# My Recipe Collection');
      buffer.writeln();
      buffer.writeln('*Exported from RecipeRipper*');
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();

      // Table of contents
      buffer.writeln('## Table of Contents');
      buffer.writeln();
      for (var i = 0; i < recipes.length; i++) {
        final recipe = recipes[i];
        final anchor = _sanitizeAnchor(recipe.title);
        buffer.writeln('${i + 1}. [${recipe.title}](#$anchor)');
      }
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();

      // Recipe content
      for (final recipe in recipes) {
        buffer.writeln(_recipeToMarkdown(recipe));
        buffer.writeln();
        buffer.writeln('---');
        buffer.writeln();
      }

      return ExportResult.success(content: buffer.toString());
    } catch (e) {
      return ExportResult.failure('Failed to export recipes: $e');
    }
  }

  /// Share recipe as text (for quick sharing via messages, etc.)
  Future<void> shareRecipeAsText(Recipe recipe) async {
    final text = _recipeToPlainText(recipe);
    await Share.share(text, subject: recipe.title);
  }

  /// Copy recipe to clipboard as markdown
  String getRecipeAsMarkdown(Recipe recipe) {
    return _recipeToMarkdown(recipe);
  }

  /// Copy recipe to clipboard as JSON
  String getRecipeAsJson(Recipe recipe) {
    return _recipeToJson(recipe);
  }

  /// Convert a recipe to JSON string
  String _recipeToJson(Recipe recipe) {
    return const JsonEncoder.withIndent('  ').convert(recipe.toJson());
  }

  /// Convert a recipe to Markdown string
  String _recipeToMarkdown(Recipe recipe) {
    final buffer = StringBuffer();

    // Title
    buffer.writeln('# ${recipe.title}');
    buffer.writeln();

    // Source info
    if (recipe.sourceUrl != null && recipe.sourceUrl!.isNotEmpty) {
      buffer.writeln('**Source:** [${recipe.sourcePlatform ?? 'Link'}](${recipe.sourceUrl})');
      buffer.writeln();
    }

    // Ingredients section
    buffer.writeln('## Ingredients');
    buffer.writeln();
    if (recipe.ingredients.isEmpty) {
      buffer.writeln('*No ingredients listed*');
    } else {
      for (final ingredient in recipe.ingredients) {
        buffer.writeln('- ${ingredient.toDisplayString()}');
      }
    }
    buffer.writeln();

    // Directions section
    buffer.writeln('## Directions');
    buffer.writeln();
    if (recipe.directions.isEmpty) {
      buffer.writeln('*No directions listed*');
    } else {
      for (final direction in recipe.directions) {
        buffer.writeln('${direction.stepNumber}. ${direction.text}');
        buffer.writeln();
      }
    }

    // Metadata footer
    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln('*Recipe extracted by RecipeRipper*');

    return buffer.toString();
  }

  /// Convert a recipe to plain text (for sharing via messages)
  String _recipeToPlainText(Recipe recipe) {
    final buffer = StringBuffer();

    buffer.writeln(recipe.title.toUpperCase());
    buffer.writeln();

    if (recipe.sourceUrl != null && recipe.sourceUrl!.isNotEmpty) {
      buffer.writeln('Source: ${recipe.sourceUrl}');
      buffer.writeln();
    }

    buffer.writeln('INGREDIENTS:');
    if (recipe.ingredients.isEmpty) {
      buffer.writeln('(No ingredients listed)');
    } else {
      for (final ingredient in recipe.ingredients) {
        buffer.writeln('• ${ingredient.toDisplayString()}');
      }
    }
    buffer.writeln();

    buffer.writeln('DIRECTIONS:');
    if (recipe.directions.isEmpty) {
      buffer.writeln('(No directions listed)');
    } else {
      for (final direction in recipe.directions) {
        buffer.writeln('${direction.stepNumber}. ${direction.text}');
      }
    }

    return buffer.toString();
  }

  /// Sanitize a string for use as a filename
  String _sanitizeFileName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .substring(0, name.length > 50 ? 50 : name.length);
  }

  /// Sanitize a string for use as a markdown anchor
  String _sanitizeAnchor(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
  }

  /// Get storage usage for all recipes
  Future<int> getStorageUsageBytes() async {
    try {
      final recipes = await _databaseService.getAllRecipes();
      var totalBytes = 0;

      for (final recipe in recipes) {
        // Estimate JSON size
        final json = _recipeToJson(recipe);
        totalBytes += json.length;

        // Add thumbnail size if exists
        if (recipe.thumbnailPath != null) {
          final file = File(recipe.thumbnailPath!);
          if (await file.exists()) {
            totalBytes += await file.length();
          }
        }
      }

      return totalBytes;
    } catch (e) {
      return 0;
    }
  }

  /// Format bytes to human-readable string
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
