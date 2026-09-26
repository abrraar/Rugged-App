class AffirmationSettings {
  final int rotationMinutes;
  final String rotationMode; // 'random', 'continuous'
  final String orderDirection; // 'asc', 'desc'
  final int isSynced;
  final DateTime? updatedAt;
  final String? userId;

  AffirmationSettings({
    this.rotationMinutes = 60,
    this.rotationMode = 'random',
    this.orderDirection = 'asc',
    this.isSynced = 0,
    this.updatedAt,
    this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'rotation_minutes': rotationMinutes,
      'rotation_mode': rotationMode,
      'order_direction': orderDirection,
      'is_synced': isSynced,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory AffirmationSettings.fromMap(Map<String, dynamic> map) {
    return AffirmationSettings(
      rotationMinutes: map['rotation_minutes'] as int? ?? 60,
      rotationMode: map['rotation_mode'] as String? ?? 'random',
      orderDirection: map['order_direction'] as String? ?? 'asc',
      isSynced: (map['is_synced'] as num?)?.toInt() ?? 1,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
      userId: map['user_id'] as String?,
    );
  }

  AffirmationSettings copyWith({
    int? rotationMinutes,
    String? rotationMode,
    String? orderDirection,
    int? isSynced,
    DateTime? updatedAt,
    String? userId,
  }) {
    return AffirmationSettings(
      rotationMinutes: rotationMinutes ?? this.rotationMinutes,
      rotationMode: rotationMode ?? this.rotationMode,
      orderDirection: orderDirection ?? this.orderDirection,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
    );
  }
}


