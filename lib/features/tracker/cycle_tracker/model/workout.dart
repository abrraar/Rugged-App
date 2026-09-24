

import 'package:uuid/uuid.dart';
import 'exercise.dart';

enum WorkoutStatus { pending, completed }

class Workout {
  final String id;
  final String cycleId;
  final String name;
  final int order;
  final WorkoutStatus status;
  final DateTime? completedAt;
  final String? note;
  final List<Exercise> exercises;
  final int isSynced;
  final DateTime? updatedAt;
  final String? userId;

  Workout({
    String? id,
    required this.cycleId,
    required this.name,
    required this.order,
    this.status = WorkoutStatus.pending,
    this.completedAt,
    this.note,
    this.exercises = const [],
    this.isSynced = 1,
    this.updatedAt,
    this.userId,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'cycle_id': cycleId,
      'name': name,
      'workout_order': order,
      'status': status.name,
      'completed_at': completedAt?.toIso8601String(),
      'note': note,
      'is_synced': isSynced,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Workout.fromMap(Map<String, dynamic> map, [List<Exercise> exercises = const []]) {
    return Workout(
      id: map['id']?.toString() ?? const Uuid().v4(),
      userId: map['user_id']?.toString(),
      cycleId: map['cycle_id']?.toString() ?? "",
      name: map['name']?.toString() ?? "Untitled Workout",
      order: (map['workout_order'] as num?)?.toInt() ?? 0,
      status: WorkoutStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => WorkoutStatus.pending,
      ),
      completedAt: map['completed_at'] != null ? DateTime.tryParse(map['completed_at'].toString()) : null,
      note: map['note']?.toString(),
      exercises: exercises,
      isSynced: (map['is_synced'] as num?)?.toInt() ?? 1,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory Workout.fromJson(Map<String, dynamic> json) => Workout.fromMap(json);

  Workout copyWith({
    String? id,
    String? cycleId,
    String? name,
    int? order,
    WorkoutStatus? status,
    DateTime? Function()? completedAt,
    String? note,
    List<Exercise>? exercises,
    int? isSynced,
    DateTime? updatedAt,
    String? userId,
  }) {
    return Workout(
      id: id ?? this.id,
      cycleId: cycleId ?? this.cycleId,
      name: name ?? this.name,
      order: order ?? this.order,
      status: status ?? this.status,
      completedAt: completedAt != null ? completedAt() : this.completedAt,
      note: note ?? this.note,
      exercises: exercises ?? this.exercises,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
    );
  }
}

