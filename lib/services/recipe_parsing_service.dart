import '../models/recipe.dart';
import '../models/ingredient.dart';
import '../models/direction.dart';
import '../utils/text_splitter.dart';
import '../utils/ingredient_classifier.dart';
import '../utils/direction_classifier.dart';
import '../utils/deduplicator.dart';
import '../utils/parsing_utils.dart';

/// Service for parsing raw transcript and OCR text into structured recipes
class RecipeParsingService {
  /// Parse raw text into a structured Recipe object
  /// Combines transcript and OCR text, extracts ingredients and directions
  static Future<Recipe> parseRecipe({
    required String? transcript,
    required String? ocrText,
    String? videoTitle,
    String? sourceUrl,
    String? sourcePlatform,
    String? thumbnailPath,
    RecipeMetadata? metadata,
  }) async {
    // Combine transcript and OCR text
    final combinedText = _combineTexts(transcript, ocrText);

    // Extract title
    final title = TextSplitter.extractTitle(
          combinedText,
          videoTitle: videoTitle,
        ) ??
        'Untitled Recipe';

    // Split text into ingredient and direction sections
    final sections = TextSplitter.splitIntoSections(combinedText);
    final ingredientLines = sections['ingredients'] ?? [];
    final directionLines = sections['directions'] ?? [];

    // Parse ingredients
    final ingredients = _parseIngredients(ingredientLines);

    // Parse directions
    final directions = _parseDirections(directionLines);

    // Create recipe with metadata
    final recipeMetadata = metadata ??
        RecipeMetadata(
          transcript: transcript,
          ocrText: ocrText,
        );

    return Recipe(
      title: title,
      sourceUrl: sourceUrl,
      sourcePlatform: sourcePlatform,
      thumbnailPath: thumbnailPath,
      ingredients: ingredients,
      directions: directions,
      metadata: recipeMetadata,
    );
  }

  /// Combine transcript and OCR text, removing duplicates
  static String _combineTexts(String? transcript, String? ocrText) {
    final parts = <String>[];

    if (transcript != null && transcript.isNotEmpty) {
      parts.add(transcript);
    }

    if (ocrText != null && ocrText.isNotEmpty) {
      parts.add(ocrText);
    }

    if (parts.isEmpty) {
      return '';
    }

    // Combine and deduplicate lines
    final allLines = parts.join('\n').split('\n');
    final deduplicated = Deduplicator.deduplicateTextLines(allLines);

    return deduplicated.join('\n');
  }

  /// Parse ingredient lines into Ingredient objects
  static List<Ingredient> _parseIngredients(List<String> lines) {
    if (lines.isEmpty) return [];

    final ingredients = <Ingredient>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final parsed = IngredientClassifier.parseIngredient(line);

      ingredients.add(
        Ingredient(
          quantity: parsed['quantity'] as double?,
          unit: parsed['unit'] as String?,
          item: parsed['item'] as String,
          notes: parsed['notes'] as String?,
          order: i,
        ),
      );
    }

    // Deduplicate ingredients
    return Deduplicator.deduplicateIngredients(ingredients);
  }

  /// Parse direction lines into Direction objects
  static List<Direction> _parseDirections(List<String> lines) {
    if (lines.isEmpty) return [];

    final directions = <Direction>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final cleaned = DirectionClassifier.cleanDirection(line);

      if (cleaned.isNotEmpty) {
        directions.add(
          Direction(
            stepNumber: i + 1,
            text: cleaned,
          ),
        );
      }
    }

    // Deduplicate directions
    return Deduplicator.deduplicateDirections(directions);
  }

  /// Validate a parsed recipe
  /// Returns a list of validation warnings (empty if valid)
  static List<String> validateRecipe(Recipe recipe) {
    final warnings = <String>[];

    // Check for empty title
    if (recipe.title.isEmpty || recipe.title == 'Untitled Recipe') {
      warnings.add('Recipe has no title');
    }

    // Check for missing ingredients
    if (recipe.ingredients.isEmpty) {
      warnings.add('Recipe has no ingredients');
    }

    // Check for missing directions
    if (recipe.directions.isEmpty) {
      warnings.add('Recipe has no directions');
    }

    // Check for very short directions (likely parsing errors)
    for (final direction in recipe.directions) {
      if (direction.text.length < 5) {
        warnings.add('Direction ${direction.stepNumber} is very short');
      }
    }

    // Check for ingredients without items
    for (final ingredient in recipe.ingredients) {
      if (ingredient.item.isEmpty) {
        warnings.add('Ingredient at position ${ingredient.order} has no item');
      }
    }

    return warnings;
  }

  /// Get parsing statistics for a recipe
  /// Useful for debugging and quality assessment
  static Map<String, dynamic> getParsingStats(Recipe recipe) {
    int ingredientsWithQuantity = 0;
    int ingredientsWithUnit = 0;
    int directionsWithTimeRef = 0;
    int directionsWithTempRef = 0;

    for (final ingredient in recipe.ingredients) {
      if (ingredient.quantity != null) ingredientsWithQuantity++;
      if (ingredient.unit != null) ingredientsWithUnit++;
    }

    for (final direction in recipe.directions) {
      if (ParsingUtils.findTimeDuration(direction.text) != null) {
        directionsWithTimeRef++;
      }
      if (ParsingUtils.findTemperature(direction.text) != null) {
        directionsWithTempRef++;
      }
    }

    return {
      'totalIngredients': recipe.ingredients.length,
      'ingredientsWithQuantity': ingredientsWithQuantity,
      'ingredientsWithUnit': ingredientsWithUnit,
      'totalDirections': recipe.directions.length,
      'directionsWithTimeRef': directionsWithTimeRef,
      'directionsWithTempRef': directionsWithTempRef,
      'hasTitle': recipe.title.isNotEmpty && recipe.title != 'Untitled Recipe',
      'hasMetadata': recipe.metadata != null,
    };
  }
}
