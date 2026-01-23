import 'ingredient.dart';
import 'direction.dart';

class Recipe {
  final String? id;
  final String title;
  final String? sourceUrl;
  final String? sourcePlatform;
  final String? thumbnailPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Ingredient> ingredients;
  final List<Direction> directions;
  final RecipeMetadata? metadata;

  Recipe({
    this.id,
    required this.title,
    this.sourceUrl,
    this.sourcePlatform,
    this.thumbnailPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.ingredients = const [],
    this.directions = const [],
    this.metadata,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Recipe copyWith({
    String? id,
    String? title,
    String? sourceUrl,
    String? sourcePlatform,
    String? thumbnailPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Ingredient>? ingredients,
    List<Direction>? directions,
    RecipeMetadata? metadata,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourcePlatform: sourcePlatform ?? this.sourcePlatform,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ingredients: ingredients ?? this.ingredients,
      directions: directions ?? this.directions,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'source_url': sourceUrl,
      'source_platform': sourcePlatform,
      'thumbnail_path': thumbnailPath,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      id: map['id'] as String?,
      title: map['title'] as String,
      sourceUrl: map['source_url'] as String?,
      sourcePlatform: map['source_platform'] as String?,
      thumbnailPath: map['thumbnail_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'sourceUrl': sourceUrl,
      'sourcePlatform': sourcePlatform,
      'thumbnailPath': thumbnailPath,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'directions': directions.map((d) => d.toJson()).toList(),
      'metadata': metadata?.toJson(),
    };
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as String?,
      title: json['title'] as String,
      sourceUrl: json['sourceUrl'] as String?,
      sourcePlatform: json['sourcePlatform'] as String?,
      thumbnailPath: json['thumbnailPath'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((i) => Ingredient.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      directions: (json['directions'] as List<dynamic>?)
              ?.map((d) => Direction.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      metadata: json['metadata'] != null
          ? RecipeMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
          : null,
    );
  }
}

class RecipeMetadata {
  final String? transcript;
  final String? ocrText;
  final int? processingTimeSeconds;
  final String? videoDuration;
  final int? frameCount;

  RecipeMetadata({
    this.transcript,
    this.ocrText,
    this.processingTimeSeconds,
    this.videoDuration,
    this.frameCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'transcript': transcript,
      'ocr_text': ocrText,
      'processing_time_seconds': processingTimeSeconds,
      'video_duration': videoDuration,
      'frame_count': frameCount,
    };
  }

  factory RecipeMetadata.fromMap(Map<String, dynamic> map) {
    return RecipeMetadata(
      transcript: map['transcript'] as String?,
      ocrText: map['ocr_text'] as String?,
      processingTimeSeconds: map['processing_time_seconds'] as int?,
      videoDuration: map['video_duration'] as String?,
      frameCount: map['frame_count'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transcript': transcript,
      'ocrText': ocrText,
      'processingTimeSeconds': processingTimeSeconds,
      'videoDuration': videoDuration,
      'frameCount': frameCount,
    };
  }

  factory RecipeMetadata.fromJson(Map<String, dynamic> json) {
    return RecipeMetadata(
      transcript: json['transcript'] as String?,
      ocrText: json['ocrText'] as String?,
      processingTimeSeconds: json['processingTimeSeconds'] as int?,
      videoDuration: json['videoDuration'] as String?,
      frameCount: json['frameCount'] as int?,
    );
  }
}
