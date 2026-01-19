import 'package:flutter/material.dart';
import '../models/processing_job.dart';
import '../services/database_service.dart';
import '../services/processing_service.dart';
import '../services/notification_service.dart';
import 'recipe_detail_screen.dart';

/// Screen that shows processing progress for a video
class ProcessingScreen extends StatefulWidget {
  final String videoPath;
  final String? sourceUrl;
  final String? videoTitle;

  const ProcessingScreen({
    super.key,
    required this.videoPath,
    this.sourceUrl,
    this.videoTitle,
  });

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  late ProcessingService _processingService;
  late NotificationService _notificationService;
  String? _jobId;
  ProcessingJob? _currentJob;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _processingService = ProcessingService(
      databaseService: DatabaseService(),
    );
    _notificationService = NotificationService();
    _notificationService.initialize();
    _startProcessing();
  }

  Future<void> _startProcessing() async {
    setState(() {
      _processing = true;
    });

    try {
      // Request permissions if needed
      await _notificationService.requestPermission();

      // Start processing
      _jobId = await _processingService.processVideo(
        widget.videoPath,
        sourceUrl: widget.sourceUrl,
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
          // Navigate to recipe detail screen
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => RecipeDetailScreen(
                  recipeId: completedJob!.recipeId!,
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
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
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
                        'This may take a few minutes. You can leave this screen and we\'ll notify you when it\'s done.',
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
