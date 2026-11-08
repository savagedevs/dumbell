import 'package:get/get.dart';

import '../../app/workout_controller.dart';
import '../../core/formatters.dart';
import '../../data/exercise_performance.dart';
import '../../data/models.dart';

enum ExerciseChartMetric { topWeight, volume, reps }

enum ExerciseChartRange { month, quarter, all }

class ExerciseProgressArguments {
  const ExerciseProgressArguments({
    required this.exerciseId,
    required this.name,
  });
  final String exerciseId;
  final String name;
}

class ExerciseProgressController extends GetxController {
  ExerciseProgressController(
    this.workouts,
    this.exercise, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final WorkoutController workouts;
  final ExerciseProgressArguments exercise;
  final DateTime Function() _clock;
  final metric = ExerciseChartMetric.topWeight.obs;
  final range = ExerciseChartRange.all.obs;
  final selectedWorkoutId = RxnString();

  WeightUnit get unit => workouts.unit;
  List<ExerciseSessionPerformance> get allSessions =>
      ExercisePerformance(workouts.history)
          .sessionsFor(exercise.exerciseId, name: exercise.name);

  List<ExerciseSessionPerformance> get sessions {
    final all = allSessions;
    if (range.value == ExerciseChartRange.all) return all;
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(
      Duration(days: range.value == ExerciseChartRange.month ? 28 : 84),
    );
    return all
        .where((session) => !session.startedAt.toLocal().isBefore(start))
        .toList(growable: false);
  }

  ExerciseSessionPerformance? get selected {
    final visible = sessions;
    for (final session in visible) {
      if (session.workoutId == selectedWorkoutId.value) return session;
    }
    return visible.isEmpty ? null : visible.last;
  }

  String get metricLabel => switch (metric.value) {
    ExerciseChartMetric.topWeight => 'Top weight',
    ExerciseChartMetric.volume => 'Volume',
    ExerciseChartMetric.reps => 'Reps',
  };

  String get axisLabel => switch (metric.value) {
    ExerciseChartMetric.topWeight => unit.label,
    ExerciseChartMetric.volume => '${unit.label} × reps',
    ExerciseChartMetric.reps => 'reps',
  };

  double valueOf(ExerciseSessionPerformance session) => switch (metric.value) {
    ExerciseChartMetric.topWeight => session.topWeightKg,
    ExerciseChartMetric.volume => session.volumeKg,
    ExerciseChartMetric.reps => session.reps.toDouble(),
  };

  String formatValue(double value) => metric.value == ExerciseChartMetric.reps
      ? value.round().toString()
      : formatWeight(value, unit);
}
