import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

import '../models/recipe.dart';
import '../models/ingredient.dart';
import '../models/direction.dart';
import '../utils/ingredient_classifier.dart';
import '../utils/direction_classifier.dart';
import '../utils/text_splitter.dart';

/// Result of extracting a recipe from a web page.
class WebRecipeResult {
  final Recipe recipe;
  final String extractionMethod; // 'json-ld' or 'heuristic'

  WebRecipeResult({required this.recipe, required this.extractionMethod});
}

/// Extracts structured recipes from HTML pages.
///
/// Two strategies:
/// 1. JSON-LD schema.org/Recipe (covers ~90% of recipe sites)
/// 2. Heuristic HTML scrape (fallback for pages without structured data)
class WebRecipeExtractor {
  /// Attempts to extract a recipe from HTML content.
  ///
  /// Tries JSON-LD first, then falls back to heuristic extraction.
  /// Returns null if no recipe could be found.
  static WebRecipeResult? extractFromHtml(String html, {String? sourceUrl}) {
    return _extractFromJsonLd(html, sourceUrl: sourceUrl) ??
        _extractFromHeuristic(html, sourceUrl: sourceUrl);
  }

  // ---------------------------------------------------------------------------
  // Strategy 1: JSON-LD schema.org/Recipe
  // ---------------------------------------------------------------------------

  static WebRecipeResult? _extractFromJsonLd(String html, {String? sourceUrl}) {
    final document = html_parser.parse(html);
    final scripts =
        document.querySelectorAll('script[type="application/ld+json"]');

    for (final script in scripts) {
      final text = script.text.trim();
      if (text.isEmpty) continue;

      try {
        final decoded = jsonDecode(text);
        final recipe = _findRecipeInJsonLd(decoded);
        if (recipe != null) {
          final result = _parseJsonLdRecipe(recipe, sourceUrl: sourceUrl);
          if (result != null) return result;
        }
      } catch (_) {
        // Malformed JSON, try next script tag
      }
    }

    return null;
  }

  /// Recursively search for a Recipe @type in JSON-LD data.
  /// Handles top-level objects, @graph arrays, and nested structures.
  static Map<String, dynamic>? _findRecipeInJsonLd(dynamic data) {
    if (data is Map<String, dynamic>) {
      final type = data['@type'];
      if (_isRecipeType(type)) return data;

      // Check @graph array
      if (data.containsKey('@graph')) {
        final graph = data['@graph'];
        if (graph is List) {
          for (final item in graph) {
            final found = _findRecipeInJsonLd(item);
            if (found != null) return found;
          }
        }
      }
    } else if (data is List) {
      for (final item in data) {
        final found = _findRecipeInJsonLd(item);
        if (found != null) return found;
      }
    }

    return null;
  }

  static bool _isRecipeType(dynamic type) {
    if (type is String) {
      return type == 'Recipe' || type == 'schema:Recipe';
    }
    if (type is List) {
      return type.any((t) => t == 'Recipe' || t == 'schema:Recipe');
    }
    return false;
  }

  static WebRecipeResult? _parseJsonLdRecipe(Map<String, dynamic> data,
      {String? sourceUrl}) {
    final name = data['name'] as String?;
    if (name == null || name.isEmpty) return null;

    final ingredients = _parseJsonLdIngredients(data);
    final directions = _parseJsonLdDirections(data);

    // Must have at least some content
    if (ingredients.isEmpty && directions.isEmpty) return null;

    String? platform;
    if (sourceUrl != null) {
      try {
        platform = Uri.parse(sourceUrl).host.replaceFirst('www.', '');
      } catch (_) {}
    }

    final recipe = Recipe(
      title: name,
      sourceUrl: sourceUrl,
      sourcePlatform: platform,
      ingredients: ingredients,
      directions: directions,
      metadata: RecipeMetadata(
        processingMethod: 'json-ld',
        description: data['description'] as String?,
      ),
    );

    return WebRecipeResult(recipe: recipe, extractionMethod: 'json-ld');
  }

  static List<Ingredient> _parseJsonLdIngredients(Map<String, dynamic> data) {
    final raw = data['recipeIngredient'];
    if (raw == null) return [];

    List<String> lines;
    if (raw is List) {
      lines = raw.map((e) => e.toString()).toList();
    } else if (raw is String) {
      lines = raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
    } else {
      return [];
    }

    final ingredients = <Ingredient>[];
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parsed = IngredientClassifier.parseIngredient(line);
      ingredients.add(Ingredient(
        quantity: parsed['quantity'] as double?,
        unit: parsed['unit'] as String?,
        item: parsed['item'] as String,
        notes: parsed['notes'] as String?,
        order: i,
      ));
    }

    return ingredients;
  }

  static List<Direction> _parseJsonLdDirections(Map<String, dynamic> data) {
    final raw = data['recipeInstructions'];
    if (raw == null) return [];

    final steps = <String>[];

    if (raw is String) {
      // Single string with all instructions
      steps.addAll(
        raw
            .split(RegExp(r'\.\s+'))
            .where((s) => s.trim().isNotEmpty)
            .map((s) => s.trim().endsWith('.') ? s.trim() : '${s.trim()}.'),
      );
    } else if (raw is List) {
      for (final item in raw) {
        if (item is String) {
          steps.add(item.trim());
        } else if (item is Map<String, dynamic>) {
          final type = item['@type']?.toString() ?? '';

          if (type == 'HowToStep') {
            final text = item['text'] as String?;
            if (text != null && text.trim().isNotEmpty) {
              steps.add(text.trim());
            }
          } else if (type == 'HowToSection') {
            // HowToSection contains itemListElement with HowToStep items
            final sectionItems = item['itemListElement'];
            if (sectionItems is List) {
              for (final sectionItem in sectionItems) {
                if (sectionItem is Map<String, dynamic>) {
                  final text = sectionItem['text'] as String?;
                  if (text != null && text.trim().isNotEmpty) {
                    steps.add(text.trim());
                  }
                }
              }
            }
          }
        }
      }
    }

    final directions = <Direction>[];
    for (int i = 0; i < steps.length; i++) {
      final cleaned = DirectionClassifier.cleanDirection(steps[i]);
      if (cleaned.isNotEmpty) {
        directions.add(Direction(
          stepNumber: i + 1,
          text: cleaned,
        ));
      }
    }

    return directions;
  }

  // ---------------------------------------------------------------------------
  // Strategy 2: Heuristic HTML scrape
  // ---------------------------------------------------------------------------

  static WebRecipeResult? _extractFromHeuristic(String html,
      {String? sourceUrl}) {
    final document = html_parser.parse(html);

    // Remove non-content elements
    for (final selector in [
      'script',
      'style',
      'nav',
      'footer',
      'header',
      'aside',
      'noscript',
    ]) {
      document.querySelectorAll(selector).forEach((e) => e.remove());
    }

    // Get text content
    final text = _extractTextContent(document);
    if (text.isEmpty) return null;

    // Use existing parsing pipeline
    final sections = TextSplitter.splitIntoSections(text);
    final ingredientLines = sections['ingredients'] ?? [];
    final directionLines = sections['directions'] ?? [];

    // Quality gate: must have at least 2 ingredients AND 2 directions
    if (ingredientLines.length < 2 && directionLines.length < 2) {
      return null;
    }

    // Parse ingredients
    final ingredients = <Ingredient>[];
    for (int i = 0; i < ingredientLines.length; i++) {
      final parsed = IngredientClassifier.parseIngredient(ingredientLines[i]);
      ingredients.add(Ingredient(
        quantity: parsed['quantity'] as double?,
        unit: parsed['unit'] as String?,
        item: parsed['item'] as String,
        notes: parsed['notes'] as String?,
        order: i,
      ));
    }

    // Parse directions
    final directions = <Direction>[];
    for (int i = 0; i < directionLines.length; i++) {
      final cleaned = DirectionClassifier.cleanDirection(directionLines[i]);
      if (cleaned.isNotEmpty) {
        directions.add(Direction(
          stepNumber: i + 1,
          text: cleaned,
        ));
      }
    }

    // Extract title from page
    final title = _extractPageTitle(document) ?? 'Web Recipe';

    String? platform;
    if (sourceUrl != null) {
      try {
        platform = Uri.parse(sourceUrl).host.replaceFirst('www.', '');
      } catch (_) {}
    }

    final recipe = Recipe(
      title: title,
      sourceUrl: sourceUrl,
      sourcePlatform: platform,
      ingredients: ingredients,
      directions: directions,
      metadata: RecipeMetadata(processingMethod: 'heuristic'),
    );

    return WebRecipeResult(recipe: recipe, extractionMethod: 'heuristic');
  }

  /// Extracts visible text content from the document body.
  static String _extractTextContent(Document document) {
    final body = document.body;
    if (body == null) return '';
    return body.text.trim();
  }

  /// Extracts the page title from meta tags or <title>.
  static String? _extractPageTitle(Document document) {
    // Try og:title first
    final ogTitle = document.querySelector('meta[property="og:title"]');
    if (ogTitle != null) {
      final content = ogTitle.attributes['content'];
      if (content != null && content.isNotEmpty) return content;
    }

    // Fall back to <title>
    final titleElement = document.querySelector('title');
    if (titleElement != null && titleElement.text.isNotEmpty) {
      return titleElement.text.trim();
    }

    return null;
  }
}
