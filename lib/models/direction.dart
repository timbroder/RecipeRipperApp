class Direction {
  final String? id;
  final String? recipeId;
  final int stepNumber;
  final String text;

  Direction({
    this.id,
    this.recipeId,
    required this.stepNumber,
    required this.text,
  });

  Direction copyWith({
    String? id,
    String? recipeId,
    int? stepNumber,
    String? text,
  }) {
    return Direction(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      stepNumber: stepNumber ?? this.stepNumber,
      text: text ?? this.text,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recipe_id': recipeId,
      'step_number': stepNumber,
      'text': text,
    };
  }

  factory Direction.fromMap(Map<String, dynamic> map) {
    return Direction(
      id: map['id'] as String?,
      recipeId: map['recipe_id'] as String?,
      stepNumber: map['step_number'] as int,
      text: map['text'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipeId': recipeId,
      'stepNumber': stepNumber,
      'text': text,
    };
  }

  factory Direction.fromJson(Map<String, dynamic> json) {
    return Direction(
      id: json['id'] as String?,
      recipeId: json['recipeId'] as String?,
      stepNumber: json['stepNumber'] as int,
      text: json['text'] as String,
    );
  }

  String toDisplayString() {
    return '$stepNumber. $text';
  }

  @override
  String toString() => toDisplayString();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Direction &&
        other.id == id &&
        other.recipeId == recipeId &&
        other.stepNumber == stepNumber &&
        other.text == text;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      recipeId,
      stepNumber,
      text,
    );
  }
}
