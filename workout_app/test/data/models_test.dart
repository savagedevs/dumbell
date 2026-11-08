import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/data/models.dart';

void main() {
  group('immutable workout snapshots', () {
    test('defensively copies every nested collection', () {
      final sets = <WorkoutSet>[
        WorkoutSet(id: 'set-1', reps: 5, weightKg: 100, isCompleted: true),
      ];
      final exercises = <WorkoutExercise>[
        WorkoutExercise(
          id: 'entry-1',
          exerciseId: 'squat',
          name: 'Squat',
          sets: sets,
        ),
      ];
      final history = <WorkoutSession>[
        WorkoutSession(
          id: 'session-1',
          name: 'Leg day',
          startedAt: DateTime.utc(2026, 11, 8, 10),
          finishedAt: DateTime.utc(2026, 11, 8, 10, 30),
          exercises: exercises,
        ),
      ];
      final weights = <BodyWeightEntry>[
        BodyWeightEntry(
          id: 'weight-1',
          measuredAt: DateTime.utc(2026, 11, 8),
          weightKg: 80,
        ),
      ];
      final data = AppData(history: history, bodyWeights: weights);
      sets.clear();
      exercises.clear();
      history.clear();
      weights.clear();

      expect(data.history.single.exercises.single.sets.single.reps, 5);
      expect(data.bodyWeights.single.weightKg, 80);
      expect(() => data.history.clear(), throwsUnsupportedError);
      expect(
        () => data.history.single.exercises.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => data.history.single.exercises.single.sets.clear(),
        throwsUnsupportedError,
      );
      expect(() => data.bodyWeights.clear(), throwsUnsupportedError);
    });

    test('only completed sets contribute to volume and set totals', () {
      final session = WorkoutSession.fromJson(_sessionJson());
      expect(session.completedSets, 1);
      expect(session.volumeKg, 500);
      expect(session.duration, const Duration(minutes: 30));
    });

    test('round-trips an active session and body weight with kg storage', () {
      final json = <String, Object?>{
        'schemaVersion': 1,
        'history': <Object?>[_sessionJson()],
        'activeWorkout': _sessionJson()
          ..['id'] = 'active-1'
          ..['finishedAt'] = null,
        'unit': 'lb',
        'bodyWeights': <Object?>[
          {
            'id': 'weight-1',
            'measuredAt': '2026-11-08T00:00:00.000Z',
            'weightKg': 81.25,
          },
        ],
      };

      final data = AppData.fromJson(json);
      expect(data.unit, WeightUnit.lb);
      expect(data.activeWorkout!.startedAt, DateTime.utc(2026, 11, 8, 10));
      expect(data.bodyWeights.single.weightKg, 81.25);
      final migrated = data.toJson();
      expect(migrated['schemaVersion'], 2);
      expect(data.profile, isNull);
      expect(data.onboardingCompleted, isFalse);
      expect(AppData.fromJson(migrated).toJson(), migrated);
      expect(data.copyWith().activeWorkout, same(data.activeWorkout));
      expect(data.copyWith(clearActiveWorkout: true).activeWorkout, isNull);
      expect(data.history.single.copyWith(name: 'Updated').name, 'Updated');
      expect(data.history.single.name, 'Leg day');
    });
  });

  group('persisted data validation', () {
    test('normalizes local timestamps to UTC without shifting instants', () {
      final startedAt = DateTime(2026, 7, 8, 10, 15, 30, 123, 456);
      final finishedAt = startedAt.add(const Duration(minutes: 30));
      final measuredAt = DateTime(2026, 7, 8, 8, 5, 4, 321, 654);
      final session = WorkoutSession(
        id: 'session-local',
        name: 'Summer workout',
        startedAt: startedAt,
        finishedAt: finishedAt,
        exercises: [],
      );
      final weight = BodyWeightEntry(
        id: 'weight-local',
        measuredAt: measuredAt,
        weightKg: 81.25,
      );

      final sessionJson = session.toJson();
      final weightJson = weight.toJson();
      expect(sessionJson['startedAt'], endsWith('Z'));
      expect(sessionJson['finishedAt'], endsWith('Z'));
      expect(weightJson['measuredAt'], endsWith('Z'));
      final restoredSession = WorkoutSession.fromJson(sessionJson);
      final restoredWeight = BodyWeightEntry.fromJson(weightJson);
      expect(
        restoredSession.startedAt.microsecondsSinceEpoch,
        startedAt.microsecondsSinceEpoch,
      );
      expect(
        restoredSession.finishedAt!.microsecondsSinceEpoch,
        finishedAt.microsecondsSinceEpoch,
      );
      expect(
        restoredWeight.measuredAt.microsecondsSinceEpoch,
        measuredAt.microsecondsSinceEpoch,
      );
    });

    test('rejects missing and future schema versions', () {
      expect(() => AppData.fromJson({}), throwsFormatException);
      expect(
        () => AppData.fromJson({'schemaVersion': 99}),
        throwsA(isA<UnsupportedSchemaVersionException>()),
      );
    });

    test('rejects malformed and non-finite set values', () {
      for (final invalid in <Object?>[-1, 2.5, '5', null]) {
        final json = _setJson()..['reps'] = invalid;
        expect(() => WorkoutSet.fromJson(json), throwsFormatException);
      }
      for (final invalid in <Object?>[-1, double.nan, double.infinity, '10']) {
        final json = _setJson()..['weightKg'] = invalid;
        expect(() => WorkoutSet.fromJson(json), throwsFormatException);
      }
      expect(
        () => WorkoutSet.fromJson(_setJson()..['isCompleted'] = 'true'),
        throwsFormatException,
      );
    });

    test('rejects impossible dates and finish times before the start', () {
      for (final invalid in <Object?>[
        'not-a-date',
        '2026-02-31T10:00:00.000Z',
        '2026-11-08T25:00:00.000Z',
        '999999-11-08T10:00:00.000Z',
        12345,
      ]) {
        expect(
          () =>
              WorkoutSession.fromJson(_sessionJson()..['startedAt'] = invalid),
          throwsFormatException,
        );
      }
      expect(
        () => WorkoutSession.fromJson(
          _sessionJson()..['finishedAt'] = '2026-11-08T09:59:00.000Z',
        ),
        throwsFormatException,
      );
    });

    test('rejects invalid body weight and unknown units', () {
      for (final invalid in <Object?>[0, -1, double.infinity, '80']) {
        expect(
          () => BodyWeightEntry.fromJson({
            'id': 'weight-1',
            'measuredAt': '2026-11-08T00:00:00.000Z',
            'weightKg': invalid,
          }),
          throwsFormatException,
        );
      }
      expect(
        () => AppData.fromJson({
          'schemaVersion': 1,
          'history': <Object?>[],
          'activeWorkout': null,
          'unit': 'stone',
          'bodyWeights': <Object?>[],
        }),
        throwsFormatException,
      );
    });
  });
}

Map<String, Object?> _setJson() => {
  'id': 'set-1',
  'reps': 5,
  'weightKg': 100.0,
  'isCompleted': true,
};

Map<String, Object?> _sessionJson() => {
  'id': 'session-1',
  'name': 'Leg day',
  'startedAt': '2026-11-08T10:00:00.000Z',
  'finishedAt': '2026-11-08T10:30:00.000Z',
  'exercises': <Object?>[
    {
      'id': 'entry-1',
      'exerciseId': 'squat',
      'name': 'Squat',
      'sets': <Object?>[
        _setJson(),
        {'id': 'set-2', 'reps': 10, 'weightKg': 100.0, 'isCompleted': false},
      ],
    },
  ],
};
