import '../models/ingredient.dart';
import '../models/direction.dart';
import 'ingredient_classifier.dart';

/// Result of cross-reference checking between ingredients and directions.
class CrossReferenceResult {
  final List<String> unusedIngredients;
  final List<String> missingIngredients;
  final List<String> warnings;
  final List<Ingredient> autoAddedIngredients;

  CrossReferenceResult({
    required this.unusedIngredients,
    required this.missingIngredients,
    required this.warnings,
    required this.autoAddedIngredients,
  });
}

/// Checks cross-references between ingredients and directions to find
/// unused ingredients and missing ingredients mentioned in directions.
class CrossReferenceChecker {
  // Multi-word food items that should be matched as a unit
  static const _multiWordItems = {
    'olive oil',
    'vegetable oil',
    'canola oil',
    'sesame oil',
    'coconut oil',
    'soy sauce',
    'fish sauce',
    'hot sauce',
    'tomato paste',
    'tomato sauce',
    'cream cheese',
    'sour cream',
    'heavy cream',
    'whipping cream',
    'ice cream',
    'baking powder',
    'baking soda',
    'brown sugar',
    'powdered sugar',
    'confectioners sugar',
    'maple syrup',
    'corn starch',
    'cornstarch',
    'bell pepper',
    'black pepper',
    'white pepper',
    'cayenne pepper',
    'chili powder',
    'garlic powder',
    'onion powder',
    'vanilla extract',
    'almond extract',
    'lemon juice',
    'lime juice',
    'orange juice',
    'apple cider',
    'red wine',
    'white wine',
    'rice vinegar',
    'balsamic vinegar',
    'green onion',
    'spring onion',
    'peanut butter',
    'almond butter',
    'coconut milk',
    'all purpose flour',
    'bread flour',
    'whole wheat flour',
  };

  /// Normalize a word to its singular form for matching.
  static String _singularize(String word) {
    final lower = word.toLowerCase();

    // Irregular plurals
    const irregulars = {
      'leaves': 'leaf',
      'halves': 'half',
      'knives': 'knife',
      'loaves': 'loaf',
      'potatoes': 'potato',
      'tomatoes': 'tomato',
    };
    if (irregulars.containsKey(lower)) return irregulars[lower]!;

    // -ies → -y (berries → berry)
    if (lower.endsWith('ies') && lower.length > 4) {
      return '${lower.substring(0, lower.length - 3)}y';
    }

    // -es → (dishes → dish, sauces → sauce)
    if (lower.endsWith('es') && lower.length > 3) {
      final stem = lower.substring(0, lower.length - 2);
      if (lower.endsWith('shes') ||
          lower.endsWith('ches') ||
          lower.endsWith('xes') ||
          lower.endsWith('sses') ||
          lower.endsWith('zzes')) {
        return stem;
      }
      // sauces → sauce, juices → juice
      if (lower.endsWith('ces') || lower.endsWith('ges')) {
        return lower.substring(0, lower.length - 1);
      }
    }

    // -s → (carrots → carrot)
    if (lower.endsWith('s') && !lower.endsWith('ss') && lower.length > 2) {
      return lower.substring(0, lower.length - 1);
    }

    return lower;
  }

  /// Extract food words from a text string.
  static Set<String> _extractFoodWords(String text) {
    final lower = text.toLowerCase();
    final foodWords = <String>{};

    // Check multi-word items first
    for (final item in _multiWordItems) {
      if (lower.contains(item)) {
        foodWords.add(item);
      }
    }

    // Check single-word ingredient keywords
    final words = lower.split(RegExp(r'[\s,;.!?()\[\]]+'));
    for (final word in words) {
      if (word.isEmpty) continue;
      final singular = _singularize(word);
      if (IngredientClassifier.ingredientKeywords.contains(word) ||
          IngredientClassifier.ingredientKeywords.contains(singular)) {
        foodWords.add(singular);
      }
    }

    return foodWords;
  }

  /// Extract the food word from an ingredient's item name.
  static Set<String> _ingredientFoodWords(Ingredient ingredient) {
    final words = <String>{};
    final lower = ingredient.item.toLowerCase();

    // Check multi-word matches first
    for (final item in _multiWordItems) {
      if (lower.contains(item)) {
        words.add(item);
      }
    }

    // Check each word
    final parts = lower.split(RegExp(r'[\s,;.!?()\[\]]+'));
    for (final part in parts) {
      if (part.isEmpty) continue;
      final singular = _singularize(part);
      if (IngredientClassifier.ingredientKeywords.contains(part) ||
          IngredientClassifier.ingredientKeywords.contains(singular)) {
        words.add(singular);
      }
    }

    // If no recognized food words, use the whole item name (singularized)
    if (words.isEmpty && ingredient.item.isNotEmpty) {
      words.add(_singularize(ingredient.item.toLowerCase().trim()));
    }

    return words;
  }

  /// Check cross-references between ingredients and directions.
  static CrossReferenceResult check({
    required List<Ingredient> ingredients,
    required List<Direction> directions,
  }) {
    if (ingredients.isEmpty || directions.isEmpty) {
      return CrossReferenceResult(
        unusedIngredients: [],
        missingIngredients: [],
        warnings: [],
        autoAddedIngredients: [],
      );
    }

    final warnings = <String>[];
    final unusedIngredients = <String>[];
    final missingIngredients = <String>[];
    final autoAddedIngredients = <Ingredient>[];

    // Combine all direction text
    final directionsText = directions.map((d) => d.text).join(' ');
    final directionFoodWords = _extractFoodWords(directionsText);

    // Build a set of all ingredient food words
    final allIngredientFoodWords = <String>{};
    final ingredientWordMap = <String, Set<String>>{};

    for (final ingredient in ingredients) {
      final words = _ingredientFoodWords(ingredient);
      ingredientWordMap[ingredient.item] = words;
      allIngredientFoodWords.addAll(words);
    }

    // Find unused ingredients (in ingredient list but not in directions)
    for (final ingredient in ingredients) {
      final words = ingredientWordMap[ingredient.item] ?? {};
      final isUsed = words.any((w) => directionFoodWords.contains(w)) ||
          _textMentionsItem(directionsText, ingredient.item);
      if (!isUsed) {
        unusedIngredients.add(ingredient.item);
        warnings.add('Unused ingredient: ${ingredient.item}');
      }
    }

    // Find missing ingredients (mentioned in directions but not in ingredients)
    for (final word in directionFoodWords) {
      // Skip if any ingredient already covers this word
      if (allIngredientFoodWords.contains(word)) continue;

      // Skip multi-word items if their component words are covered
      if (word.contains(' ')) {
        final parts = word.split(' ');
        if (parts
            .every((p) => allIngredientFoodWords.contains(_singularize(p)))) {
          continue;
        }
      }

      missingIngredients.add(word);
      warnings.add('Missing ingredient: $word');

      // Auto-add as ingredient without quantity/unit
      autoAddedIngredients.add(
        Ingredient(
          item: word,
          order: ingredients.length + autoAddedIngredients.length,
        ),
      );
    }

    return CrossReferenceResult(
      unusedIngredients: unusedIngredients,
      missingIngredients: missingIngredients,
      warnings: warnings,
      autoAddedIngredients: autoAddedIngredients,
    );
  }

  /// Check if directions text mentions an ingredient item directly.
  static bool _textMentionsItem(String text, String item) {
    final lower = text.toLowerCase();
    final itemLower = item.toLowerCase().trim();

    // Direct mention
    if (lower.contains(itemLower)) return true;

    // Singular form
    final singular = _singularize(itemLower);
    if (lower.contains(singular)) return true;

    return false;
  }
}
