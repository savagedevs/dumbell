import '../../data/models.dart';
import '../../data/exercise_performance.dart';

/// Display-only cache. The saved workout remains the source of truth.
class LiveWorkoutSnapshot {
  const LiveWorkoutSnapshot({
    required this.active,
    this.workoutId,
    this.workoutName,
    this.startedAtMs,
    this.exerciseName,
    this.exerciseAsset,
    this.completedSets = 0,
    this.totalSets = 0,
  });

  factory LiveWorkoutSnapshot.fromWorkout(
    WorkoutSession? workout, {
    WorkoutExercise? exercise,
    bool live = true,
  }) => LiveWorkoutSnapshot(
    active: workout != null && live,
    workoutId: workout?.id,
    workoutName: workout?.name,
    startedAtMs: workout?.startedAt.millisecondsSinceEpoch,
    exerciseName: exercise?.name,
    exerciseAsset: exercise == null
        ? null
        : definitionForExercise(
            exercise.exerciseId,
            name: exercise.name,
          )?.illustrations.firstOrNull?.asset,
    completedSets: workout?.completedSets ?? 0,
    totalSets:
        workout?.exercises.fold<int>(0, (total, e) => total + e.sets.length) ??
        0,
  );

  final bool active;
  final String? workoutId;
  final String? workoutName;
  final int? startedAtMs;
  final String? exerciseName;
  final String? exerciseAsset;
  final int completedSets;
  final int totalSets;

  Map<String, Object?> toMap() => {
    'active': active,
    'workoutId': workoutId,
    'workoutName': workoutName,
    'startedAtMs': startedAtMs,
    'exerciseName': exerciseName,
    'exerciseAsset': exerciseAsset,
    'completedSets': completedSets,
    'totalSets': totalSets,
  };
}
