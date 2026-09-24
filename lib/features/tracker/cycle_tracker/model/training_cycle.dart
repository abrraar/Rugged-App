
import 'package:uuid/uuid.dart';
import 'workout.dart';

enum CycleStatus { template, active, finished, incomplete }

class TrainingCycle {
  final String id;
  final String name;
  final String description;
  final bool isDefault;
  final CycleStatus status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? note;
  final List<Workout> workouts;
  final String? sharedBy;
  final int isSynced;
  final DateTime? updatedAt;
  final String? userId;

  TrainingCycle({
    String? id,
    required this.name,
    this.description = "",
    this.isDefault = false,
    this.status = CycleStatus.template,
    this.startedAt,
    this.completedAt,
    this.note,
    this.workouts = const [],
    this.sharedBy,
    this.isSynced = 1,
    this.updatedAt,
    this.userId,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'description': description,
      'is_default': isDefault ? 1 : 0,
      'status': status.name,
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'note': note,
      'shared_by': sharedBy,
      'is_synced': isSynced,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory TrainingCycle.fromMap(Map<String, dynamic> map, [List<Workout> workouts = const []]) {
    final isDefaultVal = map['is_default'];
    bool isDefaultBool = false;
    if (isDefaultVal is int) {
      isDefaultBool = isDefaultVal == 1;
    } else if (isDefaultVal is bool) {
      isDefaultBool = isDefaultVal;
    }

    return TrainingCycle(
      id: map['id']?.toString() ?? const Uuid().v4(),
      userId: map['user_id']?.toString(),
      name: map['name']?.toString() ?? "Untitled Cycle",
      description: map['description']?.toString() ?? "",
      isDefault: isDefaultBool,
      status: CycleStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => CycleStatus.template,
      ),
      startedAt: map['started_at'] != null ? DateTime.tryParse(map['started_at'].toString()) : null,
      completedAt: map['completed_at'] != null ? DateTime.tryParse(map['completed_at'].toString()) : null,
      note: map['note']?.toString(),
      workouts: workouts,
      sharedBy: map['shared_by']?.toString(),
      isSynced: (map['is_synced'] as num?)?.toInt() ?? 1,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  bool get isReadyToFinish => workouts.isNotEmpty && workouts.every((w) => w.status == WorkoutStatus.completed);

  TrainingCycle copyWith({
    String? id,
    String? name,
    String? description,
    bool? isDefault,
    CycleStatus? status,
    DateTime? Function()? startedAt,
    DateTime? Function()? completedAt,
    String? note,
    List<Workout>? workouts,
    String? sharedBy,
    int? isSynced,
    DateTime? updatedAt,
    String? userId,
  }) {
    return TrainingCycle(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isDefault: isDefault ?? this.isDefault,
      status: status ?? this.status,
      startedAt: startedAt != null ? startedAt() : this.startedAt,
      completedAt: completedAt != null ? completedAt() : this.completedAt,
      note: note ?? this.note,
      workouts: workouts ?? this.workouts,
      sharedBy: sharedBy ?? this.sharedBy,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
    );
  }
}

