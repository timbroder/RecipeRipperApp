class Ingredient {
  final String? id;
  final String? recipeId;
  final double? quantity;
  final String? unit;
  final String item;
  final String? notes;
  final int order;

  Ingredient({
    this.id,
    this.recipeId,
    this.quantity,
    this.unit,
    required this.item,
    this.notes,
    this.order = 0,
  });

  Ingredient copyWith({
    String? id,
    String? recipeId,
    double? quantity,
    String? unit,
    String? item,
    String? notes,
    int? order,
  }) {
    return Ingredient(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      item: item ?? this.item,
      notes: notes ?? this.notes,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recipe_id': recipeId,
      'quantity': quantity,
      'unit': unit,
      'item': item,
      'notes': notes,
      'order_index': order,
    };
  }

  factory Ingredient.fromMap(Map<String, dynamic> map) {
    return Ingredient(
      id: map['id'] as String?,
      recipeId: map['recipe_id'] as String?,
      quantity: map['quantity'] as double?,
      unit: map['unit'] as String?,
      item: map['item'] as String,
      notes: map['notes'] as String?,
      order: map['order_index'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipeId': recipeId,
      'quantity': quantity,
      'unit': unit,
      'item': item,
      'notes': notes,
      'order': order,
    };
  }

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: json['id'] as String?,
      recipeId: json['recipeId'] as String?,
      quantity: json['quantity'] as double?,
      unit: json['unit'] as String?,
      item: json['item'] as String,
      notes: json['notes'] as String?,
      order: json['order'] as int? ?? 0,
    );
  }

  String toDisplayString() {
    final buffer = StringBuffer();

    if (quantity != null) {
      // Format quantity nicely
      if (quantity! % 1 == 0) {
        buffer.write(quantity!.toInt());
      } else {
        buffer.write(quantity);
      }
      buffer.write(' ');
    }

    if (unit != null && unit!.isNotEmpty) {
      buffer.write(unit);
      buffer.write(' ');
    }

    buffer.write(item);

    if (notes != null && notes!.isNotEmpty) {
      buffer.write(' (');
      buffer.write(notes);
      buffer.write(')');
    }

    return buffer.toString();
  }

  @override
  String toString() => toDisplayString();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Ingredient &&
        other.id == id &&
        other.recipeId == recipeId &&
        other.quantity == quantity &&
        other.unit == unit &&
        other.item == item &&
        other.notes == notes &&
        other.order == order;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      recipeId,
      quantity,
      unit,
      item,
      notes,
      order,
    );
  }
}
