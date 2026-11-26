import '../models/ingredient.dart';

/// Result of [DescriptionGrounding.check].
class GroundingResult {
  /// Ingredients with at least one meaningful word in their name.
  final int total;

  /// Of [total], how many have a name word that appears in the description.
  final int grounded;

  /// Of [grounded], how many also have a quantity.
  final int quantified;

  /// Items whose names don't appear in the description.
  final List<String> ungrounded;

  /// Null when grounded; otherwise why the recipe was rejected.
  final String? rejectionReason;

  const GroundingResult({
    required this.total,
    required this.grounded,
    required this.quantified,
    required this.ungrounded,
    required this.rejectionReason,
  });

  bool get isGrounded => rejectionReason == null;

  Map<String, Object?> toJson() => {
        'total': total,
        'grounded': grounded,
        'quantified': quantified,
        'ungrounded': ungrounded,
        'isGrounded': isGrounded,
        'rejectionReason': rejectionReason,
      };
}

/// Checks that a recipe extracted from a video description is actually
/// written in that description, rather than invented from the dish name.
///
/// The description fast path skips the transcript and OCR entirely, so a
/// recipe the model made up (e.g. from "Chicken Bacon Fried Rice" and a
/// macros block) would otherwise become the final recipe. Requiring most
/// ingredient names to appear in the description, and at least a couple to
/// come with quantities, keeps the fast path for descriptions that really
/// list a recipe. Anything else falls through to the full pipeline, which
/// still reads the description first.
class DescriptionGrounding {
  /// Minimum share of ingredients whose name appears in the description.
  static const minGroundedShare = 0.8;

  /// Minimum number of grounded ingredients that have a quantity.
  static const minQuantified = 2;

  /// Words that don't identify an ingredient on their own.
  static const _ignoredWords = {
    'and', 'or', 'of', 'the', 'for', 'with', 'to', 'taste', 'optional', //
    'some', 'fresh', 'large', 'small', 'medium', 'chopped', 'diced',
    'minced', 'sliced', 'cooked', 'raw', 'ground', 'whole', 'light', 'dark',
    'hot', 'cold', 'warm', 'extra', 'virgin', 'boneless', 'skinless',
    'green', 'red', 'white', 'black', 'yellow', 'cup', 'tbsp', 'tsp',
    'tablespoon', 'teaspoon', 'gram', 'pound', 'ounce', 'slice', 'piece',
    'clove', 'can', 'packet', 'pinch', 'dash', 'juice',
  };

  static GroundingResult check(
    List<Ingredient> ingredients,
    String description,
  ) {
    final descriptionWords = _words(description);

    var total = 0;
    var grounded = 0;
    var quantified = 0;
    final ungrounded = <String>[];

    for (final ingredient in ingredients) {
      final nameWords = _words(ingredient.item);
      if (nameWords.isEmpty) continue;
      total++;
      if (nameWords.any(descriptionWords.contains)) {
        grounded++;
        if (ingredient.quantity != null) quantified++;
      } else {
        ungrounded.add(ingredient.item);
      }
    }

    String? reason;
    if (total == 0) {
      reason = 'no ingredients';
    } else if (grounded / total < minGroundedShare) {
      reason = 'only $grounded of $total ingredients appear in the description';
    } else if (quantified < minQuantified) {
      reason = 'only $quantified ingredients from the description have '
          'quantities (need $minQuantified)';
    }

    return GroundingResult(
      total: total,
      grounded: grounded,
      quantified: quantified,
      ungrounded: ungrounded,
      rejectionReason: reason,
    );
  }

  /// Meaningful, singularized words in [text].
  static Set<String> _words(String text) => RegExp(r'[a-z]+')
      .allMatches(text.toLowerCase())
      .map((m) => _singular(m.group(0)!))
      .where((w) => w.length >= 3 && !_ignoredWords.contains(w))
      .toSet();

  static String _singular(String word) {
    if (word.endsWith('ies') && word.length > 4) {
      return '${word.substring(0, word.length - 3)}y';
    }
    if (word.endsWith('oes') && word.length > 4) {
      return word.substring(0, word.length - 2);
    }
    if (word.endsWith('s') && !word.endsWith('ss') && word.length > 3) {
      return word.substring(0, word.length - 1);
    }
    return word;
  }
}
