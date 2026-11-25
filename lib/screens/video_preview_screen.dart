import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipe_ripper/models/recipe.dart';
import 'package:recipe_ripper/providers/recipe_provider.dart';
import 'package:recipe_ripper/services/video_service.dart';
import 'processing_screen.dart';
import 'recipe_detail_screen.dart';

/// Screen for previewing video metadata or web recipe before processing
class VideoPreviewScreen extends StatefulWidget {
  final VideoSource videoSource;

  const VideoPreviewScreen({
    super.key,
    required this.videoSource,
  });

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  final VideoService _videoService = VideoService();

  VideoMetadata? _metadata;
  Recipe? _webRecipe;
  String? _extractionMethod;
  bool _isLoading = true;
  // ignore: unused_field
  final bool _isProcessing = false;
  bool _isSaving = false;
  double _downloadProgress = 0.0;
  String _statusMessage = 'Loading...';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  @override
  void dispose() {
    _videoService.dispose();
    super.dispose();
  }

  /// Loads the video (downloads if URL, or uses local file)
  Future<void> _loadVideo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _webRecipe = null;
      _extractionMethod = null;
    });

    try {
      if (widget.videoSource.isUrl) {
        // Download from URL — may return video or web recipe
        final result = await _videoService.downloadVideo(
          widget.videoSource.url!,
          onProgress: (progress, status) {
            setState(() {
              _downloadProgress = progress;
              _statusMessage = status;
            });
          },
        );

        switch (result) {
          case VideoDownloaded(:final filePath):
            // Extract metadata for video
            setState(() {
              _statusMessage = 'Extracting video information...';
            });

            final metadata = await _videoService.extractMetadata(
              filePath,
              sourceUrl: widget.videoSource.url,
            );

            setState(() {
              _metadata = metadata;
              _isLoading = false;
            });

          case WebRecipeExtracted(:final recipe, :final extractionMethod):
            setState(() {
              _webRecipe = recipe;
              _extractionMethod = extractionMethod;
              _isLoading = false;
            });
        }
      } else {
        // Use local file
        final videoPath = widget.videoSource.filePath!;
        setState(() {
          _statusMessage = 'Loading video...';
        });

        // Extract metadata
        setState(() {
          _statusMessage = 'Extracting video information...';
        });

        final metadata = await _videoService.extractMetadata(
          videoPath,
          sourceUrl: widget.videoSource.url,
        );

        setState(() {
          _metadata = metadata;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            e is VideoException ? e.message : 'Failed to load video: $e';
      });
    }
  }

  /// Processes the video
  Future<void> _processVideo() async {
    if (_metadata == null) return;

    // Navigate to processing screen
    if (mounted) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ProcessingScreen(
            videoPath: _metadata!.localPath,
            sourceUrl: _metadata!.sourceUrl,
            videoTitle: _metadata!.title,
            description: _metadata!.description,
          ),
        ),
      );
    }
  }

  /// Saves a web-extracted recipe to the database
  Future<void> _saveWebRecipe() async {
    if (_webRecipe == null || _isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final provider = context.read<RecipeProvider>();
      final savedRecipe = await provider.addRecipe(_webRecipe!);

      if (savedRecipe != null && mounted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => RecipeDetailScreen(recipe: savedRecipe),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save recipe: $e')),
        );
      }
    }
  }

  /// Cancels and goes back
  void _cancel() {
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_webRecipe != null ? 'Preview Recipe' : 'Preview Video'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isProcessing ? null : _cancel,
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingView();
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    if (_webRecipe != null) {
      return _buildWebRecipePreview();
    }

    if (_metadata != null) {
      return _buildPreviewView();
    }

    return const Center(
      child: Text('No video loaded'),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              _statusMessage,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (widget.videoSource.isUrl && _downloadProgress > 0) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _downloadProgress),
              const SizedBox(height: 8),
              Text(
                '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 24),
            Text(
              'Error Loading Video',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _loadVideo,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: _cancel,
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebRecipePreview() {
    final recipe = _webRecipe!;
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Placeholder icon
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.article,
                    size: 64,
                    color: colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Web Recipe',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Recipe Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    Icons.restaurant,
                    'Ingredients',
                    '${recipe.ingredients.length}',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.format_list_numbered,
                    'Steps',
                    '${recipe.directions.length}',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.auto_awesome,
                    'Extraction',
                    _extractionMethod == 'json-ld'
                        ? 'Structured data (JSON-LD)'
                        : 'Heuristic analysis',
                  ),
                  if (recipe.sourceUrl != null) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.link,
                      'Source',
                      _getTruncatedUrl(recipe.sourceUrl!),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Ingredient preview
          if (recipe.ingredients.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ingredients Preview',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    ...recipe.ingredients.take(5).map((ingredient) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '\u2022 ',
                                style: TextStyle(color: colorScheme.primary),
                              ),
                              Expanded(
                                child: Text(ingredient.toDisplayString()),
                              ),
                            ],
                          ),
                        )),
                    if (recipe.ingredients.length > 5) ...[
                      const SizedBox(height: 4),
                      Text(
                        'and ${recipe.ingredients.length - 5} more...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Success info card
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Recipe found directly on page \u2014 no video processing needed!',
                      style: TextStyle(color: Colors.green.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Action Buttons
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveWebRecipe,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save Recipe'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _cancel,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPreviewView() {
    final metadata = _metadata!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thumbnail
          _buildThumbnail(metadata),
          const SizedBox(height: 24),

          // Video Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metadata.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    Icons.access_time,
                    'Duration',
                    _formatDuration(metadata.duration),
                  ),
                  const SizedBox(height: 8),
                  if (metadata.resolution != null)
                    _buildInfoRow(
                      Icons.video_settings,
                      'Resolution',
                      metadata.resolution!,
                    ),
                  const SizedBox(height: 8),
                  if (metadata.fileSizeBytes != null)
                    _buildInfoRow(
                      Icons.storage,
                      'File Size',
                      _formatFileSize(metadata.fileSizeBytes!),
                    ),
                  const SizedBox(height: 8),
                  if (metadata.sourceUrl != null)
                    _buildInfoRow(
                      Icons.link,
                      'Source',
                      _getTruncatedUrl(metadata.sourceUrl!),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Estimated Processing Time
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Estimated processing time: ${_estimateProcessingTime(metadata.duration)}',
                      style: TextStyle(color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Action Buttons
          if (_isProcessing)
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Starting processing...'),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: _processVideo,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Process Recipe'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _cancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildThumbnail(VideoMetadata metadata) {
    if (metadata.thumbnailPath != null) {
      final file = File(metadata.thumbnailPath!);
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildThumbnailPlaceholder();
            },
          ),
        ),
      );
    }

    return _buildThumbnailPlaceholder();
  }

  Widget _buildThumbnailPlaceholder() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.video_library,
          size: 64,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: Colors.grey.shade800),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
    }
  }

  String _getTruncatedUrl(String url) {
    if (url.length <= 50) {
      return url;
    }
    return '${url.substring(0, 47)}...';
  }

  String _estimateProcessingTime(Duration videoDuration) {
    // Rough estimate: processing takes 20-40% of video duration
    final minTime = (videoDuration.inSeconds * 0.2).round();
    final maxTime = (videoDuration.inSeconds * 0.4).round();

    if (minTime < 60 && maxTime < 60) {
      return '$minTime-$maxTime seconds';
    } else {
      final minMinutes = (minTime / 60).round();
      final maxMinutes = (maxTime / 60).round();
      return '$minMinutes-$maxMinutes minutes';
    }
  }
}
