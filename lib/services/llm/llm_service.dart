/// Result from an LLM recipe extraction call.
class LlmIngredient {
  final String? quantity;
  final String? unit;
  final String item;
  final String? notes;

  LlmIngredient({
    this.quantity,
    this.unit,
    required this.item,
    this.notes,
  });
}

/// Result of an LLM extraction attempt.
class LlmExtractionResult {
  final String? title;
  final List<LlmIngredient> ingredients;
  final List<String> directions;
  final bool success;
  final String? error;

  LlmExtractionResult({
    this.title,
    this.ingredients = const [],
    this.directions = const [],
    this.success = false,
    this.error,
  });

  /// Whether the result meets minimum quality thresholds.
  /// Requires at least 2 ingredients and 1 direction.
  bool get meetsMinimumQuality =>
      ingredients.length >= 2 && directions.isNotEmpty;

  factory LlmExtractionResult.failed(String error) {
    return LlmExtractionResult(success: false, error: error);
  }
}

/// Abstract interface for LLM-based recipe extraction.
abstract class LlmService {
  /// Check if this LLM service is available on the current device.
  Future<bool> isAvailable();

  /// Extract a recipe from combined transcript + OCR + description text.
  Future<LlmExtractionResult> extractRecipe(
    String text, {
    String? videoTitle,
  });

  /// Extract a recipe from just the video description (fast path).
  Future<LlmExtractionResult> extractRecipeFromDescription(
    String description, {
    String? videoTitle,
  });

  /// Human-readable name of this LLM service.
  String get name;
}
