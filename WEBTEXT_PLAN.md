# Web Recipe Extraction - Feature Plan

This document outlines the plan for extracting recipes from web pages (non-video URLs).

## Overview

When a user adds a URL that's not from a supported video platform (YouTube, Instagram, TikTok), the app will attempt to extract recipe content directly from the webpage HTML.

## User Flow

```
User adds URL → URL type detection → WebView preview with confidence indicator
                                            ↓
                              [Recipe found?]
                              No → Show "No recipe found" message, dismiss only
                              Yes → User taps "Extract Recipe"
                                            ↓
                              Recipe saved → Detail screen (same flow as video)
```

## Key Decisions

| Decision | Choice |
|----------|--------|
| Entry behavior | Preview webpage first, user confirms extraction |
| Extraction method | Layered: structured data first, heuristic fallback |
| Preview display | WebView with confidence indicator |
| No recipe found | Block extraction, show message |
| Post-extraction flow | Same as video recipes |
| Data storage | URL + page title + cached HTML |
| Login/paywall pages | Fail gracefully with message |

## Technical Design

### 1. URL Type Detection

Update `VideoService` or create `UrlClassifierService`:

```dart
enum UrlType {
  youtubeVideo,
  instagramVideo,
  tiktokVideo,
  webPage,        // New
  unsupported,
}

UrlType classifyUrl(String url) {
  // Check against known video platforms
  // Default to webPage for http/https URLs
  // Return unsupported for other schemes
}
```

### 2. Web Fetching Service

New `lib/services/web_fetch_service.dart`:

```dart
class WebFetchService {
  /// Fetches webpage HTML and metadata
  Future<WebPageData> fetchPage(String url);

  /// Checks if page is accessible (not paywalled/login-required)
  Future<bool> isAccessible(String url);
}

class WebPageData {
  final String url;
  final String html;
  final String? title;
  final String? canonicalUrl;
  final DateTime fetchedAt;
}
```

### 3. Recipe Extraction Service

New `lib/services/web_recipe_extraction_service.dart`:

```dart
class WebRecipeExtractionService {
  /// Main extraction entry point
  Future<WebExtractionResult> extract(String html, String url);

  /// Try JSON-LD/Schema.org first
  Future<Recipe?> extractStructuredData(String html);

  /// Fall back to heuristic parsing
  Future<Recipe?> extractHeuristic(String html);
}

class WebExtractionResult {
  final Recipe? recipe;
  final ExtractionMethod method;
  final ExtractionConfidence confidence;
  final int ingredientCount;
  final int directionCount;
  final String? errorMessage;
}

enum ExtractionMethod {
  structuredData,  // JSON-LD, microdata
  heuristic,       // Text analysis
  none,            // No recipe found
}

enum ExtractionConfidence {
  high,    // Structured data found
  medium,  // Heuristic with good signals
  low,     // Heuristic with weak signals
  none,    // No recipe detected
}
```

### 4. Schema.org Parser

New `lib/utils/schema_parser.dart`:

Handles:
- JSON-LD `<script type="application/ld+json">`
- Recipe schema type detection
- Ingredient array parsing
- Instruction/HowToStep parsing
- Image, author, prepTime, cookTime extraction

```dart
class SchemaParser {
  /// Extract Recipe schema from HTML
  Recipe? parseRecipeSchema(String html);

  /// Find all JSON-LD blocks
  List<Map<String, dynamic>> findJsonLdBlocks(String html);

  /// Parse @type: Recipe
  Recipe? parseRecipeObject(Map<String, dynamic> json);
}
```

### 5. HTML Text Extractor

New `lib/utils/html_text_extractor.dart`:

For heuristic fallback:
- Strip HTML tags
- Preserve list structure (ul/ol → line breaks)
- Extract text from recipe-related elements
- Remove nav, footer, ads, comments

```dart
class HtmlTextExtractor {
  /// Extract clean text from HTML
  String extractText(String html);

  /// Extract text from likely recipe sections
  String extractRecipeSections(String html);

  /// Remove boilerplate (nav, footer, ads)
  String removeBoilerplate(String html);
}
```

### 6. WebView Preview Screen

New `lib/screens/web_preview_screen.dart`:

```dart
class WebPreviewScreen extends StatefulWidget {
  final String url;
}

// Features:
// - Full WebView of the page
// - Bottom sheet with extraction confidence
// - "Extract Recipe" button (enabled only if recipe found)
// - Loading state while analyzing
// - Error state if page fails to load
```

Confidence indicator display:
```
┌─────────────────────────────────────────┐
│ ✓ Structured recipe found               │
│   8 ingredients · 6 steps               │
│                                         │
│   [Extract Recipe]                      │
└─────────────────────────────────────────┘
```

Or for heuristic:
```
┌─────────────────────────────────────────┐
│ ◐ Recipe detected via text analysis     │
│   ~12 ingredients · ~8 steps            │
│                                         │
│   [Extract Recipe]                      │
└─────────────────────────────────────────┘
```

Or when not found:
```
┌─────────────────────────────────────────┐
│ ✗ No recipe found on this page          │
│                                         │
│   This page doesn't appear to contain   │
│   a recipe, or requires login.          │
│                                         │
│   [Close]                               │
└─────────────────────────────────────────┘
```

### 7. Database Schema Updates

Add to `Recipe` model:

```dart
class Recipe {
  // Existing fields...

  // New fields for web extraction
  String? cachedHtml;        // Stored HTML for re-extraction
  String? pageTitle;         // Original page title
  String? extractionMethod;  // 'structured' or 'heuristic'
}
```

Migration:
```sql
ALTER TABLE recipes ADD COLUMN cached_html TEXT;
ALTER TABLE recipes ADD COLUMN page_title TEXT;
ALTER TABLE recipes ADD COLUMN extraction_method TEXT;
```

### 8. Integration Points

**HomeScreen URL input:**
```dart
void _handleUrlInput(String url) {
  final urlType = UrlClassifierService.classify(url);

  switch (urlType) {
    case UrlType.youtubeVideo:
    case UrlType.instagramVideo:
    case UrlType.tiktokVideo:
      // Existing video flow
      Navigator.push(VideoPreviewScreen(url: url));
      break;
    case UrlType.webPage:
      // New web flow
      Navigator.push(WebPreviewScreen(url: url));
      break;
    case UrlType.unsupported:
      _showUnsupportedUrlError();
      break;
  }
}
```

## Dependencies

New packages needed:

```yaml
dependencies:
  webview_flutter: ^4.4.0      # WebView preview
  html: ^0.15.4                 # HTML parsing
  http: ^1.1.0                  # Page fetching (if not using webview)
```

## File Structure

```
lib/
├── services/
│   ├── url_classifier_service.dart      # NEW
│   ├── web_fetch_service.dart           # NEW
│   └── web_recipe_extraction_service.dart # NEW
├── utils/
│   ├── schema_parser.dart               # NEW
│   └── html_text_extractor.dart         # NEW
├── screens/
│   └── web_preview_screen.dart          # NEW
└── models/
    └── recipe.dart                      # MODIFIED (new fields)
```

## Test Sites

### Structured Data (JSON-LD) - High Confidence Expected

| Site | URL | Notes |
|------|-----|-------|
| Delish | https://www.delish.com/cooking/recipe-ideas/a28207374/campfire-mac-and-cheese-recipe/ | User-provided |
| Pillsbury | https://www.pillsbury.com/recipes/easy-homemade-monkey-bread/7a1e41b1-4708-4028-8ce6-fcb5baebbc19 | User-provided |
| Betty Crocker | https://www.bettycrocker.com/recipes/slow-cooker-barbecued-ribs/16766efe-2d1e-4a28-9e87-b916ecbff2a1 | User-provided |
| AllRecipes | https://www.allrecipes.com/recipe/23600/worlds-best-lasagna/ | Large recipe site |
| Food Network | https://www.foodnetwork.com/recipes/food-network-kitchen/pancakes-recipe-1913844 | Major network |
| Serious Eats | https://www.seriouseats.com/the-best-slow-cooked-bolognese-sauce-recipe | Quality recipes |
| Epicurious | https://www.epicurious.com/recipes/food/views/my-favorite-chocolate-chip-cookies | Condé Nast |
| BBC Good Food | https://www.bbcgoodfood.com/recipes/easy-pancakes | UK site |

### Heuristic Parsing - Medium Confidence Expected

| Site | URL | Notes |
|------|-----|-------|
| Grown Strong | https://grownstrong.com/blogs/community-lifestyle-nutrition/the-best-overnight-oats-recipe-to-build-muscle-fuel-your-workout | User-provided, blog format |
| Personal blogs | Various | May lack structured data |
| Older recipe sites | Various | Pre-schema.org |

### Edge Cases to Test

| Scenario | Expected Behavior |
|----------|-------------------|
| Login-required page (NYT Cooking) | "Recipe content not accessible" |
| Paywall page | "Recipe content not accessible" |
| Non-recipe page | "No recipe found on this page" |
| Page with multiple recipes | Extract first/primary recipe |
| Recipe in comments | Ignore (extract main content only) |
| Print-friendly version | Should work well |
| AMP pages | Should work (structured data present) |

## Implementation Phases

### Phase 1: Core Infrastructure
- [ ] URL classifier service
- [ ] Web fetch service
- [ ] Database schema migration
- [ ] Recipe model updates

### Phase 2: Extraction Engine
- [ ] Schema.org/JSON-LD parser
- [ ] HTML text extractor
- [ ] Web recipe extraction service
- [ ] Confidence scoring

### Phase 3: UI
- [ ] WebView preview screen
- [ ] Confidence indicator widget
- [ ] Integration with home screen URL flow
- [ ] Error states and messaging

### Phase 4: Testing & Polish
- [ ] Unit tests for parsers
- [ ] Integration tests with test URLs
- [ ] Edge case handling
- [ ] Performance optimization

## Estimated Effort

| Phase | Effort |
|-------|--------|
| Phase 1: Core Infrastructure | Medium |
| Phase 2: Extraction Engine | Large |
| Phase 3: UI | Medium |
| Phase 4: Testing & Polish | Medium |

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Sites change HTML structure | Cache HTML for debugging, heuristic fallback |
| JavaScript-rendered content | WebView handles JS, fetch for initial analysis |
| Rate limiting by sites | Add delays, respect robots.txt |
| Large HTML pages | Limit fetch size, timeout handling |
| Schema.org variations | Test against many sites, flexible parsing |

## Success Criteria

- [ ] Successfully extracts from all 4 user-provided URLs
- [ ] Successfully extracts from 80%+ of structured data sites
- [ ] Gracefully handles login/paywall pages
- [ ] Confidence indicator accurately reflects extraction quality
- [ ] No recipe found → clear messaging, no garbage extraction
- [ ] Cached HTML allows re-extraction with improved parsers

## Future Enhancements (Out of Scope)

- Browser extension for easier URL sharing
- Bookmarklet support
- Recipe collections/folders
- Duplicate recipe detection across video + web sources
- Print-friendly recipe view
- Nutritional information extraction

---

**Created**: 2026-01-24
**Status**: Planning Complete - Ready for Implementation
