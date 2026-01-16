enum ProcessingStatus {
  queued,
  downloading,
  transcribing,
  extractingText,
  parsing,
  completed,
  failed,
  cancelled,
}

class ProcessingJob {
  final String id;
  final String? sourceUrl;
  final String? localVideoPath;
  final ProcessingStatus status;
  final double progress;
  final String? currentStep;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? recipeId;

  ProcessingJob({
    required this.id,
    this.sourceUrl,
    this.localVideoPath,
    this.status = ProcessingStatus.queued,
    this.progress = 0.0,
    this.currentStep,
    this.errorMessage,
    DateTime? createdAt,
    this.startedAt,
    this.completedAt,
    this.recipeId,
  }) : createdAt = createdAt ?? DateTime.now();

  ProcessingJob copyWith({
    String? id,
    String? sourceUrl,
    String? localVideoPath,
    ProcessingStatus? status,
    double? progress,
    String? currentStep,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? recipeId,
  }) {
    return ProcessingJob(
      id: id ?? this.id,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      localVideoPath: localVideoPath ?? this.localVideoPath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      currentStep: currentStep ?? this.currentStep,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      recipeId: recipeId ?? this.recipeId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source_url': sourceUrl,
      'local_video_path': localVideoPath,
      'status': status.name,
      'progress': progress,
      'current_step': currentStep,
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'recipe_id': recipeId,
    };
  }

  factory ProcessingJob.fromMap(Map<String, dynamic> map) {
    return ProcessingJob(
      id: map['id'] as String,
      sourceUrl: map['source_url'] as String?,
      localVideoPath: map['local_video_path'] as String?,
      status: ProcessingStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => ProcessingStatus.queued,
      ),
      progress: map['progress'] as double? ?? 0.0,
      currentStep: map['current_step'] as String?,
      errorMessage: map['error_message'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      startedAt: map['started_at'] != null
          ? DateTime.parse(map['started_at'] as String)
          : null,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      recipeId: map['recipe_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sourceUrl': sourceUrl,
      'localVideoPath': localVideoPath,
      'status': status.name,
      'progress': progress,
      'currentStep': currentStep,
      'errorMessage': errorMessage,
      'createdAt': createdAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'recipeId': recipeId,
    };
  }

  factory ProcessingJob.fromJson(Map<String, dynamic> json) {
    return ProcessingJob(
      id: json['id'] as String,
      sourceUrl: json['sourceUrl'] as String?,
      localVideoPath: json['localVideoPath'] as String?,
      status: ProcessingStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => ProcessingStatus.queued,
      ),
      progress: json['progress'] as double? ?? 0.0,
      currentStep: json['currentStep'] as String?,
      errorMessage: json['errorMessage'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      recipeId: json['recipeId'] as String?,
    );
  }

  bool get isActive =>
      status == ProcessingStatus.downloading ||
      status == ProcessingStatus.transcribing ||
      status == ProcessingStatus.extractingText ||
      status == ProcessingStatus.parsing;

  bool get isFinished =>
      status == ProcessingStatus.completed ||
      status == ProcessingStatus.failed ||
      status == ProcessingStatus.cancelled;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ProcessingJob && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
