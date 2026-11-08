import 'exercise_catalog.dart';
import 'models.dart';

/// The movement identity used by progress and previous-session comparisons.
///
/// Saved IDs remain authoritative. Only IDs created during CSV recovery may
/// use exact known names to recover the movement that lost its original ID.
String exerciseKey(String exerciseId, {String? name}) {
  final original = _originalExerciseIds[exerciseId];
  if (original != null) return original;
  if (exerciseId.startsWith('csv-recovered-') && name != null) {
    final exactName = name.toLowerCase();
    return _originalExerciseNames[exactName] ??
        _catalogueByName[exactName]?.id ??
        exerciseId;
  }
  return exerciseId;
}

ExerciseDefinition? definitionForExercise(String exerciseId, {String? name}) =>
    _catalogueById[exerciseKey(exerciseId, name: name)];

/// A snapshot derived exclusively from finished sessions and completed sets.
///
/// Recreate this object when history changes; it never changes saved records or
/// caches values independently of the supplied history.
class ExercisePerformance {
  ExercisePerformance(Iterable<WorkoutSession> history)
    : _exercises = _deriveTrends(history);

  final List<ExerciseTrend> _exercises;
  late final Map<String, ExerciseTrend> _byKey = {
    for (final exercise in _exercises) exercise.key: exercise,
  };

  List<ExerciseTrend> get exercises => _exercises;

  /// Chronological performance points, optionally strictly before [before].
  List<ExerciseSessionPerformance> sessionsFor(
    String exerciseId, {
    String? name,
    DateTime? before,
    String? excludingWorkoutId,
  }) {
    final sessions =
        _byKey[exerciseKey(exerciseId, name: name)]?.sessions ??
        const <ExerciseSessionPerformance>[];
    if (before == null && excludingWorkoutId == null) return sessions;
    return List.unmodifiable(
      sessions.where(
        (session) =>
            (before == null || session.startedAt.isBefore(before)) &&
            session.workoutId != excludingWorkoutId,
      ),
    );
  }

  ExerciseSessionPerformance? previousFor(
    WorkoutSession current,
    WorkoutExercise exercise,
  ) {
    final sessions = sessionsFor(
      exercise.exerciseId,
      name: exercise.name,
      before: current.startedAt,
      excludingWorkoutId: current.id,
    );
    return sessions.isEmpty ? null : sessions.last;
  }
}

class ExerciseTrend {
  ExerciseTrend._({
    required this.key,
    required this.name,
    required Iterable<ExerciseSessionPerformance> sessions,
  }) : sessions = List.unmodifiable(sessions);

  final String key;
  final String name;
  final List<ExerciseSessionPerformance> sessions;

  double get bestWeightKg => sessions.fold(
    0.0,
    (best, session) => session.topWeightKg > best ? session.topWeightKg : best,
  );
}

class ExerciseSessionPerformance {
  ExerciseSessionPerformance._({
    required this.workoutId,
    required this.workoutName,
    required this.exerciseKey,
    required this.exerciseName,
    required this.startedAt,
    required Iterable<WorkoutSet> sets,
  }) : sets = List.unmodifiable(sets);

  final String workoutId;
  final String workoutName;
  final String exerciseKey;
  final String exerciseName;
  final DateTime startedAt;
  final List<WorkoutSet> sets;

  double get topWeightKg =>
      sets.fold(0.0, (best, set) => set.weightKg > best ? set.weightKg : best);

  double get volumeKg =>
      sets.fold(0.0, (total, set) => total + set.weightKg * set.reps);

  int get reps => sets.fold(0, (total, set) => total + set.reps);

  int get completedSets => sets.length;
}

List<ExerciseTrend> _deriveTrends(Iterable<WorkoutSession> history) {
  final workouts =
      history.where((workout) => workout.finishedAt != null).toList()
        ..sort((a, b) {
          final dateOrder = a.startedAt.compareTo(b.startedAt);
          return dateOrder != 0 ? dateOrder : a.id.compareTo(b.id);
        });
  final names = <String, String>{};
  final sessionsByKey = <String, List<ExerciseSessionPerformance>>{};

  for (final workout in workouts) {
    final setsByKey = <String, List<WorkoutSet>>{};
    for (final exercise in workout.exercises) {
      final completed = exercise.sets.where((set) => set.isCompleted).toList();
      if (completed.isEmpty) continue;

      final key = exerciseKey(exercise.exerciseId, name: exercise.name);
      names.putIfAbsent(
        key,
        () =>
            definitionForExercise(
              exercise.exerciseId,
              name: exercise.name,
            )?.name ??
            exercise.name,
      );
      setsByKey.putIfAbsent(key, () => []).addAll(completed);
    }

    for (final entry in setsByKey.entries) {
      sessionsByKey
          .putIfAbsent(entry.key, () => [])
          .add(
            ExerciseSessionPerformance._(
              workoutId: workout.id,
              workoutName: workout.name,
              exerciseKey: entry.key,
              exerciseName: names[entry.key]!,
              startedAt: workout.startedAt,
              sets: entry.value,
            ),
          );
    }
  }

  final trends =
      [
        for (final entry in sessionsByKey.entries)
          ExerciseTrend._(
            key: entry.key,
            name: names[entry.key]!,
            sessions: entry.value,
          ),
      ]..sort((a, b) {
        final nameOrder = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return nameOrder != 0 ? nameOrder : a.key.compareTo(b.key);
      });
  return List.unmodifiable(trends);
}

final _catalogueById = {
  for (final exercise in exerciseCatalog) exercise.id: exercise,
};

final _catalogueByName = {
  for (final exercise in exerciseCatalog) exercise.name.toLowerCase(): exercise,
};

// Verified against the exact movement/equipment in the bundled RepDB release.
const _originalExerciseIds = {
  'squat': 'repdb_squat',
  'bench_press': 'repdb_bench-press',
  'deadlift': 'repdb_deadlift',
  'overhead_press': 'repdb_ohp',
  'barbell_row': 'repdb_barbell-row',
  'romanian_deadlift': 'repdb_romanian-deadlift',
  'dumbbell_bench_press': 'repdb_db-bench-press',
  'dumbbell_row': 'repdb_single-arm-db-row',
  'lateral_raise': 'repdb_lateral-raise',
  'biceps_curl': 'repdb_bicep-curl',
  'triceps_pushdown': 'repdb_tricep-pushdown',
  'lat_pulldown': 'repdb_lat-pulldown',
  'seated_cable_row': 'repdb_seated-cable-row',
  'leg_press': 'repdb_leg-press',
  'goblet_squat': 'repdb_db-goblet-squat',
  'push_up': 'repdb_push-up',
  'reverse_lunge': 'repdb_reverse-lunge',
  'calf_raise': 'repdb_dumbbell-calf-raise',
};

// Original display names are considered only for CSV-recovered IDs. In
// particular the old Goblet Squat and Standing Calf Raise used dumbbells.
const _originalExerciseNames = {
  'barbell squat': 'repdb_squat',
  'bench press': 'repdb_bench-press',
  'deadlift': 'repdb_deadlift',
  'overhead press': 'repdb_ohp',
  'barbell row': 'repdb_barbell-row',
  'romanian deadlift': 'repdb_romanian-deadlift',
  'dumbbell bench press': 'repdb_db-bench-press',
  'dumbbell row': 'repdb_single-arm-db-row',
  'lateral raise': 'repdb_lateral-raise',
  'biceps curl': 'repdb_bicep-curl',
  'triceps pushdown': 'repdb_tricep-pushdown',
  'lat pulldown': 'repdb_lat-pulldown',
  'seated cable row': 'repdb_seated-cable-row',
  'leg press': 'repdb_leg-press',
  'goblet squat': 'repdb_db-goblet-squat',
  'push-up': 'repdb_push-up',
  'reverse lunge': 'repdb_reverse-lunge',
  'standing calf raise': 'repdb_dumbbell-calf-raise',
};
