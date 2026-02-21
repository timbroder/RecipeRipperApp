import '../models/recipe.dart';
import '../models/ingredient.dart';
import '../models/direction.dart';
import '../utils/noise_filter.dart';
import '../utils/spoken_to_imperative.dart';
import '../utils/cross_reference_checker.dart';
import '../utils/parsing_utils.dart';
import '../utils/ingredient_classifier.dart';
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
  /// Approximate max characters for the combined input text.
  /// Foundation Models has ~4,096 tokens. Reserve ~800 for
  /// instructions + output, leaving ~3,200 tokens for input.
  /// At ~4 chars per token, that's ~12,800 characters.
  static const _maxInputChars = 12800;

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

    // Truncate if needed (descriptions are usually short, but just in case)
    final truncated = _truncateText(filtered, _maxInputChars);

    // Call LLM
    final result = await llmService.extractRecipeFromDescription(
      truncated,
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
    // Build combined text with priority: description > transcript > OCR
    final combinedText = _buildTruncatedInput(
      transcript: transcript,
      ocrText: ocrText,
      description: description,
    );

    if (combinedText == null) return null;

    // Call LLM
    var result = await llmService.extractRecipe(
      combinedText,
      videoTitle: videoTitle,
    );

    // If context overflow, retry with more aggressive truncation
    if (!result.success && result.error == 'context_overflow') {
      final shorter = _buildTruncatedInput(
        transcript: transcript,
        ocrText: ocrText,
        description: description,
        maxChars: _maxInputChars ~/ 2,
      );
      if (shorter != null) {
        result = await llmService.extractRecipe(
          shorter,
          videoTitle: videoTitle,
        );
      }
    }

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

  /// Build combined input text, truncated to fit the token budget.
  /// Priority: description first, then transcript, then OCR (noisiest).
  static String? _buildTruncatedInput({
    required String? transcript,
    required String? ocrText,
    required String? description,
    int maxChars = _maxInputChars,
  }) {
    final sections = <String>[];
    var remaining = maxChars;

    // Priority 1: Description (most structured, least noisy)
    if (description != null && description.isNotEmpty) {
      final filtered = NoiseFilter.filterText(description);
      if (filtered.isNotEmpty) {
        final section = _truncateText(filtered, remaining ~/ 2);
        sections.add('DESCRIPTION:\n$section');
        remaining -= section.length + 14; // 14 for "DESCRIPTION:\n"
      }
    }

    // Priority 2: Transcript (spoken recipe content)
    // Note: Do NOT apply NoiseFilter to transcript. The noise filter is designed
    // for line-by-line OCR text and will drop the entire transcript (which is
    // one continuous paragraph) if any engagement word like "like" appears.
    if (transcript != null && transcript.isNotEmpty && remaining > 200) {
      final section = _truncateText(transcript, remaining * 2 ~/ 3);
      sections.add('TRANSCRIPT:\n$section');
      remaining -= section.length + 13; // 13 for "TRANSCRIPT:\n"
    }

    // Priority 3: OCR (noisiest, lowest priority)
    if (ocrText != null && ocrText.isNotEmpty && remaining > 200) {
      final filtered = NoiseFilter.filterText(ocrText);
      if (filtered.isNotEmpty) {
        final section = _truncateText(filtered, remaining);
        sections.add('ON-SCREEN TEXT:\n$section');
      }
    }

    if (sections.isEmpty) return null;
    return sections.join('\n\n');
  }

  /// Truncate text to maxChars, breaking at a word boundary.
  static String _truncateText(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    // Find last space before the limit
    final truncated = text.substring(0, maxChars);
    final lastSpace = truncated.lastIndexOf(' ');
    if (lastSpace > maxChars * 0.8) {
      return '${truncated.substring(0, lastSpace)}...';
    }
    return '$truncated...';
  }

  /// Build a Recipe from an LLM extraction result.
  /// Handles both flat-string and structured ingredient formats.
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

    // Parse ingredients — handle both flat strings and structured
    var ingredients = <Ingredient>[];
    for (int i = 0; i < result.ingredients.length; i++) {
      final llmIngredient = result.ingredients[i];

      // Flat string ingredient: parse with IngredientClassifier
      if (_isFlatStringIngredient(llmIngredient)) {
        final parsed = IngredientClassifier.parseIngredient(llmIngredient.item);
        ingredients.add(Ingredient(
          quantity: parsed['quantity'] as double?,
          unit: parsed['unit'] as String?,
          item: parsed['item'] as String? ?? llmIngredient.item,
          notes: parsed['notes'] as String?,
          order: i,
        ));
      } else {
        // Structured ingredient from LLM
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

    // Cross-reference check (include title for food word extraction)
    final crossRef = CrossReferenceChecker.check(
      ingredients: ingredients,
      directions: directions,
      title: title,
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

  /// Check if an LlmIngredient is a flat string (no quantity/unit/notes parsed).
  static bool _isFlatStringIngredient(LlmIngredient ingredient) {
    return ingredient.quantity == null &&
        ingredient.unit == null &&
        ingredient.notes == null;
  }
}
