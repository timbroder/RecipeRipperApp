import 'parsing_utils.dart';

/// Classifier for identifying direction/instruction lines
class DirectionClassifier {
  // Common cooking action verbs
  static const Set<String> cookingVerbs = {
    'add',
    'mix',
    'stir',
    'combine',
    'whisk',
    'beat',
    'fold',
    'pour',
    'cook',
    'bake',
    'broil',
    'grill',
    'roast',
    'fry',
    'saute',
    'sauté',
    'simmer',
    'boil',
    'heat',
    'preheat',
    'prepare',
    'place',
    'put',
    'spread',
    'sprinkle',
    'season',
    'set',
    'let',
    'allow',
    'remove',
    'transfer',
    'drain',
    'strain',
    'slice',
    'chop',
    'dice',
    'mince',
    'cut',
    'peel',
    'grate',
    'shred',
    'crush',
    'grind',
    'blend',
    'process',
    'knead',
    'roll',
    'shape',
    'form',
    'wrap',
    'cover',
    'refrigerate',
    'freeze',
    'thaw',
    'melt',
    'dissolve',
    'reduce',
    'increase',
    'adjust',
    'taste',
    'check',
    'test',
    'insert',
    'turn',
    'flip',
    'rotate',
    'brush',
    'coat',
    'dip',
    'toss',
    'shake',
    'squeeze',
    'press',
    'flatten',
    'crimp',
    'score',
    'brown',
    'sear',
    'char',
    'caramelize',
    'glaze',
    'marinate',
    'baste',
    'stuff',
    'fill',
    'layer',
    'arrange',
    'garnish',
    'serve',
    'enjoy',
  };

  // Direction starter phrases
  static const Set<String> directionStarters = {
    'step',
    'first',
    'second',
    'third',
    'next',
    'then',
    'finally',
    'meanwhile',
    'while',
    'after',
    'before',
    'once',
    'when',
    'until',
    'if',
    'to',
    'in order to',
    'make sure',
    'be careful',
    'optional',
  };

  /// Check if a line is likely a direction/instruction
  /// Returns a confidence score between 0 and 1
  static double classifyAsDirection(String line) {
    final cleaned = ParsingUtils.cleanText(line);
    if (cleaned.isEmpty || cleaned.length < 3) return 0.0;

    double score = 0.0;

    // Check length - directions are typically longer (> 30 chars)
    if (cleaned.length > 30) {
      score += 0.2;
    }
    if (cleaned.length > 60) {
      score += 0.1;
    }

    // Check for numbered steps
    if (RegExp(r'^\d+\.?\s').hasMatch(cleaned) ||
        RegExp(r'^step\s+\d+', caseSensitive: false).hasMatch(cleaned)) {
      score += 0.4;
    }

    // Check for cooking verbs at the start
    final lower = cleaned.toLowerCase();
    bool hasVerbAtStart = false;
    for (final verb in cookingVerbs) {
      if (lower.startsWith('$verb ') ||
          lower.startsWith('$verb,') ||
          lower.startsWith('$verb.')) {
        hasVerbAtStart = true;
        score += 0.3;
        break;
      }
    }

    // Check for cooking verbs anywhere in the text
    if (!hasVerbAtStart) {
      int verbCount = 0;
      for (final verb in cookingVerbs) {
        if (lower.contains(' $verb ') ||
            lower.contains(' $verb,') ||
            lower.contains(' $verb.') ||
            lower.startsWith('$verb ')) {
          verbCount++;
          score += 0.1;
          if (verbCount >= 3) break; // Cap at 3 verbs
        }
      }
    }

    // Check for direction starter phrases
    for (final starter in directionStarters) {
      if (lower.startsWith('$starter ') || lower.startsWith('$starter,')) {
        score += 0.2;
        break;
      }
    }

    // Check for temperature references
    if (ParsingUtils.findTemperature(cleaned) != null) {
      score += 0.2;
    }

    // Check for time duration references
    if (ParsingUtils.findTimeDuration(cleaned) != null) {
      score += 0.2;
    }

    // Check for conjunctions and complex sentence structure (typical of directions)
    if (RegExp(r'\b(and|or|then|until|while|when|if|before|after)\b',
            caseSensitive: false)
        .hasMatch(cleaned)) {
      score += 0.1;
    }

    // Penalty for ingredient-like patterns
    if (_hasIngredientPatterns(cleaned)) {
      score -= 0.3;
    }

    // Penalty for very short text (likely an ingredient)
    if (cleaned.length < 20) {
      score -= 0.2;
    }

    // Ensure score is between 0 and 1
    return score.clamp(0.0, 1.0);
  }

  /// Check if line has patterns that suggest it's an ingredient, not a direction
  static bool _hasIngredientPatterns(String line) {
    final lower = line.toLowerCase();

    // Check for quantity at the start (very common for ingredients)
    if (RegExp(r'^[\d¼½¾⅓⅔⅛⅜⅝⅞]+\s').hasMatch(line)) {
      // If it has quantity but also has cooking verbs, it might still be a direction
      // Example: "3 minutes until golden brown" vs "3 cups flour"
      bool hasVerb = false;
      for (final verb in cookingVerbs) {
        if (lower.contains(' $verb ') || lower.contains(' $verb,')) {
          hasVerb = true;
          break;
        }
      }
      if (!hasVerb) {
        return true;
      }
    }

    // Very short lines with cooking units are likely ingredients
    if (line.length < 30) {
      final words = lower.split(RegExp(r'\s+'));
      for (final word in words) {
        if (ParsingUtils.isValidCookingUnit(word)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Clean and normalize a direction text
  /// Removes step numbers, extra whitespace, etc.
  static String cleanDirection(String text) {
    String cleaned = ParsingUtils.cleanText(text);

    // Remove step numbers at the start (e.g., "1.", "Step 1:")
    cleaned = cleaned.replaceFirst(RegExp(r'^\d+\.?\s*'), '');
    cleaned = cleaned.replaceFirst(
      RegExp(r'^step\s+\d+:?\s*', caseSensitive: false),
      '',
    );

    // Capitalize first letter if not already
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }

    return cleaned.trim();
  }

  /// Assign step numbers to a list of directions
  /// Returns a list of maps with 'stepNumber' and 'text' keys
  static List<Map<String, dynamic>> assignStepNumbers(List<String> directions) {
    final result = <Map<String, dynamic>>[];

    for (int i = 0; i < directions.length; i++) {
      result.add({
        'stepNumber': i + 1,
        'text': cleanDirection(directions[i]),
      });
    }

    return result;
  }
}
