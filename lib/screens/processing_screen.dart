import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../models/processing_job.dart';
import '../services/background_processing_service.dart';
import '../services/database_service.dart';
import '../services/processing_service.dart';
import '../services/notification_service.dart';
import 'recipe_detail_screen.dart';

/// Screen that shows processing progress for a video
class ProcessingScreen extends StatefulWidget {
  final String videoPath;
  final String? sourceUrl;
  final String? videoTitle;
  final String? description;

  const ProcessingScreen({
    super.key,
    required this.videoPath,
    this.sourceUrl,
    this.videoTitle,
    this.description,
  });

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with WidgetsBindingObserver {
  late ProcessingService _processingService;
  late NotificationService _notificationService;
  late DatabaseService _databaseService;
  String? _jobId;
  ProcessingJob? _currentJob;
  bool _isBackgroundProcessing = false;
  bool _backgroundAvailable = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _databaseService = DatabaseService();
    _processingService = ProcessingService(
      databaseService: _databaseService,
    );
    _notificationService = NotificationService();
    _notificationService.initialize();
    _checkBackgroundAvailability();
    _startProcessing();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !_isBackgroundProcessing) {
      // App is going to background, switch to background processing if available
      _switchToBackgroundProcessing();
    } else if (state == AppLifecycleState.resumed && _isBackgroundProcessing) {
      // App is back in foreground, start polling for updates
      _startPollingForUpdates();
    }
  }

  Future<void> _checkBackgroundAvailability() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final available = await BackgroundProcessingService.isAvailable();
      if (mounted) {
        setState(() {
          _backgroundAvailable = available;
        });
      }
    }
  }

  Future<void> _switchToBackgroundProcessing() async {
    if (!_backgroundAvailable || _jobId == null) return;

    // Schedule the job for background processing
    await BackgroundProcessingService.scheduleProcessing(
      jobId: _jobId!,
      videoPath: widget.videoPath,
      sourceUrl: widget.sourceUrl,
    );

    if (mounted) {
      setState(() {
        _isBackgroundProcessing = true;
      });
    }
  }

  void _startPollingForUpdates() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_jobId != null) {
        final job = await _processingService.getJob(_jobId!);
        if (job != null && mounted) {
          setState(() {
            _currentJob = job;
          });

          // Check if completed
          if (job.status == ProcessingStatus.completed &&
              job.recipeId != null) {
            _pollTimer?.cancel();
            _navigateToRecipe(job.recipeId!);
          } else if (job.status == ProcessingStatus.failed) {
            _pollTimer?.cancel();
            _showError(job.errorMessage ?? 'Processing failed');
          }
        }
      }
    });
  }

  Future<void> _navigateToRecipe(String recipeId) async {
    final recipe = await _databaseService.getRecipe(recipeId);
    if (recipe != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => RecipeDetailScreen(recipe: recipe),
        ),
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Processing failed: $message'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _startProcessing() async {
    try {
      // Request permissions if needed
      await _notificationService.requestPermission();

      // Start processing
      _jobId = await _processingService.processVideo(
        widget.videoPath,
        sourceUrl: widget.sourceUrl,
        description: widget.description,
        videoTitle: widget.videoTitle,
        onProgress: (jobId, status, progress, currentStep) {
          setState(() {
            _currentJob = ProcessingJob(
              id: jobId,
              localVideoPath: widget.videoPath,
              sourceUrl: widget.sourceUrl,
              status: status,
              progress: progress,
              currentStep: currentStep,
            );
          });

          // Update notification
          _notificationService.showJobStatusNotification(_currentJob!);
        },
      );

      // Processing completed successfully
      if (mounted) {
        // Get the completed job to find the recipe ID
        final completedJob = await _processingService.getJob(_jobId!);
        if (completedJob?.recipeId != null) {
          // Fetch the recipe from database
          final recipe =
              await _databaseService.getRecipe(completedJob!.recipeId!);
          if (recipe != null && mounted) {
            // Navigate to recipe detail screen
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => RecipeDetailScreen(
                  recipe: recipe,
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Processing failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Processing Recipe'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Progress indicator
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: _currentJob?.progress ?? 0.0,
                  strokeWidth: 8,
                ),
              ),
              const SizedBox(height: 32),

              // Progress percentage
              Text(
                '${((_currentJob?.progress ?? 0.0) * 100).toInt()}%',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              // Current step
              Text(
                _currentJob?.currentStep ?? 'Initializing...',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Status message
              if (_currentJob?.status == ProcessingStatus.analyzingDescription)
                _buildStatusMessage(
                  Icons.description,
                  'Analyzing Description',
                  'Checking for recipe in video description...',
                ),
              if (_currentJob?.status == ProcessingStatus.transcribing)
                _buildStatusMessage(
                  Icons.mic,
                  'Transcribing Audio',
                  'Converting speech to text...',
                ),
              if (_currentJob?.status == ProcessingStatus.extractingText)
                _buildStatusMessage(
                  Icons.image_search,
                  'Extracting Text',
                  'Reading on-screen text...',
                ),
              if (_currentJob?.status == ProcessingStatus.aiExtracting)
                _buildStatusMessage(
                  Icons.auto_awesome,
                  'AI Extraction',
                  'Using AI to identify recipe...',
                ),
              if (_currentJob?.status == ProcessingStatus.parsing)
                _buildStatusMessage(
                  Icons.restaurant_menu,
                  'Creating Recipe',
                  'Organizing ingredients and directions...',
                ),

              const SizedBox(height: 48),

              // Info message
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isBackgroundProcessing
                            ? 'Processing continues in the background. You\'ll be notified when it\'s done.'
                            : 'This may take a few minutes. You can leave this screen and we\'ll notify you when it\'s done.',
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Background processing button (Android only)
              if (_backgroundAvailable && !_isBackgroundProcessing) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _moveToBackground,
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('Continue in Background'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],

              // Background processing indicator
              if (_isBackgroundProcessing) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Running in background',
                        style: TextStyle(
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _moveToBackground() async {
    await _switchToBackgroundProcessing();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Processing moved to background'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back to home screen
      Navigator.of(context).pop();
    }
  }

  Widget _buildStatusMessage(IconData icon, String title, String subtitle) {
    return Column(
      children: [
        Icon(icon, size: 48, color: Theme.of(context).primaryColor),
        const SizedBox(height: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
