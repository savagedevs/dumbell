import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workout_app/app/workout_controller.dart';
import 'package:workout_app/core/formatters.dart';
import 'package:workout_app/data/exercise_catalog.dart';
import 'package:workout_app/data/models.dart';

import '../support/memory_repository.dart';

void main() {
  late MemoryRepository repository;
  late WorkoutController controller;
  var clock = DateTime(2026, 11, 8, 9);
  setUp(() {
    Get.testMode = true;
    repository = MemoryRepository();
    controller = WorkoutController(repository, AppData(), clock: () => clock);
  });
  tearDown(() async => Get.reset());

  Future<void> addCompletedSet() async {
    expect(await controller.startWorkout(), isTrue);
    expect(await controller.addExercise(exerciseCatalog.first.id), isTrue);
    final workout = controller.activeWorkout!;
    final exercise = workout.exercises.first;
    expect(
      await controller.updateSet(
        workout.id,
        exercise.id,
        exercise.sets.first.id,
        reps: 10,
        weight: 50,
        completed: true,
      ),
      isTrue,
    );
  }

  test(
    'draft survives reload and timer uses original start timestamp',
    () async {
      await addCompletedSet();
      final started = controller.activeWorkout!.startedAt;
      clock = clock.add(const Duration(minutes: 23));
      final resumed = WorkoutController(
        repository,
        await repository.load(),
        clock: () => clock,
      );
      expect(
        resumed.activeWorkout!.startedAt.isAtSameMomentAs(started),
        isTrue,
      );
      expect(clock.difference(resumed.activeWorkout!.startedAt).inMinutes, 23);
      expect(resumed.activeWorkout!.completedSets, 1);
    },
  );

  test('queued edits preserve both changes and save history once', () async {
    await addCompletedSet();
    final workout = controller.activeWorkout!;
    final exercise = workout.exercises.first;
    final results = await Future.wait([
      controller.addSet(workout.id, exercise.id),
      controller.renameWorkout(workout.id, 'Leg day'),
    ]);
    expect(results, everyElement(isTrue));
    expect(controller.activeWorkout!.exercises.first.sets.length, 2);
    expect(controller.activeWorkout!.name, 'Leg day');
    final finishes = await Future.wait([
      controller.finishWorkout(),
      controller.finishWorkout(),
    ]);
    expect(finishes, [true, false]);
    expect(controller.history.length, 1);
    expect(controller.activeWorkout, isNull);
  });

  test('failed writes preserve state and following retry succeeds', () async {
    await addCompletedSet();
    final before = controller.data.value;
    repository.failWrites = true;
    expect(await controller.finishWorkout(), isFalse);
    expect(identical(controller.data.value, before), isTrue);
    expect(controller.isSaving.value, isFalse);
    expect(controller.error.value, isNotEmpty);
    repository.failWrites = false;
    expect(await controller.finishWorkout(), isTrue);
    expect(controller.error.value, isEmpty);
  });

  test(
    'unit switch preserves canonical weight and converts new entries',
    () async {
      await addCompletedSet();
      await controller.setUnit(WeightUnit.lb);
      expect(controller.activeWorkout!.exercises.first.sets.first.weightKg, 50);
      final workout = controller.activeWorkout!;
      final exercise = workout.exercises.first;
      await controller.updateSet(
        workout.id,
        exercise.id,
        exercise.sets.first.id,
        reps: 10,
        weight: 50 * poundsPerKg,
        completed: true,
      );
      expect(
        controller.activeWorkout!.exercises.first.sets.first.weightKg,
        closeTo(50, .00001),
      );
      await controller.addBodyWeight(80 * poundsPerKg);
      expect(controller.bodyWeights.single.weightKg, closeTo(80, .00001));
    },
  );

  test('invalid inputs and empty workouts do not save', () async {
    await controller.startWorkout();
    expect(await controller.finishWorkout(), isFalse);
    await controller.addExercise(exerciseCatalog.first.id);
    final workout = controller.activeWorkout!;
    final exercise = workout.exercises.first;
    final writes = repository.writes;
    for (final value in [-1.0, double.nan, double.infinity]) {
      expect(
        await controller.updateSet(
          workout.id,
          exercise.id,
          exercise.sets.first.id,
          reps: 8,
          weight: value,
          completed: true,
        ),
        isFalse,
      );
    }
    expect(
      await controller.updateSet(
        workout.id,
        exercise.id,
        exercise.sets.first.id,
        reps: 0,
        weight: 0,
        completed: true,
      ),
      isFalse,
    );
    expect(await controller.addBodyWeight(0), isFalse);
    expect(repository.writes, writes);
  });

  test('editing saved history keeps active draft intact', () async {
    await addCompletedSet();
    final savedId = controller.activeWorkout!.id;
    await controller.finishWorkout();
    await controller.startWorkout();
    final draftId = controller.activeWorkout!.id;
    await controller.renameWorkout(savedId, 'Saved session');
    expect(controller.sessionById(savedId)!.name, 'Saved session');
    expect(controller.activeWorkout!.id, draftId);
    await controller.deleteWorkout(savedId);
    expect(controller.history, isEmpty);
    expect(controller.activeWorkout!.id, draftId);
  });
}
