import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/app/workout_controller.dart';
import 'package:workout_app/data/models.dart';
import 'package:workout_app/features/exercise_progress/exercise_progress_controller.dart';

import '../support/memory_repository.dart';

WorkoutSession session(String id, DateTime date, double kg, int reps) =>
    WorkoutSession(
      id: id,
      name: 'Strength',
      startedAt: date,
      finishedAt: date.add(const Duration(minutes: 30)),
      exercises: [
        WorkoutExercise(
          id: '$id-entry',
          exerciseId: 'repdb_squat',
          name: 'Barbell Back Squat',
          sets: [
            WorkoutSet(
              id: '$id-set',
              weightKg: kg,
              reps: reps,
              isCompleted: true,
            ),
          ],
        ),
      ],
    );
void main() {
  test('exercise metrics keep canonical values while formatting the selected units', () async {
    final repository = MemoryRepository()
      ..value = AppData(
        history: [session('one', DateTime(2026, 11, 1), 40, 8)],
      );
    final workouts = WorkoutController(repository, repository.value);
    final controller = ExerciseProgressController(
      workouts,
      const ExerciseProgressArguments(
        exerciseId: 'repdb_squat',
        name: 'Barbell Back Squat',
      ),
    );
    final point = controller.sessions.single;
    expect(controller.valueOf(point), 40);
    controller.metric.value = ExerciseChartMetric.volume;
    expect(controller.valueOf(point), 320);
    expect(controller.axisLabel, 'kg × reps');
    await workouts.setUnit(WeightUnit.lb);
    expect(controller.valueOf(controller.sessions.single), 320);
    expect(controller.formatValue(40), '88.2');
    controller.metric.value = ExerciseChartMetric.reps;
    expect(controller.valueOf(point), 8);
    expect(controller.formatValue(8), '8');
  });
  test(
    'range and deleted selections resolve only to available points',
    () async {
      final repository = MemoryRepository()
        ..value = AppData(
          history: [
            session('old', DateTime(2026, 6, 1), 30, 8),
            session('new', DateTime(2026, 11, 1), 40, 8),
          ],
        );
      final workouts = WorkoutController(repository, repository.value);
      final controller = ExerciseProgressController(
        workouts,
        const ExerciseProgressArguments(
          exerciseId: 'repdb_squat',
          name: 'Barbell Back Squat',
        ),
        clock: () => DateTime(2026, 11, 8),
      );
      controller.selectedWorkoutId.value = 'old';
      expect(controller.selected!.workoutId, 'old');
      controller.range.value = ExerciseChartRange.month;
      expect(controller.sessions.map((s) => s.workoutId), ['new']);
      expect(controller.selected!.workoutId, 'new');
      await workouts.deleteWorkout('new');
      expect(controller.sessions, isEmpty);
      expect(controller.selected, isNull);
    },
  );
}
