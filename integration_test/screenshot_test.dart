import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:recipe_ripper/models/recipe.dart';
import 'package:recipe_ripper/models/ingredient.dart';
import 'package:recipe_ripper/models/direction.dart';

/// Integration tests to capture screenshots of all app screens.
///
/// Run with:
/// ```
/// flutter test integration_test/screenshot_test.dart -d <device-id>
/// ```
///
/// Or use the provided script:
/// ```
/// ./scripts/take_ios_screenshots.sh
/// ```
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Sample recipe data for screenshots
  final sampleRecipes = [
    Recipe(
      id: '1',
      title: 'Classic Chocolate Chip Cookies',
      sourcePlatform: 'YouTube',
      sourceUrl: 'https://youtube.com/watch?v=abc123',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      ingredients: [
        Ingredient(
            quantity: 2.25,
            unit: 'cups',
            item: 'all-purpose flour',
            order: 0),
        Ingredient(
            quantity: 1, unit: 'teaspoon', item: 'baking soda', order: 1),
        Ingredient(quantity: 1, unit: 'teaspoon', item: 'salt', order: 2),
        Ingredient(
            quantity: 1, unit: 'cup', item: 'butter, softened', order: 3),
        Ingredient(
            quantity: 0.75, unit: 'cup', item: 'granulated sugar', order: 4),
        Ingredient(
            quantity: 0.75,
            unit: 'cup',
            item: 'packed brown sugar',
            order: 5),
        Ingredient(quantity: 2, unit: 'large', item: 'eggs', order: 6),
        Ingredient(
            quantity: 1, unit: 'teaspoon', item: 'vanilla extract', order: 7),
        Ingredient(
            quantity: 2, unit: 'cups', item: 'chocolate chips', order: 8),
      ],
      directions: [
        Direction(
            stepNumber: 1,
            text:
                'Preheat oven to 375°F (190°C). Line baking sheets with parchment paper.'),
        Direction(
            stepNumber: 2,
            text:
                'In a medium bowl, whisk together flour, baking soda, and salt. Set aside.'),
        Direction(
            stepNumber: 3,
            text:
                'In a large bowl, cream butter and sugars until light and fluffy, about 3 minutes.'),
        Direction(
            stepNumber: 4,
            text: 'Beat in eggs one at a time, then add vanilla extract.'),
        Direction(
            stepNumber: 5,
            text:
                'Gradually add flour mixture to wet ingredients, mixing until just combined.'),
        Direction(
            stepNumber: 6, text: 'Fold in chocolate chips with a spatula.'),
        Direction(
            stepNumber: 7,
            text:
                'Drop rounded tablespoons of dough onto prepared baking sheets, spacing 2 inches apart.'),
        Direction(
            stepNumber: 8,
            text:
                'Bake 9-11 minutes until golden brown. Cool on pan 5 minutes before transferring.'),
      ],
    ),
    Recipe(
      id: '2',
      title: 'Quick Tomato Pasta',
      sourcePlatform: 'Local Video',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ingredients: [
        Ingredient(quantity: 1, unit: 'pound', item: 'spaghetti', order: 0),
        Ingredient(
            quantity: 2, unit: 'tablespoons', item: 'olive oil', order: 1),
        Ingredient(
            quantity: 4, unit: 'cloves', item: 'garlic, minced', order: 2),
        Ingredient(
            quantity: 1,
            unit: 'can',
            item: 'crushed tomatoes (28 oz)',
            order: 3),
        Ingredient(quantity: 1, unit: 'teaspoon', item: 'dried basil', order: 4),
        Ingredient(item: 'Salt and pepper to taste', order: 5),
        Ingredient(item: 'Fresh parmesan for serving', order: 6),
      ],
      directions: [
        Direction(
            stepNumber: 1,
            text: 'Cook pasta according to package directions. Reserve 1 cup pasta water.'),
        Direction(
            stepNumber: 2,
            text: 'Heat olive oil in a large skillet over medium heat. Add garlic and cook 1 minute.'),
        Direction(
            stepNumber: 3,
            text: 'Add crushed tomatoes and basil. Simmer 10 minutes.'),
        Direction(
            stepNumber: 4,
            text: 'Toss pasta with sauce, adding pasta water as needed. Season to taste.'),
      ],
    ),
    Recipe(
      id: '3',
      title: 'Morning Smoothie Bowl',
      sourcePlatform: 'Vimeo',
      sourceUrl: 'https://vimeo.com/123456',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      ingredients: [
        Ingredient(quantity: 1, unit: 'cup', item: 'frozen berries', order: 0),
        Ingredient(quantity: 1, unit: 'medium', item: 'banana', order: 1),
        Ingredient(quantity: 0.5, unit: 'cup', item: 'Greek yogurt', order: 2),
        Ingredient(
            quantity: 0.25, unit: 'cup', item: 'almond milk', order: 3),
        Ingredient(item: 'Granola for topping', order: 4),
        Ingredient(item: 'Fresh fruit for topping', order: 5),
      ],
      directions: [
        Direction(
            stepNumber: 1,
            text: 'Add frozen berries, banana, yogurt, and almond milk to blender.'),
        Direction(
            stepNumber: 2,
            text: 'Blend until thick and smooth, about 30 seconds.'),
        Direction(
            stepNumber: 3,
            text: 'Pour into a bowl and top with granola and fresh fruit.'),
      ],
    ),
  ];

  /// Wrapper widget for testing screens with proper providers
  Widget createTestApp({required Widget child}) {
    return MaterialApp(
      title: 'Recipe Ripper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      home: child,
    );
  }

  /// Takes a screenshot and saves it to the screenshots directory
  Future<void> takeScreenshot(
    IntegrationTestWidgetsFlutterBinding binding,
    WidgetTester tester,
    String name,
  ) async {
    await tester.pumpAndSettle();
    // Wait a bit for any animations to complete
    await Future.delayed(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Convert Flutter surface to image and capture
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();

    // Take the screenshot
    final bytes = await binding.takeScreenshot(name);

    // Save to screenshots directory
    final dir = Directory('screenshots');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final file = File('screenshots/$name.png');
    await file.writeAsBytes(bytes);

    // Reset for next screenshot
    binding.reportData ??= <String, dynamic>{};
    binding.reportData!['screenshots'] ??= <String>[];
    (binding.reportData!['screenshots'] as List).add(name);
  }

  group('iOS App Screenshots', () {
    testWidgets('1. Home Screen - Empty State', (tester) async {
      // Mock empty state
      await tester.pumpWidget(
        createTestApp(
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Recipes'),
              actions: [
                IconButton(icon: const Icon(Icons.search), onPressed: () {}),
                IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
              ],
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.restaurant_menu,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Recipes Yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first recipe by tapping the + button',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Add Recipe'),
            ),
          ),
        ),
      );

      await takeScreenshot(binding, tester, '01_home_empty');
    });

    testWidgets('2. Home Screen - With Recipes', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Recipes'),
              actions: [
                IconButton(icon: const Icon(Icons.search), onPressed: () {}),
                IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
              ],
            ),
            body: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: sampleRecipes.length,
              itemBuilder: (context, index) {
                final recipe = sampleRecipes[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          width: double.infinity,
                          color: Colors.deepOrange.withAlpha(51),
                          child: const Icon(
                            Icons.restaurant,
                            size: 48,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                recipe.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    _getPlatformIcon(recipe.sourcePlatform),
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    recipe.sourcePlatform ?? 'Unknown',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                '${recipe.ingredients.length} ingredients',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Add Recipe'),
            ),
          ),
        ),
      );

      await takeScreenshot(binding, tester, '02_home_with_recipes');
    });

    testWidgets('3. Add Recipe Bottom Sheet', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: Scaffold(
            appBar: AppBar(title: const Text('Recipes')),
            body: Stack(
              children: [
                Container(color: Colors.grey[100]),
                Positioned.fill(
                  child: Container(color: Colors.black38),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 8),
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Add Recipe',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.deepOrange.withAlpha(26),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.link,
                                  color: Colors.deepOrange),
                            ),
                            title: const Text('Enter Video URL'),
                            subtitle: const Text(
                                'YouTube, Vimeo, or direct video link'),
                          ),
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withAlpha(26),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.video_library,
                                  color: Colors.blue),
                            ),
                            title: const Text('Pick from Camera Roll'),
                            subtitle:
                                const Text('Select a local video file'),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await takeScreenshot(binding, tester, '03_add_recipe_sheet');
    });

    testWidgets('4. Recipe Detail Screen', (tester) async {
      final recipe = sampleRecipes[0];
      await tester.pumpWidget(
        createTestApp(
          child: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      recipe.title,
                      style: const TextStyle(fontSize: 16),
                    ),
                    background: Container(
                      color: Colors.deepOrange.withAlpha(51),
                      child: const Icon(
                        Icons.restaurant,
                        size: 80,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ),
                  actions: [
                    IconButton(icon: const Icon(Icons.share), onPressed: () {}),
                    IconButton(icon: const Icon(Icons.edit), onPressed: () {}),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Source info
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(Icons.play_circle,
                                    color: Colors.red),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Source',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                    ),
                                    Text(recipe.sourcePlatform ?? 'Unknown'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Ingredients
                        const Text(
                          'Ingredients',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...recipe.ingredients
                            .take(5)
                            .map((ing) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Colors.deepOrange,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          child:
                                              Text(ing.toDisplayString())),
                                    ],
                                  ),
                                )),
                        const SizedBox(height: 24),

                        // Directions
                        const Text(
                          'Directions',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...recipe.directions.take(3).map((dir) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.deepOrange,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${dir.stepNumber}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(dir.text)),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await takeScreenshot(binding, tester, '04_recipe_detail');
    });

    testWidgets('5. Recipe Detail - Cooking Mode', (tester) async {
      final recipe = sampleRecipes[0];
      await tester.pumpWidget(
        createTestApp(
          child: Scaffold(
            appBar: AppBar(
              title: Text(recipe.title),
              actions: [
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.restaurant_menu),
                  label: const Text('Exit Cooking'),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Cooking mode banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withAlpha(77)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.restaurant_menu, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Cooking Mode Active',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Ingredients with checkboxes
                const Text(
                  'Ingredients',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...recipe.ingredients.take(5).asMap().entries.map((entry) {
                  final checked = entry.key < 3;
                  return CheckboxListTile(
                    value: checked,
                    onChanged: (_) {},
                    title: Text(
                      entry.value.toDisplayString(),
                      style: TextStyle(
                        decoration:
                            checked ? TextDecoration.lineThrough : null,
                        color: checked ? Colors.grey : null,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Colors.green,
                  );
                }),
                const SizedBox(height: 24),

                // Directions with current step highlighted
                const Text(
                  'Directions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...recipe.directions.take(4).asMap().entries.map((entry) {
                  final isActive = entry.key == 1;
                  final isCompleted = entry.key < 1;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.deepOrange.withAlpha(26)
                          : isCompleted
                              ? Colors.green.withAlpha(26)
                              : null,
                      borderRadius: BorderRadius.circular(8),
                      border: isActive
                          ? Border.all(color: Colors.deepOrange, width: 2)
                          : null,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? Colors.green
                                : isActive
                                    ? Colors.deepOrange
                                    : Colors.grey[300],
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: isCompleted
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 16)
                                : Text(
                                    '${entry.value.stepNumber}',
                                    style: TextStyle(
                                      color: isActive
                                          ? Colors.white
                                          : Colors.grey[600],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.value.text,
                            style: TextStyle(
                              fontWeight:
                                  isActive ? FontWeight.w500 : FontWeight.normal,
                              color: isCompleted ? Colors.grey : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      );

      await takeScreenshot(binding, tester, '05_cooking_mode');
    });

    testWidgets('6. Recipe Edit Screen', (tester) async {
      final recipe = sampleRecipes[0];
      await tester.pumpWidget(
        createTestApp(
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Edit Recipe'),
              actions: [
                TextButton(
                  onPressed: () {},
                  child: const Text('Save'),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Title
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recipe Title',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: recipe.title,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Ingredients
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Ingredients',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle,
                                  color: Colors.deepOrange),
                              onPressed: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...recipe.ingredients.take(4).map((ing) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.drag_handle,
                                      color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: ing.toDisplayString(),
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () {},
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await takeScreenshot(binding, tester, '06_recipe_edit');
    });

    testWidgets('7. Settings Screen', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: Scaffold(
            appBar: AppBar(title: const Text('Settings')),
            body: ListView(
              children: [
                // Cloud Sync Section
                _buildSettingsSection(
                  title: 'Cloud Sync',
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.cloud),
                      title: const Text('iCloud Sync'),
                      subtitle: const Text('Sync recipes across your devices'),
                      value: true,
                      onChanged: (_) {},
                    ),
                    ListTile(
                      leading: const Icon(Icons.sync),
                      title: const Text('Sync Now'),
                      subtitle: const Text('Last synced: Just now'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {},
                    ),
                  ],
                ),

                // Export Section
                _buildSettingsSection(
                  title: 'Export & Import',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.upload),
                      title: const Text('Export All Recipes'),
                      subtitle: const Text('Save as JSON or Markdown'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {},
                    ),
                    ListTile(
                      leading: const Icon(Icons.download),
                      title: const Text('Import Recipes'),
                      subtitle: const Text('Import from file'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {},
                    ),
                  ],
                ),

                // Storage Section
                _buildSettingsSection(
                  title: 'Storage',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.storage),
                      title: const Text('Storage Used'),
                      trailing: const Text('12.5 MB'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_outline,
                          color: Colors.red),
                      title: const Text('Clear All Data',
                          style: TextStyle(color: Colors.red)),
                      onTap: () {},
                    ),
                  ],
                ),

                // About Section
                _buildSettingsSection(
                  title: 'About',
                  children: [
                    const ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('Version'),
                      trailing: Text('1.0.0+1'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.code),
                      title: const Text('View on GitHub'),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () {},
                    ),
                    ListTile(
                      leading: const Icon(Icons.bug_report),
                      title: const Text('Report an Issue'),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      await takeScreenshot(binding, tester, '07_settings');
    });

    testWidgets('8. Share Options Modal', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: Scaffold(
            body: Stack(
              children: [
                Container(color: Colors.grey[100]),
                Positioned.fill(
                  child: Container(color: Colors.black38),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 8),
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Share Recipe',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withAlpha(26),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.share,
                                  color: Colors.blue),
                            ),
                            title: const Text('Share as Text'),
                            subtitle:
                                const Text('Share to Messages, Mail, etc.'),
                          ),
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withAlpha(26),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.file_download,
                                  color: Colors.green),
                            ),
                            title: const Text('Export as JSON'),
                            subtitle:
                                const Text('Save structured recipe file'),
                          ),
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.purple.withAlpha(26),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.description,
                                  color: Colors.purple),
                            ),
                            title: const Text('Export as Markdown'),
                            subtitle: const Text('Save formatted text file'),
                          ),
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withAlpha(26),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.copy,
                                  color: Colors.orange),
                            ),
                            title: const Text('Copy to Clipboard'),
                            subtitle:
                                const Text('Copy recipe as Markdown'),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await takeScreenshot(binding, tester, '08_share_options');
    });

    testWidgets('9. Processing Screen', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: Scaffold(
            appBar: AppBar(title: const Text('Processing Video')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: CircularProgressIndicator(
                            value: 0.65,
                            strokeWidth: 8,
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation(
                                Colors.deepOrange),
                          ),
                        ),
                        const Text(
                          '65%',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Extracting Text from Video',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This may take a few minutes...',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 48),

                    // Processing steps
                    _buildProcessingStep(
                      icon: Icons.check_circle,
                      color: Colors.green,
                      title: 'Downloaded video',
                      isComplete: true,
                    ),
                    _buildProcessingStep(
                      icon: Icons.check_circle,
                      color: Colors.green,
                      title: 'Extracted audio',
                      isComplete: true,
                    ),
                    _buildProcessingStep(
                      icon: Icons.check_circle,
                      color: Colors.green,
                      title: 'Transcribed speech',
                      isComplete: true,
                    ),
                    _buildProcessingStep(
                      icon: Icons.radio_button_unchecked,
                      color: Colors.deepOrange,
                      title: 'Extracting on-screen text...',
                      isComplete: false,
                      isActive: true,
                    ),
                    _buildProcessingStep(
                      icon: Icons.radio_button_unchecked,
                      color: Colors.grey,
                      title: 'Parse recipe',
                      isComplete: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await takeScreenshot(binding, tester, '09_processing');
    });

    testWidgets('10. Video Preview Screen', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: Scaffold(
            appBar: AppBar(title: const Text('Video Preview')),
            body: Column(
              children: [
                // Video thumbnail area
                Expanded(
                  flex: 2,
                  child: Container(
                    width: double.infinity,
                    color: Colors.black87,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.play_circle_outline,
                            size: 64, color: Colors.white70),
                        const SizedBox(height: 16),
                        Text(
                          'Amazing Chocolate Cake Recipe',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '12:34',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ),
                ),

                // Video info
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Video Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                            Icons.video_library, 'Source', 'YouTube'),
                        _buildInfoRow(
                            Icons.timer, 'Duration', '12 minutes 34 seconds'),
                        _buildInfoRow(Icons.high_quality, 'Resolution',
                            '1920 x 1080'),
                        _buildInfoRow(
                            Icons.storage, 'Size', '156.4 MB'),
                        _buildInfoRow(Icons.schedule, 'Est. Processing',
                            '2-3 minutes'),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.restaurant_menu),
                            label: const Text('Extract Recipe'),
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await takeScreenshot(binding, tester, '10_video_preview');
    });
  });
}

/// Helper to get platform icon
IconData _getPlatformIcon(String? platform) {
  switch (platform?.toLowerCase()) {
    case 'youtube':
      return Icons.play_circle;
    case 'vimeo':
      return Icons.video_library;
    case 'local video':
      return Icons.phone_android;
    default:
      return Icons.link;
  }
}

/// Helper to build settings section
Widget _buildSettingsSection({
  required String title,
  required List<Widget> children,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
      ),
      ...children,
    ],
  );
}

/// Helper to build processing step
Widget _buildProcessingStep({
  required IconData icon,
  required Color color,
  required String title,
  required bool isComplete,
  bool isActive = false,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
            color: isComplete || isActive ? Colors.black87 : Colors.grey,
          ),
        ),
      ],
    ),
  );
}

/// Helper to build info row
Widget _buildInfoRow(IconData icon, String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}
