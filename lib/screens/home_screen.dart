import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/recipe_provider.dart';
import '../providers/sync_provider.dart';
import '../services/video_service.dart';
import '../services/share_handler_service.dart';
import '../models/recipe.dart';
import '../widgets/widgets.dart';
import 'recipe_detail_screen.dart';
import 'settings_screen.dart';
import 'video_preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final VideoService _videoService = VideoService();
  final ShareHandlerService _shareHandlerService = ShareHandlerService();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    // Delay data loading to after the first frame to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
    _initializeShareHandler();
  }

  @override
  void dispose() {
    _videoService.dispose();
    _shareHandlerService.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Initializes the share handler to receive shared URLs
  void _initializeShareHandler() {
    // Set up callback for incoming shared URLs
    _shareHandlerService.initialize(
      onUrlReceived: (url) {
        // Handle the shared URL
        if (mounted) {
          _handleSharedUrl(url);
        }
      },
    );

    // Check if there was a shared URL when the app was launched
    _shareHandlerService.getInitialSharedUrl().then((url) {
      if (url != null && mounted) {
        _handleSharedUrl(url);
      }
    });
  }

  /// Validates and handles a shared URL
  void _handleSharedUrl(String url) {
    if (!_videoService.isValidUrl(url)) return;
    _openVideoPreview(VideoSource.url(url));
  }

  Future<void> _loadData() async {
    final provider = context.read<RecipeProvider>();
    await provider.refresh();
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
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withAlpha(77),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add Recipe',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.link,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                title: const Text('Enter Video URL'),
                subtitle: const Text('Video or recipe page'),
                onTap: () {
                  Navigator.pop(context);
                  _showUrlInputDialog();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.video_library,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
                title: const Text('Choose Local Video'),
                subtitle: const Text('Pick from your device'),
                onTap: () {
                  Navigator.pop(context);
                  _pickLocalVideo();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  /// Shows dialog to input video URL
  void _showUrlInputDialog() {
    final urlController = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Enter Video URL'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: urlController,
                    decoration: InputDecoration(
                      hintText: 'Paste video link here...',
                      prefixIcon: const Icon(Icons.link),
                      border: const OutlineInputBorder(),
                      errorText: errorText,
                    ),
                    keyboardType: TextInputType.url,
                    autofocus: true,
                    onChanged: (_) {
                      if (errorText != null) {
                        setDialogState(() => errorText = null);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Paste any video or recipe URL',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final url = urlController.text.trim();
                    if (url.isEmpty) {
                      setDialogState(() => errorText = 'Please enter a URL');
                      return;
                    }
                    if (!_videoService.isValidUrl(url)) {
                      setDialogState(
                          () => errorText = 'Please enter a valid URL');
                      return;
                    }
                    Navigator.pop(context);
                    _openVideoPreview(VideoSource.url(url));
                  },
                  child: const Text('Continue'),
                ),
              ],
            );
          },
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
          content: Text(
            e is VideoException ? e.message : 'Failed to pick video: $e',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
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
      _loadData();
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        context.read<RecipeProvider>().clearSearch();
      }
    });
  }

  void _onSearchChanged(String query) {
    context.read<RecipeProvider>().setSearchQuery(query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Consumer<RecipeProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return _buildLoadingGrid();
          }

          if (provider.errorMessage != null) {
            return ErrorState.loadFailed(
              itemType: 'recipes',
              onRetry: _loadData,
            );
          }

          return RefreshIndicator(
            onRefresh: _loadData,
            child: CustomScrollView(
              slivers: [
                // Processing jobs section
                if (provider.activeJobs.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _buildProcessingJobsSection(provider),
                  ),
                ],
                // Recipe grid or empty state
                if (provider.recipes.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: provider.searchQuery != null
                        ? EmptyState.noSearchResults(
                            query: provider.searchQuery)
                        : EmptyState.noRecipes(
                            onAddRecipe: _showAddRecipeOptions),
                  )
                else
                  _buildRecipeGrid(provider),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddRecipeOptions,
        icon: const Icon(Icons.add),
        label: const Text('Add Recipe'),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isSearching) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _toggleSearch,
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search recipes...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: colorScheme.onSurface.withAlpha(128)),
          ),
          style: Theme.of(context).textTheme.bodyLarge,
          onChanged: _onSearchChanged,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
        ],
      );
    }

    return AppBar(
      title: const Text('Recipe Slurp'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: _toggleSearch,
        ),
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
    );
  }

  Widget _buildLoadingGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _calculateCrossAxisCount(constraints.maxWidth);
        return RecipeGridSkeleton(
          crossAxisCount: crossAxisCount,
          itemCount: crossAxisCount * 3,
        );
      },
    );
  }

  Widget _buildProcessingJobsSection(RecipeProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(
                Icons.hourglass_top,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Processing',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              Text(
                '${provider.activeJobs.length} active',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: provider.activeJobs.length,
            itemBuilder: (context, index) {
              final job = provider.activeJobs[index];
              return SizedBox(
                width: 200,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ProcessingJobCard(job: job),
                ),
              );
            },
          ),
        ),
        const Divider(height: 24),
      ],
    );
  }

  Widget _buildRecipeGrid(RecipeProvider provider) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount =
            _calculateCrossAxisCount(constraints.crossAxisExtent);
        return SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final recipe = provider.recipes[index];
                return RecipeCard(
                  recipe: recipe,
                  onTap: () => _openRecipeDetail(recipe),
                  onLongPress: () => _showRecipeOptions(recipe),
                );
              },
              childCount: provider.recipes.length,
            ),
          ),
        );
      },
    );
  }

  int _calculateCrossAxisCount(double width) {
    // Responsive grid: 2 columns for phones, 3+ for tablets
    if (width < 600) return 2;
    if (width < 900) return 3;
    if (width < 1200) return 4;
    return 5;
  }

  Future<void> _openRecipeDetail(Recipe recipe) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDetailScreen(recipe: recipe),
      ),
    );
    // Refresh recipes after returning from detail screen
    _loadData();
  }

  void _showRecipeOptions(Recipe recipe) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withAlpha(77),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('Open'),
                onTap: () {
                  Navigator.pop(context);
                  _openRecipeDetail(recipe);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(context);
                  _shareRecipe(recipe);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Delete',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteRecipe(recipe);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _shareRecipe(Recipe recipe) async {
    try {
      final syncProvider = context.read<SyncProvider>();
      await syncProvider.exportService.shareRecipeAsText(recipe);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteRecipe(Recipe recipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recipe'),
        content: Text(
          'Are you sure you want to delete "${recipe.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<RecipeProvider>();
      final success = await provider.deleteRecipe(recipe.id!);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipe deleted')),
        );
      }
    }
  }
}
