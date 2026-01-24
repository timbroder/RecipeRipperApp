import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_ripper/models/confidence_score.dart';

void main() {
  group('ConfidenceLevel', () {
    test('fromScore returns veryHigh for scores >= 0.85', () {
      expect(ConfidenceLevel.fromScore(0.85), ConfidenceLevel.veryHigh);
      expect(ConfidenceLevel.fromScore(0.90), ConfidenceLevel.veryHigh);
      expect(ConfidenceLevel.fromScore(1.0), ConfidenceLevel.veryHigh);
    });

    test('fromScore returns high for scores >= 0.65 and < 0.85', () {
      expect(ConfidenceLevel.fromScore(0.65), ConfidenceLevel.high);
      expect(ConfidenceLevel.fromScore(0.75), ConfidenceLevel.high);
      expect(ConfidenceLevel.fromScore(0.84), ConfidenceLevel.high);
    });

    test('fromScore returns medium for scores >= 0.40 and < 0.65', () {
      expect(ConfidenceLevel.fromScore(0.40), ConfidenceLevel.medium);
      expect(ConfidenceLevel.fromScore(0.50), ConfidenceLevel.medium);
      expect(ConfidenceLevel.fromScore(0.64), ConfidenceLevel.medium);
    });

    test('fromScore returns low for scores < 0.40', () {
      expect(ConfidenceLevel.fromScore(0.0), ConfidenceLevel.low);
      expect(ConfidenceLevel.fromScore(0.20), ConfidenceLevel.low);
      expect(ConfidenceLevel.fromScore(0.39), ConfidenceLevel.low);
    });

    test('labels are human-readable', () {
      expect(ConfidenceLevel.veryHigh.label, 'Very High');
      expect(ConfidenceLevel.high.label, 'High');
      expect(ConfidenceLevel.medium.label, 'Medium');
      expect(ConfidenceLevel.low.label, 'Low');
    });
  });

  group('ConfidenceScore', () {
    test('constructor sets level based on overall score', () {
      final score = ConfidenceScore(
        overall: 0.90,
        ingredientScore: 0.85,
        directionScore: 0.95,
        dataQualityScore: 0.80,
        explanation: 'Great extraction!',
      );

      expect(score.level, ConfidenceLevel.veryHigh);
      expect(score.overall, 0.90);
    });

    test('low factory creates a low confidence score', () {
      final score = ConfidenceScore.low();

      expect(score.level, ConfidenceLevel.low);
      expect(score.overall, 0.0);
      expect(score.ingredientScore, 0.0);
      expect(score.directionScore, 0.0);
      expect(score.dataQualityScore, 0.0);
    });

    test('toJson creates correct map', () {
      final score = ConfidenceScore(
        overall: 0.75,
        ingredientScore: 0.80,
        directionScore: 0.70,
        dataQualityScore: 0.65,
        explanation: 'Good extraction',
      );

      final json = score.toJson();

      expect(json['overall'], 0.75);
      expect(json['level'], 'high');
      expect(json['ingredientScore'], 0.80);
      expect(json['directionScore'], 0.70);
      expect(json['dataQualityScore'], 0.65);
      expect(json['explanation'], 'Good extraction');
    });

    test('fromJson creates correct ConfidenceScore', () {
      final json = {
        'overall': 0.55,
        'level': 'medium',
        'ingredientScore': 0.60,
        'directionScore': 0.50,
        'dataQualityScore': 0.45,
        'explanation': 'Moderate extraction',
      };

      final score = ConfidenceScore.fromJson(json);

      expect(score.overall, 0.55);
      expect(score.level, ConfidenceLevel.medium);
      expect(score.ingredientScore, 0.60);
      expect(score.directionScore, 0.50);
      expect(score.dataQualityScore, 0.45);
      expect(score.explanation, 'Moderate extraction');
    });

    test('fromJson handles missing values gracefully', () {
      final json = <String, dynamic>{};

      final score = ConfidenceScore.fromJson(json);

      expect(score.overall, 0.0);
      expect(score.level, ConfidenceLevel.low);
    });

    test('toString includes percentage and level', () {
      final score = ConfidenceScore(
        overall: 0.85,
        ingredientScore: 0.80,
        directionScore: 0.90,
        dataQualityScore: 0.75,
        explanation: 'Test',
      );

      final str = score.toString();

      expect(str, contains('85%'));
      expect(str, contains('Very High'));
    });
  });
}
