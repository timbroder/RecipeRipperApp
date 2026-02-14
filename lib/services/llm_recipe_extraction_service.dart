import '../models/recipe.dart';
import '../models/ingredient.dart';
import '../models/direction.dart';
import '../utils/noise_filter.dart';
import '../utils/spoken_to_imperative.dart';
import '../utils/cross_reference_checker.dart';
import '../utils/parsing_utils.dart';
import 'llm/llm_service.dart';

/// Orchestrates LLM-based recipe extraction with the fallback chain.
///
/// Two main methods:
/// - [tryDescriptionOnly] — fast path using just the video description
/// - [tryFullLlm] — full pipeline using transcript + OCR + description
///
/// Both apply noise filtering, spoken-to-imperative conversion,
/// and cross-reference checking.
class LlmRecipeExtractionService {
  /// Try extracting a recipe from just the video description (fast path).
  /// Returns null if the result doesn't meet minimum quality thresholds.
  static Future<Recipe?> tryDescriptionOnly({
    required String description,
    required LlmService llmService,
    String? videoTitle,
    String? sourceUrl,
    String? sourcePlatform,
    String? thumbnailPath,
  }) async {
    // Filter noise from description
    final filtered = NoiseFilter.filterText(description);
    if (filtered.trim().isEmpty) return null;

    // Call LLM
    final result = await llmService.extractRecipeFromDescription(
      filtered,
      videoTitle: videoTitle,
    );

    if (!result.success || !result.meetsMinimumQuality) return null;

    return _buildRecipe(
      result: result,
      videoTitle: videoTitle,
      sourceUrl: sourceUrl,
      sourcePlatform: sourcePlatform,
      thumbnailPath: thumbnailPath,
      processingMethod: 'description_only',
      description: description,
    );
  }

  /// Try extracting a recipe using full LLM pipeline.
  /// Returns null if LLM fails or produces invalid output.
  static Future<Recipe?> tryFullLlm({
    required String? transcript,
    required String? ocrText,
    required String? description,
    required LlmService llmService,
    String? videoTitle,
    String? sourceUrl,
    String? sourcePlatform,
    String? thumbnailPath,
    RecipeMetadata? existingMetadata,
  }) async {
    // Combine and filter all text sources
    final parts = <String>[];
    if (transcript != null && transcript.isNotEmpty) {
      parts.add('TRANSCRIPT:\n${NoiseFilter.filterText(transcript)}');
    }
    if (ocrText != null && ocrText.isNotEmpty) {
      parts.add('ON-SCREEN TEXT:\n${NoiseFilter.filterText(ocrText)}');
    }
    if (description != null && description.isNotEmpty) {
      parts.add('VIDEO DESCRIPTION:\n${NoiseFilter.filterText(description)}');
    }

    if (parts.isEmpty) return null;

    final combinedText = parts.join('\n\n');

    // Call LLM
    final result = await llmService.extractRecipe(
      combinedText,
      videoTitle: videoTitle,
    );

    if (!result.success) return null;

    return _buildRecipe(
      result: result,
      videoTitle: videoTitle,
      sourceUrl: sourceUrl,
      sourcePlatform: sourcePlatform,
      thumbnailPath: thumbnailPath,
      processingMethod: 'llm_full',
      description: description,
      existingMetadata: existingMetadata,
    );
  }

  /// Build a Recipe from an LLM extraction result.
  /// Applies spoken-to-imperative conversion and cross-reference checking.
  static Recipe _buildRecipe({
    required LlmExtractionResult result,
    String? videoTitle,
    String? sourceUrl,
    String? sourcePlatform,
    String? thumbnailPath,
    required String processingMethod,
    String? description,
    RecipeMetadata? existingMetadata,
  }) {
    // Parse title
    final title = result.title ?? videoTitle ?? 'Untitled Recipe';

    // Parse ingredients
    var ingredients = <Ingredient>[];
    for (int i = 0; i < result.ingredients.length; i++) {
      final llmIngredient = result.ingredients[i];
      double? quantity;
      if (llmIngredient.quantity != null) {
        quantity = ParsingUtils.parseQuantity(llmIngredient.quantity!);
      }
      String? unit = llmIngredient.unit;
      if (unit != null) {
        unit = ParsingUtils.normalizeUnit(unit);
      }

      ingredients.add(Ingredient(
        quantity: quantity,
        unit: unit,
        item: llmIngredient.item,
        notes: llmIngredient.notes,
        order: i,
      ));
    }

    // Parse and convert directions to imperative form
    final rawDirections =
        result.directions.where((d) => d.trim().isNotEmpty).toList();
    final imperativeDirections = SpokenToImperative.convertAll(rawDirections);

    var directions = <Direction>[];
    for (int i = 0; i < imperativeDirections.length; i++) {
      directions.add(Direction(
        stepNumber: i + 1,
        text: imperativeDirections[i],
      ));
    }

    // Cross-reference check
    final crossRef = CrossReferenceChecker.check(
      ingredients: ingredients,
      directions: directions,
    );

    // Merge auto-added ingredients
    if (crossRef.autoAddedIngredients.isNotEmpty) {
      ingredients = [...ingredients, ...crossRef.autoAddedIngredients];
    }

    // Build metadata
    final metadata = (existingMetadata ?? RecipeMetadata()).copyWith(
      description: description,
      warnings: crossRef.warnings.isNotEmpty ? crossRef.warnings : null,
      processingMethod: processingMethod,
    );

    return Recipe(
      title: title,
      sourceUrl: sourceUrl,
      sourcePlatform: sourcePlatform,
      thumbnailPath: thumbnailPath,
      ingredients: ingredients,
      directions: directions,
      metadata: metadata,
    );
  }
}
