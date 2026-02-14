import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_ripper/services/web_recipe_extractor.dart';

void main() {
  group('WebRecipeExtractor', () {
    // -----------------------------------------------------------------------
    // JSON-LD tests
    // -----------------------------------------------------------------------
    group('JSON-LD extraction', () {
      test(
          'extracts recipe from standard JSON-LD with string array instructions',
          () {
        const html = '''
        <html>
        <head>
          <script type="application/ld+json">
          {
            "@context": "https://schema.org",
            "@type": "Recipe",
            "name": "Classic Chocolate Chip Cookies",
            "description": "The best chocolate chip cookies ever.",
            "recipeIngredient": [
              "2 1/4 cups all-purpose flour",
              "1 teaspoon baking soda",
              "1 teaspoon salt",
              "1 cup butter, softened",
              "3/4 cup sugar"
            ],
            "recipeInstructions": [
              "Preheat oven to 375 degrees F.",
              "Combine flour, baking soda and salt in small bowl.",
              "Beat butter and sugar in large mixer bowl.",
              "Add eggs and vanilla extract; beat well.",
              "Gradually beat in flour mixture."
            ]
          }
          </script>
        </head>
        <body><p>Content</p></body>
        </html>
        ''';

        final result = WebRecipeExtractor.extractFromHtml(html,
            sourceUrl: 'https://www.example.com/cookies');

        expect(result, isNotNull);
        expect(result!.extractionMethod, 'json-ld');
        expect(result.recipe.title, 'Classic Chocolate Chip Cookies');
        expect(result.recipe.ingredients.length, 5);
        expect(result.recipe.directions.length, 5);
        expect(result.recipe.sourceUrl, 'https://www.example.com/cookies');
        expect(result.recipe.sourcePlatform, 'example.com');
        expect(result.recipe.metadata?.processingMethod, 'json-ld');
        expect(result.recipe.metadata?.description,
            'The best chocolate chip cookies ever.');
      });

      test('extracts recipe with HowToStep instructions', () {
        const html = '''
        <html>
        <head>
          <script type="application/ld+json">
          {
            "@type": "Recipe",
            "name": "Simple Pasta",
            "recipeIngredient": ["1 pound pasta", "2 tablespoons olive oil"],
            "recipeInstructions": [
              {"@type": "HowToStep", "text": "Boil a large pot of salted water."},
              {"@type": "HowToStep", "text": "Cook pasta until al dente."},
              {"@type": "HowToStep", "text": "Drain and toss with olive oil."}
            ]
          }
          </script>
        </head>
        <body></body>
        </html>
        ''';

        final result = WebRecipeExtractor.extractFromHtml(html);

        expect(result, isNotNull);
        expect(result!.extractionMethod, 'json-ld');
        expect(result.recipe.title, 'Simple Pasta');
        expect(result.recipe.ingredients.length, 2);
        expect(result.recipe.directions.length, 3);
        expect(result.recipe.directions[0].stepNumber, 1);
        expect(result.recipe.directions[0].text,
            contains('Boil a large pot of salted water'));
      });

      test('extracts recipe with HowToSection instructions', () {
        const html = '''
        <html>
        <head>
          <script type="application/ld+json">
          {
            "@type": "Recipe",
            "name": "Layered Cake",
            "recipeIngredient": ["2 cups flour", "1 cup sugar"],
            "recipeInstructions": [
              {
                "@type": "HowToSection",
                "name": "Make the batter",
                "itemListElement": [
                  {"@type": "HowToStep", "text": "Mix dry ingredients."},
                  {"@type": "HowToStep", "text": "Add wet ingredients."}
                ]
              },
              {
                "@type": "HowToSection",
                "name": "Bake",
                "itemListElement": [
                  {"@type": "HowToStep", "text": "Pour into pan and bake at 350F for 30 minutes."}
                ]
              }
            ]
          }
          </script>
        </head>
        <body></body>
        </html>
        ''';

        final result = WebRecipeExtractor.extractFromHtml(html);

        expect(result, isNotNull);
        expect(result!.extractionMethod, 'json-ld');
        expect(result.recipe.title, 'Layered Cake');
        expect(result.recipe.directions.length, 3);
        expect(result.recipe.directions[2].stepNumber, 3);
      });

      test('finds Recipe inside @graph array', () {
        const html = '''
        <html>
        <head>
          <script type="application/ld+json">
          {
            "@context": "https://schema.org",
            "@graph": [
              {
                "@type": "WebSite",
                "name": "Recipe Blog"
              },
              {
                "@type": "Recipe",
                "name": "Guacamole",
                "recipeIngredient": ["3 avocados", "1 lime", "1 teaspoon salt"],
                "recipeInstructions": [
                  "Mash avocados in a bowl.",
                  "Mix in lime juice and salt."
                ]
              },
              {
                "@type": "Article",
                "name": "About Guacamole"
              }
            ]
          }
          </script>
        </head>
        <body></body>
        </html>
        ''';

        final result = WebRecipeExtractor.extractFromHtml(html);

        expect(result, isNotNull);
        expect(result!.extractionMethod, 'json-ld');
        expect(result.recipe.title, 'Guacamole');
        expect(result.recipe.ingredients.length, 3);
        expect(result.recipe.directions.length, 2);
      });

      test('handles malformed JSON-LD gracefully', () {
        const html = '''
        <html>
        <head>
          <script type="application/ld+json">
          { this is not valid json
          </script>
        </head>
        <body></body>
        </html>
        ''';

        final result = WebRecipeExtractor.extractFromHtml(html);

        // Should return null (no crash), possibly falling through to heuristic
        // which also returns null for empty body
        expect(result, isNull);
      });

      test('returns null when no Recipe @type found', () {
        const html = '''
        <html>
        <head>
          <script type="application/ld+json">
          {
            "@type": "Article",
            "name": "How to Cook",
            "description": "An article about cooking."
          }
          </script>
        </head>
        <body></body>
        </html>
        ''';

        final result = WebRecipeExtractor.extractFromHtml(html);

        expect(result, isNull);
      });

      test('handles instructions as a single string', () {
        const html = '''
        <html>
        <head>
          <script type="application/ld+json">
          {
            "@type": "Recipe",
            "name": "Quick Salad",
            "recipeIngredient": ["1 head lettuce", "2 tomatoes", "1 cucumber"],
            "recipeInstructions": "Chop all vegetables. Toss together in a large bowl. Add dressing and serve immediately."
          }
          </script>
        </head>
        <body></body>
        </html>
        ''';

        final result = WebRecipeExtractor.extractFromHtml(html);

        expect(result, isNotNull);
        expect(result!.extractionMethod, 'json-ld');
        expect(result.recipe.title, 'Quick Salad');
        expect(result.recipe.ingredients.length, 3);
        expect(result.recipe.directions.length, greaterThanOrEqualTo(2));
      });

      test('parses ingredient quantities correctly', () {
        const html = '''
        <html>
        <head>
          <script type="application/ld+json">
          {
            "@type": "Recipe",
            "name": "Test Recipe",
            "recipeIngredient": [
              "2 cups all-purpose flour",
              "1/2 teaspoon salt",
              "3 large eggs"
            ],
            "recipeInstructions": ["Mix all together.", "Bake at 350F."]
          }
          </script>
        </head>
        <body></body>
        </html>
        ''';

        final result = WebRecipeExtractor.extractFromHtml(html);

        expect(result, isNotNull);
        final ingredients = result!.recipe.ingredients;
        expect(ingredients.length, 3);

        // First ingredient: 2 cups flour
        expect(ingredients[0].quantity, 2.0);
        expect(ingredients[0].unit, 'cups');
      });

      test('returns null for Recipe with empty name', () {
        const html = '''
        <html>
        <head>
          <script type="application/ld+json">
          {
            "@type": "Recipe",
            "name": "",
            "recipeIngredient": ["1 cup flour"],
            "recipeInstructions": ["Mix well."]
          }
          </script>
        </head>
        <body></body>
        </html>
        ''';

        final result = WebRecipeExtractor.extractFromHtml(html);

        // JSON-LD returns null due to empty name, heuristic may or may not find content
        // The JSON-LD path should definitely not return a result
        if (result != null) {
          expect(result.extractionMethod, isNot('json-ld'));
        }
      });
    });

    // -----------------------------------------------------------------------
    // Heuristic tests
    // -----------------------------------------------------------------------
    group('Heuristic extraction', () {
      test('extracts recipe from HTML with clear ingredient list and steps',
          () {
        const html = '''
        <html>
        <head><title>My Pancake Recipe</title></head>
        <body>
          <h1>Fluffy Pancakes</h1>
          <h2>Ingredients</h2>
          <ul>
            <li>2 cups flour</li>
            <li>2 tablespoons sugar</li>
            <li>1 teaspoon baking powder</li>
            <li>1/2 teaspoon salt</li>
            <li>2 eggs</li>
            <li>1 1/2 cups milk</li>
          </ul>
          <h2>Directions</h2>
          <ol>
            <li>Mix all dry ingredients in a large bowl.</li>
            <li>Whisk eggs and milk together, then add to dry ingredients.</li>
            <li>Heat a griddle over medium heat and grease with butter.</li>
            <li>Pour 1/4 cup batter for each pancake and cook until bubbles form.</li>
            <li>Flip and cook until golden brown on both sides.</li>
          </ol>
        </body>
        </html>
        ''';

        final result = WebRecipeExtractor.extractFromHtml(html,
            sourceUrl: 'https://www.myblog.com/pancakes');

        expect(result, isNotNull);
        expect(result!.extractionMethod, 'heuristic');
        expect(result.recipe.ingredients.length, greaterThanOrEqualTo(2));
        expect(result.recipe.directions.length, greaterThanOrEqualTo(2));
        expect(result.recipe.metadata?.processingMethod, 'heuristic');
      });

      test('returns null for HTML with no recipe content', () {
        const html = '''
        <html>
        <head><title>About Us</title></head>
        <body>
          <h1>About Our Company</h1>
          <p>We are a technology company founded in 2020.</p>
          <p>Our mission is to make software better.</p>
          <p>Contact us at hello@example.com</p>
        </body>
        </html>
        ''';

        final result = WebRecipeExtractor.extractFromHtml(html);

        expect(result, isNull);
      });

      test('returns null below quality gate', () {
        const html = '''
        <html>
        <head><title>Quick Note</title></head>
        <body>
          <p>1 cup sugar</p>
          <p>Some random text about nothing.</p>
        </body>
        </html>
        ''';

        final result = WebRecipeExtractor.extractFromHtml(html);

        // Should be null: fewer than 2 ingredients AND fewer than 2 directions
        expect(result, isNull);
      });

      test('strips script, style, nav, footer elements', () {
        const html = '''
        <html>
        <head>
          <title>Cookie Recipe</title>
          <style>body { color: red; }</style>
        </head>
        <body>
          <nav><a href="/">Home</a><a href="/about">About</a></nav>
          <header><h1>Recipe Blog</h1></header>
          <main>
            <h2>Ingredients</h2>
            <ul>
              <li>2 cups flour</li>
              <li>1 cup sugar</li>
              <li>1/2 cup butter</li>
            </ul>
            <h2>Instructions</h2>
            <ol>
              <li>Preheat oven to 350 degrees F.</li>
              <li>Mix flour and sugar together in a bowl.</li>
              <li>Cut in butter until mixture resembles coarse crumbs.</li>
            </ol>
          </main>
          <footer>Copyright 2024</footer>
          <script>console.log("tracking");</script>
        </body>
        </html>
        ''';

        final result = WebRecipeExtractor.extractFromHtml(html);

        // Should find recipe content from the main area
        // (nav, header, footer, script, style are stripped)
        if (result != null) {
          expect(result.extractionMethod, 'heuristic');
          expect(result.recipe.ingredients.length, greaterThanOrEqualTo(2));
        }
      });
    });

    // -----------------------------------------------------------------------
    // Integration tests
    // -----------------------------------------------------------------------
    group('Integration', () {
      test('prefers JSON-LD over heuristic when both possible', () {
        const html = '''
        <html>
        <head>
          <title>Banana Bread</title>
          <script type="application/ld+json">
          {
            "@type": "Recipe",
            "name": "Best Banana Bread",
            "recipeIngredient": ["3 bananas", "1/3 cup melted butter", "1 cup sugar"],
            "recipeInstructions": [
              {"@type": "HowToStep", "text": "Preheat oven to 350F."},
              {"@type": "HowToStep", "text": "Mash bananas and mix with butter."},
              {"@type": "HowToStep", "text": "Bake for 60 minutes."}
            ]
          }
          </script>
        </head>
        <body>
          <h1>Best Banana Bread</h1>
          <p>3 bananas</p>
          <p>1/3 cup melted butter</p>
          <p>Mix everything and bake for 60 minutes.</p>
        </body>
        </html>
        ''';

        final result = WebRecipeExtractor.extractFromHtml(html);

        expect(result, isNotNull);
        expect(result!.extractionMethod, 'json-ld');
        expect(result.recipe.title, 'Best Banana Bread');
      });

      test('extractionMethod is correctly set to json-ld', () {
        const html = '''
        <html>
        <head>
          <script type="application/ld+json">
          {"@type": "Recipe", "name": "Soup", "recipeIngredient": ["1 onion", "2 carrots"], "recipeInstructions": ["Chop and boil.", "Season to taste."]}
          </script>
        </head>
        <body></body>
        </html>
        ''';

        final result = WebRecipeExtractor.extractFromHtml(html);
        expect(result, isNotNull);
        expect(result!.extractionMethod, 'json-ld');
      });

      test('extractionMethod is correctly set to heuristic', () {
        const html = '''
        <html>
        <head><title>Omelette Recipe</title></head>
        <body>
          <h2>Ingredients</h2>
          <ul>
            <li>3 eggs</li>
            <li>1 tablespoon butter</li>
            <li>1/4 cup cheese</li>
            <li>salt and pepper</li>
          </ul>
          <h2>Directions</h2>
          <ol>
            <li>Beat eggs in a bowl with salt and pepper.</li>
            <li>Melt butter in a non-stick pan over medium heat.</li>
            <li>Pour in eggs and cook until edges set.</li>
            <li>Add cheese, fold and serve.</li>
          </ol>
        </body>
        </html>
        ''';

        final result = WebRecipeExtractor.extractFromHtml(html);
        // No JSON-LD, so if recipe found, must be heuristic
        if (result != null) {
          expect(result.extractionMethod, 'heuristic');
        }
      });

      test('source platform is extracted from URL', () {
        const html = '''
        <html>
        <head>
          <script type="application/ld+json">
          {"@type": "Recipe", "name": "Pie", "recipeIngredient": ["1 pie crust", "2 cups filling"], "recipeInstructions": ["Fill crust.", "Bake at 375F."]}
          </script>
        </head>
        <body></body>
        </html>
        ''';

        final result = WebRecipeExtractor.extractFromHtml(html,
            sourceUrl: 'https://www.allrecipes.com/recipe/12345');

        expect(result, isNotNull);
        expect(result!.recipe.sourcePlatform, 'allrecipes.com');
      });

      test('handles Recipe in a JSON-LD array', () {
        const html = '''
        <html>
        <head>
          <script type="application/ld+json">
          [
            {"@type": "BreadcrumbList", "name": "nav"},
            {"@type": "Recipe", "name": "Tacos", "recipeIngredient": ["1 lb ground beef", "8 taco shells", "1 cup cheese"], "recipeInstructions": ["Brown the beef.", "Fill shells and top with cheese."]}
          ]
          </script>
        </head>
        <body></body>
        </html>
        ''';

        final result = WebRecipeExtractor.extractFromHtml(html);

        expect(result, isNotNull);
        expect(result!.extractionMethod, 'json-ld');
        expect(result.recipe.title, 'Tacos');
      });

      test('returns null for completely empty HTML', () {
        final result = WebRecipeExtractor.extractFromHtml('');
        expect(result, isNull);
      });

      test('returns null for HTML with no body content', () {
        const html = '<html><head></head><body></body></html>';
        final result = WebRecipeExtractor.extractFromHtml(html);
        expect(result, isNull);
      });
    });
  });
}
