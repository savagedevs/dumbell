import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workout_app/app/workout_controller.dart';
import 'package:workout_app/data/models.dart';

import '../support/exercise_prefill_fixture.dart';
import '../support/memory_repository.dart';

void main() {
  setUp(() => Get.testMode = true);
  tearDown(() => Get.reset());
  test(
    'new movement copies earlier completed sets once and leaves them unchecked',
    () async {
      final repository = MemoryRepository()..value = exercisePrefillFixture();
      final controller = WorkoutController(repository, repository.value);
      final history = controller.history
          .map((workout) => workout.toJson())
          .toList();
      expect(await controller.addExercise('repdb_squat'), isTrue);
      final exercise = controller.activeWorkout!.exercises.single;
      expect(exercise.sets.map((set) => set.weightKg), [40.125, 45.5]);
      expect(exercise.sets.map((set) => set.reps), [10, 6]);
      expect(exercise.sets.every((set) => !set.isCompleted), isTrue);
      expect(exercise.sets.map((set) => set.id).toSet(), hasLength(2));
      expect(
        exercise.sets.any((set) => set.id.startsWith('previous-')),
        isFalse,
      );
      expect(controller.activeWorkout!.completedSets, 0);
      expect(controller.activeWorkout!.volumeKg, 0);
      expect(await controller.finishWorkout(), isFalse);
      expect(
        controller.history.map((workout) => workout.toJson()).toList(),
        history,
      );

      final set = exercise.sets.first;
      expect(
        await controller.updateSet(
          'current',
          exercise.id,
          set.id,
          reps: 9,
          weight: 42.75,
          completed: false,
        ),
        isTrue,
      );
      final restored = WorkoutController(repository, await repository.load());
      expect(
        restored.activeWorkout!.exercises.single.sets.first.weightKg,
        42.75,
      );
      expect(restored.activeWorkout!.exercises.single.sets.first.reps, 9);
      await restored.setUnit(WeightUnit.lb);
      expect(
        restored.activeWorkout!.exercises.single.sets.first.weightKg,
        42.75,
      );
    },
  );

  test(
    'lb preferences do not convert canonical values while prefilling',
    () async {
      final repository = MemoryRepository()
        ..value = exercisePrefillFixture(unit: WeightUnit.lb);
      final controller = WorkoutController(repository, repository.value);
      expect(await controller.addExercise('repdb_squat'), isTrue);
      final exercise = controller.activeWorkout!.exercises.single;
      expect(exercise.sets.map((set) => set.weightKg), [40.125, 45.5]);
      await controller.addSet('current', exercise.id);
      expect(
        controller.activeWorkout!.exercises.single.sets.last.weightKg,
        45.5,
      );
      expect(controller.activeWorkout!.exercises.single.sets.last.reps, 6);
    },
  );

  test('unrelated movements retain the empty starter set', () async {
    final repository = MemoryRepository()..value = exercisePrefillFixture();
    final controller = WorkoutController(repository, repository.value);
    expect(await controller.addExercise('repdb_bench-press'), isTrue);
    final set = controller.activeWorkout!.exercises.single.sets.single;
    expect(set.weightKg, 0);
    expect(set.reps, 8);
    expect(set.isCompleted, isFalse);
  });

  test(
    'failed prefill is atomic and retry preserves the source workout',
    () async {
      final repository = MemoryRepository()
        ..value = exercisePrefillFixture()
        ..failWrites = true;
      final controller = WorkoutController(repository, repository.value);
      final original = controller.data.value.toJson();
      expect(await controller.addExercise('repdb_squat'), isFalse);
      expect(controller.data.value.toJson(), original);
      expect(controller.currentExercise, isNull);
      repository.failWrites = false;
      expect(await controller.addExercise('repdb_squat'), isTrue);
      expect(
        controller.activeWorkout!.exercises.single.sets.map((set) => set.reps),
        [10, 6],
      );
    },
  );
}
