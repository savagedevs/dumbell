import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workout_app/app/workout_controller.dart';
import 'package:workout_app/data/exercise_catalog.dart';
import 'package:workout_app/data/models.dart';

import '../support/memory_repository.dart';

WorkoutExercise _exercise(String id, {bool completed = false}) =>
    WorkoutExercise(
      id: id,
      exerciseId: 'barbell-bench-press',
      name: 'Exercise $id',
      sets: [
        WorkoutSet(
          id: 'set-$id',
          reps: 8,
          weightKg: 40,
          isCompleted: completed,
        ),
      ],
    );

WorkoutSession _session(
  String id,
  List<WorkoutExercise> exercises, {
  DateTime? startedAt,
  DateTime? finishedAt,
}) => WorkoutSession(
  id: id,
  name: 'Upper body',
  startedAt: startedAt ?? DateTime(2026, 11, 8, 9),
  finishedAt: finishedAt,
  exercises: exercises,
);

class _DelayedRepository extends MemoryRepository {
  Completer<void>? hold;

  @override
  Future<void> save(AppData data) async {
    if (hold != null) await hold!.future;
    await super.save(data);
  }
}

void main() {
  setUp(() => Get.testMode = true);
  tearDown(() async => Get.reset());

  WorkoutController create(MemoryRepository repository, {DateTime? now}) =>
      WorkoutController(
        repository,
        repository.value,
        clock: () => now ?? DateTime(2026, 11, 8, 10),
      );

  test('current exercise falls back to first incomplete, then last', () async {
    final repository = MemoryRepository()
      ..value = AppData(
        activeWorkout: _session('active', [
          _exercise('first', completed: true),
          _exercise('second'),
          _exercise('last'),
        ]),
      );
    final controller = create(repository);
    expect(controller.currentExercise?.id, 'second');
    controller.currentExerciseId.value = 'stale-entry';
    expect(controller.currentExercise?.id, 'second');
    await controller.updateSet(
      'active',
      'second',
      'set-second',
      reps: 8,
      weight: 40,
      completed: true,
    );
    controller.currentExerciseId.value = null;
    expect(controller.currentExercise?.id, 'last');
    await controller.updateSet(
      'active',
      'last',
      'set-last',
      reps: 8,
      weight: 40,
      completed: true,
    );
    controller.currentExerciseId.value = null;
    expect(controller.currentExercise?.id, 'last');
    await controller.removeExercise('active', 'last');
    expect(controller.currentExercise?.id, 'second');
    await controller.removeExercise('active', 'first');
    await controller.removeExercise('active', 'second');
    expect(controller.currentExercise, isNull);
    await controller.discardWorkout();
    expect(controller.currentExercise, isNull);
  });

  test('focus is active-only, ephemeral, and resolves the durable entry', () {
    final repository = MemoryRepository()
      ..value = AppData(
        activeWorkout: _session('active', [
          _exercise('first'),
          _exercise('second'),
        ]),
        history: [
          _session('saved', [_exercise('historical')]),
        ],
      );
    final controller = create(repository);
    controller.focusExercise('second');
    expect(controller.currentExercise?.id, 'second');
    controller.focusExercise('historical');
    controller.focusExercise('missing');
    expect(controller.currentExercise?.id, 'second');
    expect(repository.writes, 0);
    expect(create(repository).currentExercise?.id, 'first');
  });

  test('adding publishes focus only after persistence succeeds', () async {
    final repository = _DelayedRepository()
      ..value = AppData(
        activeWorkout: _session('active', [_exercise('first')]),
      );
    final controller = create(repository);
    repository.hold = Completer<void>();
    final adding = controller.addExercise(exerciseCatalog.first.id);
    await Future<void>.delayed(Duration.zero);
    expect(controller.activeWorkout!.exercises.length, 1);
    expect(controller.currentExercise?.id, 'first');
    expect(controller.currentExerciseId.value, isNull);
    repository.hold!.complete();
    expect(await adding, isTrue);
    final added = controller.activeWorkout!.exercises.last;
    expect(controller.currentExercise?.id, added.id);
    expect(repository.value.activeWorkout!.exercises.last.id, added.id);
    repository.failWrites = true;
    expect(await controller.addExercise(exerciseCatalog[1].id), isFalse);
    expect(controller.currentExercise?.id, added.id);
    expect(controller.activeWorkout!.exercises.length, 2);
  });

  test(
    'set logging and adding focus active exercises, never history',
    () async {
      final repository = MemoryRepository()
        ..value = AppData(
          activeWorkout: _session('active', [
            _exercise('first'),
            _exercise('second'),
          ]),
          history: [
            _session('saved', [_exercise('historical')]),
          ],
        );
      final controller = create(repository);
      await controller.addSet('active', 'second');
      expect(controller.currentExercise?.id, 'second');
      await controller.updateSet(
        'active',
        'first',
        'set-first',
        reps: 12,
        weight: 50,
        completed: true,
      );
      expect(controller.currentExercise?.id, 'first');
      await controller.addSet('saved', 'historical');
      await controller.updateSet(
        'saved',
        'historical',
        'set-historical',
        reps: 10,
        weight: 45,
        completed: true,
      );
      expect(controller.currentExercise?.id, 'first');
      repository.failWrites = true;
      expect(await controller.addSet('active', 'second'), isFalse);
      expect(controller.currentExercise?.id, 'first');
    },
  );

  test('save and start archives every set with one atomic write', () async {
    final existing = _session('saved', [_exercise('historical')]);
    final draft = _session('active', [
      _exercise('completed', completed: true),
      _exercise('unfinished'),
    ]).copyWith(photoPath: 'photos/active.jpg');
    final repository = MemoryRepository()
      ..value = AppData(activeWorkout: draft, history: [existing]);
    final controller = create(repository);
    controller.focusExercise('unfinished');
    expect(await controller.saveAndStartWorkout(), isTrue);
    expect(repository.writes, 1);
    expect(controller.history.map((workout) => workout.id), [
      'active',
      'saved',
    ]);
    final archived = controller.history.first;
    expect(archived.finishedAt, DateTime(2026, 11, 8, 10));
    expect(archived.startedAt, DateTime(2026, 11, 8, 9));
    expect(archived.photoPath, 'photos/active.jpg');
    expect(archived.exercises.map((exercise) => exercise.id), [
      'completed',
      'unfinished',
    ]);
    expect(archived.exercises.last.sets.single.isCompleted, isFalse);
    expect(archived.exercises.last.sets.single.reps, 8);
    expect(archived.exercises.last.sets.single.weightKg, 40);
    expect(controller.activeWorkout!.id, isNot('active'));
    expect(controller.activeWorkout!.startedAt, DateTime(2026, 11, 8, 10));
    expect(controller.activeWorkout!.finishedAt, isNull);
    expect(controller.activeWorkout!.exercises, isEmpty);
    expect(controller.currentExercise, isNull);
    final reloaded = await repository.load();
    expect(reloaded.history.length, 2);
    expect(reloaded.activeWorkout!.id, controller.activeWorkout!.id);
  });

  test('save unfinished is allowed and clamps a backwards clock', () async {
    final now = DateTime(2026, 11, 8, 8);
    final repository = MemoryRepository()
      ..value = AppData(
        activeWorkout: _session('active', [_exercise('unfinished')]),
      );
    final controller = create(repository, now: now);
    expect(await controller.finishWorkout(), isFalse);
    expect(await controller.saveAndStartWorkout(), isTrue);
    expect(controller.history.single.completedSets, 0);
    expect(controller.history.single.exercises.single.sets.length, 1);
    expect(controller.history.single.finishedAt, DateTime(2026, 11, 8, 9));
    expect(controller.activeWorkout!.startedAt, now);
  });

  test('new draft avoids IDs already used by any saved record', () async {
    final now = DateTime(2026, 11, 8, 10);
    final prefix = now.microsecondsSinceEpoch;
    final repository = MemoryRepository()
      ..value = AppData(
        activeWorkout: _session('$prefix-0', [_exercise('$prefix-1')]),
        bodyWeights: [
          BodyWeightEntry(id: '$prefix-2', measuredAt: now, weightKg: 80),
        ],
      );
    final controller = create(repository, now: now);
    expect(await controller.saveAndStartWorkout(), isTrue);
    expect(controller.activeWorkout!.id, '$prefix-3');
    expect(controller.history.single.id, '$prefix-0');
    expect(controller.bodyWeights.single.id, '$prefix-2');
  });

  test(
    'save and start requires a draft and preserves both states on failure',
    () async {
      final repository = MemoryRepository();
      final controller = create(repository);
      expect(await controller.saveAndStartWorkout(), isFalse);
      expect(repository.writes, 0);
      await controller.startWorkout();
      await controller.addExercise(exerciseCatalog.first.id);
      final before = controller.data.value;
      final stored = repository.value;
      final focus = controller.currentExercise?.id;
      repository.failWrites = true;
      expect(await controller.saveAndStartWorkout(), isFalse);
      expect(identical(controller.data.value, before), isTrue);
      expect(identical(repository.value, stored), isTrue);
      expect(controller.history, isEmpty);
      expect(controller.currentExercise?.id, focus);
      repository.failWrites = false;
      expect(await controller.saveAndStartWorkout(), isTrue);
      expect(controller.history.single.id, before.activeWorkout!.id);
    },
  );

  test('save and start is serialized after pending set edits', () async {
    final repository = MemoryRepository()
      ..value = AppData(
        activeWorkout: _session('active', [_exercise('first')]),
      );
    final controller = create(repository);
    final results = await Future.wait([
      controller.updateSet(
        'active',
        'first',
        'set-first',
        reps: 13,
        weight: 57.5,
        completed: false,
      ),
      controller.saveAndStartWorkout(),
    ]);
    expect(results, [true, true]);
    expect(repository.writes, 2);
    expect(controller.history.single.exercises.single.sets.single.reps, 13);
    expect(
      controller.history.single.exercises.single.sets.single.weightKg,
      57.5,
    );
    expect(controller.activeWorkout!.exercises, isEmpty);
  });
}
