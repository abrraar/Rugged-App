import 'package:uuid/uuid.dart';

class Affirmation {
  final String id;
  final String text;
  final String? speaker;
  final String? sharedBy;
  final DateTime createdAt;
  final int isSynced;
  final DateTime? updatedAt;
  final String? userId;

  final int displayOrder;

  Affirmation({
    String? id,
    required this.text,
    this.speaker,
    this.sharedBy,
    DateTime? createdAt,
    this.isSynced = 0,
    this.updatedAt,
    this.displayOrder = 0,
    this.userId,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'text': text,
      'speaker': speaker,
      'shared_by': sharedBy,
      'created_at': createdAt.toIso8601String(),
      'is_synced': isSynced,
      'updated_at': updatedAt?.toIso8601String(),
      'display_order': displayOrder,
    };
  }

  factory Affirmation.fromMap(Map<String, dynamic> map) {
    return Affirmation(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      text: map['text'] as String,
      speaker: map['speaker'] as String?,
      sharedBy: map['shared_by'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      isSynced: (map['is_synced'] as num?)?.toInt() ?? 1,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
      displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
    );
  }

  Affirmation copyWith({
    String? id,
    String? text,
    String? speaker,
    String? sharedBy,
    DateTime? createdAt,
    int? isSynced,
    DateTime? updatedAt,
    int? displayOrder,
    String? userId,
  }) {
    return Affirmation(
      id: id ?? this.id,
      text: text ?? this.text,
      speaker: speaker ?? this.speaker,
      sharedBy: sharedBy ?? this.sharedBy,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
      displayOrder: displayOrder ?? this.displayOrder,
      userId: userId ?? this.userId,
    );
  }
}


