class UserProfile {
  final String id;
  final String? userId;
  final String? fullName;
  final String? username;
  final DateTime? birthday;
  final String? gender;
  final double? height;
  final double? weight;
  final bool isPro;
  final String? proPlanTier;
  final DateTime? proStartDate;
  final DateTime? proExpiryDate;
  final int isSynced;
  final DateTime? updatedAt;

  UserProfile({
    required this.id,
    this.userId,
    this.fullName,
    this.username,
    this.birthday,
    this.gender,
    this.height,
    this.weight,
    this.isPro = false,
    this.proPlanTier,
    this.proStartDate,
    this.proExpiryDate,
    this.isSynced = 1,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'full_name': fullName,
      'username': username,
      'birthday': birthday?.toIso8601String(),
      'gender': gender,
      'height': height,
      'weight': weight,
      'is_pro': isPro ? 1 : 0,
      'pro_plan_tier': proPlanTier,
      'pro_start_date': proStartDate?.toIso8601String(),
      'pro_expiry_date': proExpiryDate?.toIso8601String(),
      'is_synced': isSynced,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'],
      userId: map['user_id'],
      fullName: map['full_name'],
      username: map['username'],
      birthday: map['birthday'] != null ? DateTime.tryParse(map['birthday'].toString()) : null,
      gender: map['gender'],
      height: (map['height'] as num?)?.toDouble(),
      weight: (map['weight'] as num?)?.toDouble(),
      isPro: map['is_pro'] == 1 || map['is_pro'] == true || map['is_pro'] == 'true' || map['is_pro'] == '1',
      proPlanTier: map['pro_plan_tier']?.toString(),
      proStartDate: map['pro_start_date'] != null ? DateTime.tryParse(map['pro_start_date'].toString()) : null,
      proExpiryDate: map['pro_expiry_date'] != null ? DateTime.tryParse(map['pro_expiry_date'].toString()) : null,
      isSynced: map['is_synced'] ?? 1,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  UserProfile copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? username,
    DateTime? birthday,
    String? gender,
    double? height,
    double? weight,
    bool? isPro,
    String? proPlanTier,
    DateTime? proStartDate,
    DateTime? proExpiryDate,
    int? isSynced,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      birthday: birthday ?? this.birthday,
      gender: gender ?? this.gender,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      isPro: isPro ?? this.isPro,
      proPlanTier: proPlanTier ?? this.proPlanTier,
      proStartDate: proStartDate ?? this.proStartDate,
      proExpiryDate: proExpiryDate ?? this.proExpiryDate,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

