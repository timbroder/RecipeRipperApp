import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/video_service.dart';
import '../services/share_handler_service.dart';
import '../models/recipe.dart';
import 'recipe_detail_screen.dart';
import 'settings_screen.dart';
import 'video_preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Recipe> _recipes = [];
  bool _isLoading = true;
  final VideoService _videoService = VideoService();
  final ShareHandlerService _shareHandlerService = ShareHandlerService();

  @override
  void initState() {
    super.initState();
    _loadRecipes();
    _initializeShareHandler();
  }

  @override
  void dispose() {
    _videoService.dispose();
    _shareHandlerService.dispose();
    super.dispose();
  }

  /// Initializes the share handler to receive shared URLs
  void _initializeShareHandler() {
    // Set up callback for incoming shared URLs
    _shareHandlerService.initialize(
      onUrlReceived: (url) {
        // Handle the shared URL
        if (mounted) {
          _openVideoPreview(VideoSource.url(url));
        }
      },
    );

    // Check if there was a shared URL when the app was launched
    _shareHandlerService.getInitialSharedUrl().then((url) {
      if (url != null && mounted) {
        _openVideoPreview(VideoSource.url(url));
      }
    });
  }

  Future<void> _loadRecipes() async {
    setState(() => _isLoading = true);

    final databaseService = context.read<DatabaseService>();
    final recipes = await databaseService.getAllRecipes();

    setState(() {
      _recipes = recipes;
      _isLoading = false;
    });
  }

  /// Shows options to add a new recipe (URL or local file)
  void _showAddRecipeOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Enter Video URL'),
                subtitle: const Text('YouTube or direct video link'),
                onTap: () {
                  Navigator.pop(context);
                  _showUrlInputDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('Choose Local Video'),
                subtitle: const Text('Pick from your device'),
                onTap: () {
                  Navigator.pop(context);
                  _pickLocalVideo();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// Shows dialog to input video URL
  void _showUrlInputDialog() {
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Video URL'),
          content: TextField(
            controller: urlController,
            decoration: const InputDecoration(
              hintText: 'https://youtube.com/watch?v=...',
              prefixIcon: Icon(Icons.link),
            ),
            keyboardType: TextInputType.url,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final url = urlController.text.trim();
                Navigator.pop(context);
                if (url.isNotEmpty) {
                  _openVideoPreview(VideoSource.url(url));
                }
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  /// Picks a local video file
  Future<void> _pickLocalVideo() async {
    try {
      final filePath = await _videoService.pickVideoFile();

      if (filePath != null && mounted) {
        _openVideoPreview(VideoSource.file(filePath));
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is VideoException ? e.message : 'Failed to pick video: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Opens the video preview screen
  Future<void> _openVideoPreview(VideoSource videoSource) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPreviewScreen(videoSource: videoSource),
      ),
    );

    // Reload recipes if processing was successful
    if (result == true && mounted) {
      _loadRecipes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Ripper'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recipes.isEmpty
              ? _buildEmptyState()
              : _buildRecipeGrid(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddRecipeOptions,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 120,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'No Recipes Yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Tap the + button to add your first recipe from a cooking video',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeGrid() {
    return RefreshIndicator(
      onRefresh: _loadRecipes,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _recipes.length,
        itemBuilder: (context, index) {
          final recipe = _recipes[index];
          return _RecipeCard(
            recipe: recipe,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecipeDetailScreen(recipe: recipe),
                ),
              );
              // Refresh recipes after returning from detail screen
              _loadRecipes();
            },
          );
        },
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const _RecipeCard({required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: recipe.thumbnailPath != null
                    ? Image.asset(
                        recipe.thumbnailPath!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholderImage(context);
                        },
                      )
                    : _buildPlaceholderImage(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (recipe.sourcePlatform != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      recipe.sourcePlatform!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(BuildContext context) {
    return Center(
      child: Icon(
        Icons.restaurant,
        size: 64,
        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
      ),
    );
  }
}
