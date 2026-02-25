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

  /// Parse from JSON, handling both flat-string and structured ingredients.
  ///
  /// Flat format: `{"ingredients": ["1 cup flour", "2 eggs"]}`
  /// Structured format: `{"ingredients": [{"quantity":"1","unit":"cup","item":"flour"}]}`
  factory LlmExtractionResult.fromJson(Map<String, dynamic> json) {
    try {
      final title = json['title'] as String?;
      final ingredientsList = json['ingredients'] as List<dynamic>? ?? [];
      final directionsList = json['directions'] as List<dynamic>? ?? [];

      final ingredients = ingredientsList.map((item) {
        if (item is String) {
          // Flat string format — store as raw item for later parsing
          return LlmIngredient(item: item);
        }
        final map = item as Map<String, dynamic>;
        return LlmIngredient(
          quantity: map['quantity']?.toString(),
          unit: map['unit'] as String?,
          item: map['item'] as String? ?? '',
          notes: map['notes'] as String?,
        );
      }).toList();

      final directions = directionsList.map((d) => d.toString()).toList();

      return LlmExtractionResult(
        title: title,
        ingredients: ingredients,
        directions: directions,
        success: true,
      );
    } catch (e) {
      return LlmExtractionResult.failed('Error parsing result: $e');
    }
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
