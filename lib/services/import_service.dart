import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../models/recipe.dart';
import '../models/ingredient.dart';
import '../models/direction.dart';
import 'database_service.dart';

/// Result of a validation check
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  factory ValidationResult.valid({List<String> warnings = const []}) {
    return ValidationResult(isValid: true, warnings: warnings);
  }

  factory ValidationResult.invalid(List<String> errors) {
    return ValidationResult(isValid: false, errors: errors);
  }
}

/// Result of an import operation
class ImportResult {
  final bool success;
  final int importedCount;
  final int skippedCount;
  final int failedCount;
  final List<String> importedRecipes;
  final List<String> skippedRecipes;
  final List<String> errors;
  final String? errorMessage;

  ImportResult({
    required this.success,
    this.importedCount = 0,
    this.skippedCount = 0,
    this.failedCount = 0,
    this.importedRecipes = const [],
    this.skippedRecipes = const [],
    this.errors = const [],
    this.errorMessage,
  });

  factory ImportResult.failure(String errorMessage) {
    return ImportResult(success: false, errorMessage: errorMessage);
  }
}

/// Import mode for handling duplicates
enum ImportMode {
  /// Skip recipes that already exist (by title)
  skipDuplicates,

  /// Replace existing recipes with imported ones
  replaceDuplicates,

  /// Import all recipes, renaming duplicates
  renameDuplicates,
}

/// Service for importing recipes from JSON and Markdown files
class ImportService {
  final DatabaseService _databaseService;

  ImportService(this._databaseService);

  /// Pick and import recipes from a file
  Future<ImportResult> pickAndImportFile({
    ImportMode mode = ImportMode.skipDuplicates,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'md', 'txt', 'markdown'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult.failure('No file selected');
      }

      final file = result.files.first;
      if (file.path == null) {
        return ImportResult.failure('Unable to access file');
      }

      return await importFromFile(File(file.path!), mode: mode);
    } catch (e) {
      return ImportResult.failure('Failed to pick file: $e');
    }
  }

  /// Import recipes from a file
  Future<ImportResult> importFromFile(
    File file, {
    ImportMode mode = ImportMode.skipDuplicates,
  }) async {
    try {
      final content = await file.readAsString();
      final extension = file.path.split('.').last.toLowerCase();

      if (extension == 'json') {
        return await importFromJson(content, mode: mode);
      } else if (extension == 'md' ||
          extension == 'markdown' ||
          extension == 'txt') {
        return await importFromMarkdown(content, mode: mode);
      } else {
        return ImportResult.failure('Unsupported file format: $extension');
      }
    } catch (e) {
      return ImportResult.failure('Failed to read file: $e');
    }
  }

  /// Import recipes from JSON string
  Future<ImportResult> importFromJson(
    String jsonString, {
    ImportMode mode = ImportMode.skipDuplicates,
  }) async {
    try {
      final data = json.decode(jsonString);
      List<Recipe> recipes = [];

      if (data is Map<String, dynamic>) {
        // Check if it's our export format (with 'recipes' array)
        if (data.containsKey('recipes') && data['recipes'] is List) {
          for (final recipeJson in data['recipes']) {
            if (recipeJson is Map<String, dynamic>) {
              final recipe = _parseRecipeFromJson(recipeJson);
              if (recipe != null) {
                recipes.add(recipe);
              }
            }
          }
        } else {
          // Try parsing as a single recipe
          final recipe = _parseRecipeFromJson(data);
          if (recipe != null) {
            recipes.add(recipe);
          }
        }
      } else if (data is List) {
        // Array of recipes
        for (final recipeJson in data) {
          if (recipeJson is Map<String, dynamic>) {
            final recipe = _parseRecipeFromJson(recipeJson);
            if (recipe != null) {
              recipes.add(recipe);
            }
          }
        }
      }

      if (recipes.isEmpty) {
        return ImportResult.failure('No valid recipes found in JSON');
      }

      return await _importRecipes(recipes, mode);
    } catch (e) {
      return ImportResult.failure('Failed to parse JSON: $e');
    }
  }

  /// Import recipes from Markdown string (best-effort parsing)
  Future<ImportResult> importFromMarkdown(
    String markdown, {
    ImportMode mode = ImportMode.skipDuplicates,
  }) async {
    try {
      final recipes = _parseMarkdown(markdown);

      if (recipes.isEmpty) {
        return ImportResult.failure('No valid recipes found in Markdown');
      }

      return await _importRecipes(recipes, mode);
    } catch (e) {
      return ImportResult.failure('Failed to parse Markdown: $e');
    }
  }

  /// Parse a recipe from JSON map
  Recipe? _parseRecipeFromJson(Map<String, dynamic> json) {
    try {
      // Handle both camelCase and snake_case keys
      final title =
          json['title'] as String? ?? json['name'] as String? ?? 'Untitled';

      // Parse ingredients
      final ingredients = <Ingredient>[];
      final ingredientsList =
          json['ingredients'] as List<dynamic>? ?? <dynamic>[];
      for (var i = 0; i < ingredientsList.length; i++) {
        final item = ingredientsList[i];
        if (item is Map<String, dynamic>) {
          ingredients.add(Ingredient(
            quantity: _parseDouble(item['quantity']),
            unit: item['unit'] as String?,
            item:
                item['item'] as String? ?? item['name'] as String? ?? 'Unknown',
            notes: item['notes'] as String?,
            order: i,
          ));
        } else if (item is String) {
          ingredients.add(Ingredient(item: item, order: i));
        }
      }

      // Parse directions
      final directions = <Direction>[];
      final directionsList =
          json['directions'] as List<dynamic>? ??
          json['steps'] as List<dynamic>? ??
          json['instructions'] as List<dynamic>? ??
          <dynamic>[];
      for (var i = 0; i < directionsList.length; i++) {
        final item = directionsList[i];
        if (item is Map<String, dynamic>) {
          directions.add(Direction(
            stepNumber: item['stepNumber'] as int? ??
                item['step_number'] as int? ??
                i + 1,
            text: item['text'] as String? ??
                item['instruction'] as String? ??
                '',
          ));
        } else if (item is String) {
          directions.add(Direction(stepNumber: i + 1, text: item));
        }
      }

      return Recipe(
        title: title,
        sourceUrl: json['sourceUrl'] as String? ?? json['source_url'] as String?,
        sourcePlatform: json['sourcePlatform'] as String? ??
            json['source_platform'] as String?,
        ingredients: ingredients,
        directions: directions,
      );
    } catch (e) {
      return null;
    }
  }

  /// Parse markdown content into recipes
  List<Recipe> _parseMarkdown(String markdown) {
    final recipes = <Recipe>[];
    final lines = markdown.split('\n');

    String? currentTitle;
    List<Ingredient> currentIngredients = [];
    List<Direction> currentDirections = [];
    String? currentSection;
    int directionIndex = 0;

    void saveCurrentRecipe() {
      if (currentTitle != null &&
          (currentIngredients.isNotEmpty || currentDirections.isNotEmpty)) {
        recipes.add(Recipe(
          title: currentTitle!,
          ingredients: List.from(currentIngredients),
          directions: List.from(currentDirections),
        ));
      }
      currentTitle = null;
      currentIngredients = [];
      currentDirections = [];
      currentSection = null;
      directionIndex = 0;
    }

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      // Check for recipe title (# Title)
      if (line.startsWith('# ') && !line.startsWith('## ')) {
        saveCurrentRecipe();
        currentTitle = line.substring(2).trim();
        continue;
      }

      // Check for section headers (## Ingredients, ## Directions)
      if (line.startsWith('## ')) {
        final header = line.substring(3).trim().toLowerCase();
        if (header.contains('ingredient')) {
          currentSection = 'ingredients';
        } else if (header.contains('direction') ||
            header.contains('instruction') ||
            header.contains('step')) {
          currentSection = 'directions';
        } else {
          currentSection = null;
        }
        continue;
      }

      // Skip metadata lines
      if (line.startsWith('---') ||
          line.startsWith('**Source') ||
          line.startsWith('*Recipe extracted')) {
        continue;
      }

      // Parse content based on current section
      if (currentSection == 'ingredients') {
        final ingredient = _parseIngredientFromMarkdown(
          line,
          currentIngredients.length,
        );
        if (ingredient != null) {
          currentIngredients.add(ingredient);
        }
      } else if (currentSection == 'directions') {
        final direction = _parseDirectionFromMarkdown(line, directionIndex);
        if (direction != null) {
          currentDirections.add(direction);
          directionIndex++;
        }
      }
    }

    // Save the last recipe
    saveCurrentRecipe();

    return recipes;
  }

  /// Parse an ingredient line from markdown
  Ingredient? _parseIngredientFromMarkdown(String line, int index) {
    // Remove bullet points
    if (line.startsWith('- ')) line = line.substring(2);
    if (line.startsWith('* ')) line = line.substring(2);
    if (line.startsWith('• ')) line = line.substring(2);

    line = line.trim();
    if (line.isEmpty || line == '*No ingredients listed*') return null;

    // Try to parse quantity and unit
    final quantityMatch = RegExp(r'^([\d./\s]+)\s*').firstMatch(line);
    double? quantity;
    String remaining = line;

    if (quantityMatch != null) {
      final qStr = quantityMatch.group(1)!.trim();
      quantity = _parseFraction(qStr);
      if (quantity != null) {
        remaining = line.substring(quantityMatch.end).trim();
      }
    }

    // Try to extract unit
    String? unit;
    final unitMatch = RegExp(
      r'^(cup|cups|tablespoon|tablespoons|tbsp|teaspoon|teaspoons|tsp|'
      r'pound|pounds|lb|lbs|ounce|ounces|oz|gram|grams|g|kilogram|kg|'
      r'ml|milliliter|liter|l|pinch|dash|piece|pieces|slice|slices|'
      r'can|cans|package|packages|pkg|bunch|bunches|clove|cloves|'
      r'head|heads|stalk|stalks|sprig|sprigs|large|medium|small)\s+',
      caseSensitive: false,
    ).firstMatch(remaining);

    if (unitMatch != null) {
      unit = unitMatch.group(1);
      remaining = remaining.substring(unitMatch.end).trim();
    }

    // Check for notes in parentheses
    String? notes;
    final notesMatch = RegExp(r'\(([^)]+)\)\s*$').firstMatch(remaining);
    if (notesMatch != null) {
      notes = notesMatch.group(1);
      remaining = remaining.substring(0, notesMatch.start).trim();
    }

    return Ingredient(
      quantity: quantity,
      unit: unit,
      item: remaining.isEmpty ? line : remaining,
      notes: notes,
      order: index,
    );
  }

  /// Parse a direction line from markdown
  Direction? _parseDirectionFromMarkdown(String line, int index) {
    if (line.isEmpty || line == '*No directions listed*') return null;

    // Remove numbered list prefix
    final numberMatch = RegExp(r'^(\d+)[.)]\s*').firstMatch(line);
    String text = line;
    int stepNumber = index + 1;

    if (numberMatch != null) {
      stepNumber = int.tryParse(numberMatch.group(1)!) ?? (index + 1);
      text = line.substring(numberMatch.end).trim();
    }

    if (text.isEmpty) return null;

    return Direction(stepNumber: stepNumber, text: text);
  }

  /// Import a list of recipes with duplicate handling
  Future<ImportResult> _importRecipes(
    List<Recipe> recipes,
    ImportMode mode,
  ) async {
    final existingRecipes = await _databaseService.getAllRecipes();
    final existingTitles =
        existingRecipes.map((r) => r.title.toLowerCase()).toSet();

    final importedRecipes = <String>[];
    final skippedRecipes = <String>[];
    final errors = <String>[];

    for (final recipe in recipes) {
      try {
        final titleLower = recipe.title.toLowerCase();
        final isDuplicate = existingTitles.contains(titleLower);

        if (isDuplicate) {
          switch (mode) {
            case ImportMode.skipDuplicates:
              skippedRecipes.add(recipe.title);
              continue;

            case ImportMode.replaceDuplicates:
              final existing = existingRecipes.firstWhere(
                (r) => r.title.toLowerCase() == titleLower,
              );
              final updated = recipe.copyWith(id: existing.id);
              await _databaseService.updateRecipe(updated);
              importedRecipes.add(recipe.title);
              break;

            case ImportMode.renameDuplicates:
              var newTitle = recipe.title;
              var counter = 2;
              while (existingTitles.contains(newTitle.toLowerCase())) {
                newTitle = '${recipe.title} ($counter)';
                counter++;
              }
              final renamed = recipe.copyWith(title: newTitle);
              await _databaseService.insertRecipe(renamed);
              existingTitles.add(newTitle.toLowerCase());
              importedRecipes.add(newTitle);
              break;
          }
        } else {
          await _databaseService.insertRecipe(recipe);
          existingTitles.add(titleLower);
          importedRecipes.add(recipe.title);
        }
      } catch (e) {
        errors.add('Failed to import "${recipe.title}": $e');
      }
    }

    return ImportResult(
      success: errors.isEmpty || importedRecipes.isNotEmpty,
      importedCount: importedRecipes.length,
      skippedCount: skippedRecipes.length,
      failedCount: errors.length,
      importedRecipes: importedRecipes,
      skippedRecipes: skippedRecipes,
      errors: errors,
    );
  }

  /// Validate a recipe before import
  ValidationResult validateRecipe(Recipe recipe) {
    final errors = <String>[];
    final warnings = <String>[];

    if (recipe.title.isEmpty) {
      errors.add('Recipe title is required');
    }

    if (recipe.ingredients.isEmpty) {
      warnings.add('Recipe has no ingredients');
    }

    if (recipe.directions.isEmpty) {
      warnings.add('Recipe has no directions');
    }

    for (final ingredient in recipe.ingredients) {
      if (ingredient.item.isEmpty) {
        warnings.add('An ingredient has no name');
      }
    }

    for (final direction in recipe.directions) {
      if (direction.text.isEmpty) {
        warnings.add('A direction step has no text');
      }
    }

    if (errors.isNotEmpty) {
      return ValidationResult.invalid(errors);
    }
    return ValidationResult.valid(warnings: warnings);
  }

  /// Parse a double from string, handling nulls
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? _parseFraction(value);
    }
    return null;
  }

  /// Parse a fraction string (e.g., "1/2", "1 1/2")
  double? _parseFraction(String str) {
    str = str.trim();
    if (str.isEmpty) return null;

    // Handle mixed numbers (e.g., "1 1/2")
    final mixedMatch = RegExp(r'^(\d+)\s+(\d+)/(\d+)$').firstMatch(str);
    if (mixedMatch != null) {
      final whole = int.parse(mixedMatch.group(1)!);
      final num = int.parse(mixedMatch.group(2)!);
      final den = int.parse(mixedMatch.group(3)!);
      if (den != 0) {
        return whole + num / den;
      }
    }

    // Handle simple fractions (e.g., "1/2")
    final fractionMatch = RegExp(r'^(\d+)/(\d+)$').firstMatch(str);
    if (fractionMatch != null) {
      final num = int.parse(fractionMatch.group(1)!);
      final den = int.parse(fractionMatch.group(2)!);
      if (den != 0) {
        return num / den;
      }
    }

    // Handle unicode fractions
    const unicodeFractions = {
      '½': 0.5,
      '⅓': 1 / 3,
      '⅔': 2 / 3,
      '¼': 0.25,
      '¾': 0.75,
      '⅕': 0.2,
      '⅖': 0.4,
      '⅗': 0.6,
      '⅘': 0.8,
      '⅙': 1 / 6,
      '⅚': 5 / 6,
      '⅛': 0.125,
      '⅜': 0.375,
      '⅝': 0.625,
      '⅞': 0.875,
    };

    for (final entry in unicodeFractions.entries) {
      if (str.contains(entry.key)) {
        final parts = str.split(entry.key);
        final whole = double.tryParse(parts[0].trim()) ?? 0;
        return whole + entry.value;
      }
    }

    // Try regular number parsing
    return double.tryParse(str);
  }
}
