import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:sembast/sembast_io.dart';
import 'package:workout_app/app/workout_controller.dart';
import 'package:workout_app/data/workout_repository.dart';
import 'package:workout_app/features/data_transfer/csv_backup_codec.dart';
import 'package:workout_app/features/data_transfer/csv_cells.dart';
import 'package:workout_app/features/data_transfer/workout_csv_exporter.dart';

void main() {
  late Directory directory;
  late LocalWorkoutRepository repository;
  late WorkoutController controller;

  Future<void> reopen() async {
    await repository.close();
    repository = LocalWorkoutRepository(
      await databaseFactoryIo.openDatabase('${directory.path}/workouts.db'),
    );
  }

  setUp(() async {
    Get.testMode = true;
    directory = await Directory.systemTemp.createTemp('repdb-history-');
    final database = await databaseFactoryIo.openDatabase(
      '${directory.path}/workouts.db',
    );
    await stringMapStoreFactory
        .store('app_data')
        .record('snapshot')
        .put(database, _legacySnapshot);
    repository = LocalWorkoutRepository(database);
    controller = WorkoutController(
      repository,
      await repository.load(),
      clock: () => DateTime.utc(2026, 11, 8, 12),
    );
  });

  tearDown(() async {
    await controller.waitForPendingWrites();
    await repository.close();
    await directory.delete(recursive: true);
    Get.reset();
  });

  test(
    'pre-RepDB history and draft remain editable without remapping snapshots',
    () async {
      expect(controller.data.value.toJson(), _legacySnapshot);
      final history = controller.sessionById('old-workout')!;
      final draft = controller.activeWorkout!;

      expect(
        await controller.updateSet(
          history.id,
          'old-wger-entry',
          'old-wger-set',
          reps: 6,
          weight: 47.5,
          completed: true,
        ),
        isTrue,
      );
      expect(
        await controller.updateSet(
          draft.id,
          'old-draft-entry',
          'old-draft-set',
          reps: 4,
          weight: 92.5,
          completed: true,
        ),
        isTrue,
      );

      await reopen();
      final restored = await repository.load();
      final editedHistory = restored.history.single;
      expect(editedHistory.id, 'old-workout');
      expect(editedHistory.name, 'Original session');
      expect(editedHistory.startedAt, DateTime.utc(2026, 11, 1, 9));
      expect(editedHistory.finishedAt, DateTime.utc(2026, 11, 1, 9, 30));
      expect(editedHistory.exercises.first.toJson(), {
        ..._legacyHistoryExercises.first,
        'sets': [
          {
            'id': 'old-wger-set',
            'reps': 6,
            'weightKg': 47.5,
            'isCompleted': true,
          },
          {
            'id': 'old-wger-warmup',
            'reps': 12,
            'weightKg': 20.0,
            'isCompleted': false,
          },
        ],
      });
      expect(
        editedHistory.exercises
            .skip(1)
            .map((exercise) => exercise.toJson())
            .toList(),
        _legacyHistoryExercises.skip(1).toList(),
      );
      expect(restored.activeWorkout!.toJson(), {
        ..._legacyDraft,
        'exercises': [
          {
            ..._legacyDraftExercise,
            'sets': [
              {
                'id': 'old-draft-set',
                'reps': 4,
                'weightKg': 92.5,
                'isCompleted': true,
              },
            ],
          },
        ],
      });
    },
  );

  test('pre-RepDB snapshots export readable CSV and restore losslessly from backup', () {
    final data = controller.data.value;
    final rows = decodeCsvRows(WorkoutCsvExporter().encode(data));
    expect(rows.skip(1).map((row) => row.sublist(5)).toList(), [
      ['My saved Wger row', '1', '45.75', 'kg', '8', 'Yes'],
      ['My saved Wger row', '2', '20', 'kg', '12', 'No'],
      ['Original Barbell Row', '1', '60.13', 'kg', '5', 'Yes'],
      ['Farmer carry, "custom"', '1', '24.5', 'kg', '20', 'Yes'],
      ['My original squat', '1', '90.25', 'kg', '3', 'No'],
    ]);
    expect(rows.last[4], 'In progress');

    final codec = CsvBackupCodec();
    expect(codec.decode(codec.encode(data)).toJson(), _legacySnapshot);
  });

  test('adding RepDB exercises appends entries and preserves every old snapshot', () async {
    final original = controller.data.value;
    expect(await controller.addExercise('repdb_squat'), isTrue);
    expect(await controller.addExercise('repdb_barbell-row'), isTrue);

    await reopen();
    final restored = await repository.load();
    expect(
      restored.history.map((session) => session.toJson()).toList(),
      _legacySnapshot['history'],
    );
    final draft = restored.activeWorkout!;
    expect(draft.exercises.map((exercise) => exercise.exerciseId).toList(), [
      'squat',
      'repdb_squat',
      'repdb_barbell-row',
    ]);
    expect(draft.exercises.first.toJson(), _legacyDraftExercise);
    expect(
      draft.toJson()..remove('exercises'),
      {..._legacyDraft}..remove('exercises'),
    );
    expect(draft.exercises.map((exercise) => exercise.id).toSet().length, 3);
    expect(draft.exercises[1].sets.single.weightKg, 0);
    expect(draft.exercises[2].sets.single.weightKg, 60.125);
    expect(draft.exercises[2].sets.single.reps, 5);
    expect(draft.exercises[2].sets.single.isCompleted, isFalse);
    // The already loaded objects also remain intact after controller mutations.
    expect(original.toJson(), _legacySnapshot);
  });
}

const _legacyHistoryExercises = <Map<String, Object?>>[
  {
    'id': 'old-wger-entry',
    'exerciseId': 'wger_83',
    'name': 'My saved Wger row',
    'sets': [
      {'id': 'old-wger-set', 'reps': 8, 'weightKg': 45.75, 'isCompleted': true},
      {
        'id': 'old-wger-warmup',
        'reps': 12,
        'weightKg': 20.0,
        'isCompleted': false,
      },
    ],
  },
  {
    'id': 'old-original-entry',
    'exerciseId': 'barbell_row',
    'name': 'Original Barbell Row',
    'sets': [
      {
        'id': 'old-original-set',
        'reps': 5,
        'weightKg': 60.125,
        'isCompleted': true,
      },
    ],
  },
  {
    'id': 'old-custom-entry',
    'exerciseId': 'custom_carry',
    'name': 'Farmer carry, "custom"',
    'sets': [
      {
        'id': 'old-custom-set',
        'reps': 20,
        'weightKg': 24.5,
        'isCompleted': true,
      },
    ],
  },
];

const _legacyDraftExercise = <String, Object?>{
  'id': 'old-draft-entry',
  'exerciseId': 'squat',
  'name': 'My original squat',
  'sets': [
    {'id': 'old-draft-set', 'reps': 3, 'weightKg': 90.25, 'isCompleted': false},
  ],
};

const _legacyDraft = <String, Object?>{
  'id': 'old-draft',
  'name': 'Unfinished original session',
  'startedAt': '2026-11-08T10:00:00.000Z',
  'finishedAt': null,
  'photoPath': null,
  'exercises': [_legacyDraftExercise],
};

const _legacySnapshot = <String, Object?>{
  'schemaVersion': 2,
  'unit': 'kg',
  'profile': null,
  'onboardingCompleted': false,
  'bodyWeights': <Object?>[],
  'history': [
    {
      'id': 'old-workout',
      'name': 'Original session',
      'startedAt': '2026-11-01T09:00:00.000Z',
      'finishedAt': '2026-11-01T09:30:00.000Z',
      'photoPath': null,
      'exercises': _legacyHistoryExercises,
    },
  ],
  'activeWorkout': _legacyDraft,
};
