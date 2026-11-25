import 'parsing_utils.dart';

/// Classifier for identifying ingredient lines vs direction lines
class IngredientClassifier {
  // Common ingredient keywords
  static const Set<String> ingredientKeywords = {
    // Grains & starches
    'flour',
    'rice',
    'pasta',
    'bread',
    'noodles',
    'lentils',
    // Sweeteners & baking
    'sugar',
    'honey',
    'chocolate',
    'cocoa',
    'vanilla',
    'yeast',
    'baking powder',
    'baking soda',
    // Dairy & fats
    'butter',
    'oil',
    'cream',
    'cheese',
    'milk',
    'coconut oil',
    'sesame oil',
    // Eggs
    'egg',
    'eggs',
    // Seasonings & spices
    'salt',
    'pepper',
    'garlic',
    'onion',
    'parsley',
    'basil',
    'oregano',
    'thyme',
    'rosemary',
    'cinnamon',
    'nutmeg',
    'ginger',
    'cumin',
    'paprika',
    'chili',
    'nutritional yeast',
    // Proteins
    'chicken',
    'beef',
    'pork',
    'fish',
    'salmon',
    'shrimp',
    'tofu',
    'tempeh',
    // Vegetables
    'tomato',
    'carrot',
    'potato',
    'celery',
    'mushroom',
    'spinach',
    'kale',
    'lettuce',
    'cabbage',
    'zucchini',
    'eggplant',
    'broccoli',
    'cauliflower',
    'asparagus',
    'cucumber',
    'corn',
    'peas',
    'beans',
    'edamame',
    'green beans',
    // Peppers
    'bell pepper',
    'jalapeno',
    // Fruits
    'lemon',
    'lime',
    'avocado',
    'strawberry',
    'blueberry',
    'raspberry',
    'apple',
    'banana',
    'orange',
    'pineapple',
    'mango',
    'peach',
    'pear',
    // Nuts & seeds
    'almond',
    'walnut',
    'pecan',
    'cashew',
    'peanut',
    'seeds',
    // Liquids & sauces
    'water',
    'soy sauce',
    'vinegar',
    'stock',
    'broth',
    'wine',
  };

  /// Check if a line is likely an ingredient
  /// Returns a confidence score between 0 and 1
  static double classifyAsIngredient(String line) {
    final cleaned = ParsingUtils.cleanText(line);
    if (cleaned.isEmpty || cleaned.length < 2) return 0.0;

    double score = 0.0;

    // Check length - ingredients are typically short (< 100 chars)
    if (cleaned.length < 100) {
      score += 0.2;
    } else if (cleaned.length < 50) {
      score += 0.3;
    }

    // Check for quantity/number at the start
    if (RegExp(r'^\d+').hasMatch(cleaned) ||
        RegExp(r'^(one|two|three|four|five|six|seven|eight|nine|ten)',
                caseSensitive: false)
            .hasMatch(cleaned)) {
      score += 0.3;
    }

    // Check for fractions
    if (RegExp(r'[¼½¾⅓⅔⅛⅜⅝⅞]').hasMatch(cleaned) ||
        RegExp(r'\d+\s*/\s*\d+').hasMatch(cleaned)) {
      score += 0.2;
    }

    // Check for cooking units
    final words = cleaned.toLowerCase().split(RegExp(r'\s+'));
    for (final word in words) {
      if (ParsingUtils.isValidCookingUnit(word)) {
        score += 0.3;
        break;
      }
    }

    // Check for ingredient keywords
    final lowerLine = cleaned.toLowerCase();
    int keywordMatches = 0;
    for (final keyword in ingredientKeywords) {
      if (lowerLine.contains(keyword)) {
        keywordMatches++;
        score += 0.1;
        if (keywordMatches >= 3) break; // Cap at 3 keywords
      }
    }

    // Penalty for direction-like patterns
    if (_hasDirectionPatterns(cleaned)) {
      score -= 0.3;
    }

    // Penalty for very long text (likely a direction)
    if (cleaned.length > 150) {
      score -= 0.2;
    }

    // Ensure score is between 0 and 1
    return score.clamp(0.0, 1.0);
  }

  /// Check if line has patterns that suggest it's a direction, not an ingredient
  static bool _hasDirectionPatterns(String line) {
    final lower = line.toLowerCase();

    // Check for numbered steps (e.g., "1.", "Step 1", "Step one")
    if (RegExp(r'^\d+\.|\bstep\s+\d+|\bstep\s+(one|two|three)',
            caseSensitive: false)
        .hasMatch(lower)) {
      return true;
    }

    // Check for imperative verbs at start
    final directionStarters = [
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
      'slice',
      'chop',
      'dice',
      'mince',
      'cut',
      'serve',
    ];

    for (final verb in directionStarters) {
      if (lower.startsWith('$verb ') || lower.startsWith('$verb,')) {
        return true;
      }
    }

    // Check for time references (common in directions)
    if (ParsingUtils.findTimeDuration(line) != null) {
      return true;
    }

    // Check for temperature references (common in directions)
    if (ParsingUtils.findTemperature(line) != null) {
      return true;
    }

    return false;
  }

  /// Parse an ingredient line into components
  /// Returns a map with keys: quantity, unit, item, notes
  static Map<String, dynamic> parseIngredient(String line) {
    final cleaned = ParsingUtils.cleanText(line);

    double? quantity;
    String? unit;
    String item = cleaned;
    String? notes;

    // Extract notes in parentheses
    final notesMatch = RegExp(r'\(([^)]+)\)').firstMatch(cleaned);
    if (notesMatch != null) {
      notes = notesMatch.group(1);
      item = cleaned.replaceAll(notesMatch.group(0)!, '').trim();
    }

    // Try to parse quantity and unit at the beginning
    // Pattern: [quantity] [unit] [item]
    // Examples: "2 cups flour", "1/2 teaspoon salt", "3 large eggs"
    final quantityPattern = RegExp(
      r'^([\d\s\/¼½¾⅓⅔⅛⅜⅝⅞.]+)\s*([a-zA-Z]+)?\s+(.+)$',
    );
    final match = quantityPattern.firstMatch(item);

    if (match != null) {
      final quantityStr = match.group(1)?.trim();
      final unitStr = match.group(2)?.trim();
      final itemStr = match.group(3)?.trim();

      if (quantityStr != null) {
        quantity = ParsingUtils.parseQuantity(quantityStr);
      }

      if (unitStr != null && ParsingUtils.isValidCookingUnit(unitStr)) {
        unit = ParsingUtils.normalizeUnit(unitStr);
        item = itemStr ?? item;
      } else {
        // Unit might be part of item (e.g., "large eggs")
        item = '${unitStr ?? ''} ${itemStr ?? ''}'.trim();
      }
    }

    // Clean up item text
    item = item.trim();
    if (item.isEmpty) {
      item = cleaned; // Fallback to original
    }

    return {
      'quantity': quantity,
      'unit': unit,
      'item': item,
      'notes': notes,
    };
  }
}
