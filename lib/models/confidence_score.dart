/// Confidence levels for recipe extraction quality
enum ConfidenceLevel {
  veryHigh('Very High', 0.85),
  high('High', 0.65),
  medium('Medium', 0.40),
  low('Low', 0.0);

  final String label;
  final double minScore;

  const ConfidenceLevel(this.label, this.minScore);

  /// Get the confidence level from a score (0.0 to 1.0)
  static ConfidenceLevel fromScore(double score) {
    if (score >= ConfidenceLevel.veryHigh.minScore) {
      return ConfidenceLevel.veryHigh;
    } else if (score >= ConfidenceLevel.high.minScore) {
      return ConfidenceLevel.high;
    } else if (score >= ConfidenceLevel.medium.minScore) {
      return ConfidenceLevel.medium;
    }
    return ConfidenceLevel.low;
  }
}

/// Detailed confidence score for a recipe extraction
class ConfidenceScore {
  /// Overall confidence score (0.0 to 1.0)
  final double overall;

  /// Confidence level based on overall score
  final ConfidenceLevel level;

  /// Individual factor scores (0.0 to 1.0 each)
  final double ingredientScore;
  final double directionScore;
  final double dataQualityScore;

  /// Human-readable explanation of the confidence
  final String explanation;

  ConfidenceScore({
    required this.overall,
    required this.ingredientScore,
    required this.directionScore,
    required this.dataQualityScore,
    required this.explanation,
  }) : level = ConfidenceLevel.fromScore(overall);

  /// Create a default low confidence score
  factory ConfidenceScore.low() {
    return ConfidenceScore(
      overall: 0.0,
      ingredientScore: 0.0,
      directionScore: 0.0,
      dataQualityScore: 0.0,
      explanation: 'Unable to extract recipe data from video.',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'overall': overall,
      'level': level.name,
      'ingredientScore': ingredientScore,
      'directionScore': directionScore,
      'dataQualityScore': dataQualityScore,
      'explanation': explanation,
    };
  }

  factory ConfidenceScore.fromJson(Map<String, dynamic> json) {
    final overall = (json['overall'] as num?)?.toDouble() ?? 0.0;
    return ConfidenceScore(
      overall: overall,
      ingredientScore: (json['ingredientScore'] as num?)?.toDouble() ?? 0.0,
      directionScore: (json['directionScore'] as num?)?.toDouble() ?? 0.0,
      dataQualityScore: (json['dataQualityScore'] as num?)?.toDouble() ?? 0.0,
      explanation: json['explanation'] as String? ?? '',
    );
  }

  @override
  String toString() {
    return 'ConfidenceScore(overall: ${(overall * 100).toStringAsFixed(0)}%, level: ${level.label})';
  }
}
