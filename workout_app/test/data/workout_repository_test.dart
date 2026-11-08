import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:workout_app/data/models.dart';
import 'package:workout_app/data/workout_repository.dart';

void main() {
  test('schema one migrates without losing draft, sets or units', () async {
    final database = await newDatabaseFactoryMemory().openDatabase('migration');
    final store = stringMapStoreFactory.store('app_data');
    final legacy = <String, Object?>{
      'schemaVersion': 1,
      'unit': 'lb',
      'history': <Object?>[],
      'bodyWeights': <Object?>[],
      'activeWorkout': {
        'id': 'old-draft',
        'name': 'Keep my workout',
        'startedAt': '2026-11-08T00:00:00.000Z',
        'finishedAt': null,
        'exercises': [
          {
            'id': 'entry',
            'exerciseId': 'squat',
            'name': 'Squat',
            'sets': [
              {'id': 'set', 'reps': 7, 'weightKg': 82.5, 'isCompleted': true},
            ],
          },
        ],
      },
    };
    await store.record('snapshot').put(database, legacy);
    final repository = LocalWorkoutRepository(database);
    final migrated = await repository.load();
    expect(migrated.unit, WeightUnit.lb);
    expect(migrated.activeWorkout!.exercises.single.sets.single.weightKg, 82.5);
    expect(migrated.onboardingCompleted, isFalse);
    expect(migrated.profile, isNull);
    // Loading alone does not overwrite the old snapshot.
    expect(await store.record('snapshot').get(database), legacy);
    await repository.save(migrated.copyWith(onboardingCompleted: true));
    expect((await store.record('snapshot').get(database))!['schemaVersion'], 2);
    expect((await repository.load()).activeWorkout!.id, 'old-draft');
    await repository.close();
  });

  test('persists a full snapshot across database reopen', () async {
    final factory = newDatabaseFactoryMemory();
    var database = await factory.openDatabase('workout-test');
    var repository = LocalWorkoutRepository(database);
    expect((await repository.load()).history, isEmpty);

    final snapshot = AppData(
      activeWorkout: WorkoutSession(
        id: 'active-1',
        name: 'Morning workout',
        startedAt: DateTime.utc(2026, 11, 8, 10),
        exercises: [
          WorkoutExercise(
            id: 'entry-1',
            exerciseId: 'squat',
            name: 'Squat',
            sets: [
              WorkoutSet(
                id: 'set-1',
                reps: 5,
                weightKg: 100,
                isCompleted: true,
              ),
            ],
          ),
        ],
      ),
      unit: WeightUnit.lb,
      bodyWeights: [
        BodyWeightEntry(
          id: 'weight-1',
          measuredAt: DateTime.utc(2026, 11, 8),
          weightKg: 81.25,
        ),
      ],
    );
    await repository.save(snapshot);
    await repository.close();

    database = await factory.openDatabase('workout-test');
    repository = LocalWorkoutRepository(database);
    final loaded = await repository.load();
    expect(loaded.toJson(), snapshot.toJson());
    expect(loaded.activeWorkout!.completedSets, 1);
    expect(loaded.activeWorkout!.volumeKg, 500);
    await repository.close();
  });

  test('refuses to read or overwrite an unknown future schema', () async {
    final database = await newDatabaseFactoryMemory().openDatabase('future');
    final store = stringMapStoreFactory.store('app_data');
    final futureData = <String, Object?>{
      'schemaVersion': 99,
      'futureFeature': {'mustBePreserved': true},
    };
    await store.record('snapshot').put(database, futureData);
    final repository = LocalWorkoutRepository(database);

    await expectLater(
      repository.load(),
      throwsA(isA<UnsupportedSchemaVersionException>()),
    );
    await expectLater(
      repository.save(AppData()),
      throwsA(isA<UnsupportedSchemaVersionException>()),
    );
    expect(await store.record('snapshot').get(database), futureData);
    await repository.close();
  });

  test('refuses to replace corrupt data with an empty snapshot', () async {
    final database = await newDatabaseFactoryMemory().openDatabase('corrupt');
    final store = stringMapStoreFactory.store('app_data');
    final corrupt = <String, Object?>{'schemaVersion': 1, 'history': 'corrupt'};
    await store.record('snapshot').put(database, corrupt);
    final repository = LocalWorkoutRepository(database);

    await expectLater(repository.load(), throwsFormatException);
    await expectLater(repository.save(AppData()), throwsFormatException);
    expect(await store.record('snapshot').get(database), corrupt);
    await repository.close();
  });
}
