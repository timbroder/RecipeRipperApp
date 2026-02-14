import '../models/recipe.dart';
import '../models/confidence_score.dart';
import '../utils/parsing_utils.dart';

/// Service for calculating recipe extraction confidence scores
class ConfidenceCalculatorService {
  // Weights for different confidence factors
  static const double _ingredientWeight = 0.35;
  static const double _directionWeight = 0.35;
  static const double _dataQualityWeight = 0.30;

  // Thresholds for ingredient scoring
  static const int _minIngredientsForGood = 3;
  static const int _minIngredientsForExcellent = 6;

  // Thresholds for direction scoring
  static const int _minDirectionsForGood = 2;
  static const int _minDirectionsForExcellent = 4;

  // Thresholds for data quality
  static const int _minTranscriptLength = 100;
  static const int _goodTranscriptLength = 500;
  static const int _minOcrLength = 50;
  static const int _goodOcrLength = 200;

  /// Calculate confidence score for a recipe
  static ConfidenceScore calculate(Recipe recipe) {
    final ingredientScore = _calculateIngredientScore(recipe);
    final directionScore = _calculateDirectionScore(recipe);
    final dataQualityScore = _calculateDataQualityScore(recipe);

    // Calculate weighted overall score
    final overall = (ingredientScore * _ingredientWeight) +
        (directionScore * _directionWeight) +
        (dataQualityScore * _dataQualityWeight);

    // Generate explanation
    final explanation = _generateExplanation(
      recipe,
      ingredientScore,
      directionScore,
      dataQualityScore,
    );

    return ConfidenceScore(
      overall: overall,
      ingredientScore: ingredientScore,
      directionScore: directionScore,
      dataQualityScore: dataQualityScore,
      explanation: explanation,
    );
  }

  /// Calculate ingredient score (0.0 to 1.0)
  static double _calculateIngredientScore(Recipe recipe) {
    final ingredients = recipe.ingredients;
    if (ingredients.isEmpty) return 0.0;

    double score = 0.0;

    // Base score for having ingredients
    final count = ingredients.length;
    if (count >= _minIngredientsForExcellent) {
      score += 0.5;
    } else if (count >= _minIngredientsForGood) {
      score += 0.3;
    } else {
      score += 0.15;
    }

    // Bonus for ingredients with quantities
    int withQuantity = 0;
    int withUnit = 0;
    for (final ingredient in ingredients) {
      if (ingredient.quantity != null) withQuantity++;
      if (ingredient.unit != null) withUnit++;
    }

    final quantityRatio = withQuantity / count;
    final unitRatio = withUnit / count;

    // Quality bonus (up to 0.5)
    score += quantityRatio * 0.3;
    score += unitRatio * 0.2;

    return score.clamp(0.0, 1.0);
  }

  /// Calculate direction score (0.0 to 1.0)
  static double _calculateDirectionScore(Recipe recipe) {
    final directions = recipe.directions;
    if (directions.isEmpty) return 0.0;

    double score = 0.0;

    // Base score for having directions
    final count = directions.length;
    if (count >= _minDirectionsForExcellent) {
      score += 0.5;
    } else if (count >= _minDirectionsForGood) {
      score += 0.3;
    } else {
      score += 0.15;
    }

    // Quality indicators
    int withTimeRef = 0;
    int withTempRef = 0;
    int withGoodLength = 0;

    for (final direction in directions) {
      if (ParsingUtils.findTimeDuration(direction.text) != null) {
        withTimeRef++;
      }
      if (ParsingUtils.findTemperature(direction.text) != null) {
        withTempRef++;
      }
      // Good length is between 20 and 500 characters
      if (direction.text.length >= 20 && direction.text.length <= 500) {
        withGoodLength++;
      }
    }

    // Quality bonus (up to 0.5)
    final timeRatio = withTimeRef / count;
    final tempRatio = withTempRef / count;
    final lengthRatio = withGoodLength / count;

    score += timeRatio * 0.15;
    score += tempRatio * 0.15;
    score += lengthRatio * 0.20;

    return score.clamp(0.0, 1.0);
  }

  /// Calculate data quality score based on source data (0.0 to 1.0)
  static double _calculateDataQualityScore(Recipe recipe) {
    final metadata = recipe.metadata;
    if (metadata == null) return 0.3; // Base score without metadata

    double score = 0.0;

    // Transcript quality
    final transcript = metadata.transcript ?? '';
    final transcriptLength = transcript.length;
    if (transcriptLength >= _goodTranscriptLength) {
      score += 0.35;
    } else if (transcriptLength >= _minTranscriptLength) {
      score += 0.2;
    } else if (transcriptLength > 0) {
      score += 0.1;
    }

    // OCR text quality
    final ocrText = metadata.ocrText ?? '';
    final ocrLength = ocrText.length;
    if (ocrLength >= _goodOcrLength) {
      score += 0.25;
    } else if (ocrLength >= _minOcrLength) {
      score += 0.12;
    } else if (ocrLength > 0) {
      score += 0.05;
    }

    // Frame count bonus
    final frameCount = metadata.frameCount ?? 0;
    if (frameCount >= 50) {
      score += 0.1;
    } else if (frameCount >= 20) {
      score += 0.07;
    } else if (frameCount > 0) {
      score += 0.03;
    }

    // Title quality
    if (recipe.title.isNotEmpty && recipe.title != 'Untitled Recipe') {
      score += 0.1;
    }

    // Description quality bonus
    final description = metadata.description ?? '';
    if (description.length >= 200) {
      score += 0.1;
    } else if (description.isNotEmpty) {
      score += 0.05;
    }

    // Processing method bonus (LLM results get a small boost)
    final method = metadata.processingMethod;
    if (method == 'llm_full' || method == 'description_only') {
      score += 0.1;
    }

    return score.clamp(0.0, 1.0);
  }

  /// Generate a human-readable explanation
  static String _generateExplanation(
    Recipe recipe,
    double ingredientScore,
    double directionScore,
    double dataQualityScore,
  ) {
    final issues = <String>[];
    final strengths = <String>[];

    // Analyze ingredients
    final ingredientCount = recipe.ingredients.length;
    if (ingredientCount == 0) {
      issues.add('No ingredients found');
    } else if (ingredientCount < _minIngredientsForGood) {
      issues.add(
          'Only $ingredientCount ingredient${ingredientCount == 1 ? '' : 's'} found');
    } else {
      strengths.add('$ingredientCount ingredients extracted');
    }

    // Check ingredient quality
    if (ingredientCount > 0) {
      int withQuantity = 0;
      for (final ing in recipe.ingredients) {
        if (ing.quantity != null) withQuantity++;
      }
      final quantityPercent = ((withQuantity / ingredientCount) * 100).round();
      if (quantityPercent >= 70) {
        strengths.add('$quantityPercent% have quantities');
      } else if (quantityPercent < 30) {
        issues.add('Few ingredients have quantities');
      }
    }

    // Analyze directions
    final directionCount = recipe.directions.length;
    if (directionCount == 0) {
      issues.add('No directions found');
    } else if (directionCount < _minDirectionsForGood) {
      issues.add(
          'Only $directionCount step${directionCount == 1 ? '' : 's'} found');
    } else {
      strengths.add('$directionCount steps extracted');
    }

    // Analyze data quality
    final metadata = recipe.metadata;
    if (metadata != null) {
      final transcriptLen = metadata.transcript?.length ?? 0;
      final ocrLen = metadata.ocrText?.length ?? 0;

      if (transcriptLen < _minTranscriptLength && ocrLen < _minOcrLength) {
        issues.add('Limited text extracted from video');
      }
    }

    // Build explanation
    if (issues.isEmpty && strengths.isNotEmpty) {
      return 'Complete recipe extracted: ${strengths.join(', ')}.';
    } else if (strengths.isEmpty && issues.isNotEmpty) {
      return 'Limited extraction: ${issues.join(', ')}.';
    } else if (strengths.isNotEmpty && issues.isNotEmpty) {
      return '${strengths.join(', ')}. Note: ${issues.join(', ')}.';
    }

    return 'Recipe extraction completed.';
  }
}
