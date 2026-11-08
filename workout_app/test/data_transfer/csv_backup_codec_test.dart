import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/data/models.dart';
import 'package:workout_app/features/data_transfer/csv_backup_codec.dart';

void main() {
  final codec = CsvBackupCodec();
  final start = DateTime.utc(2026, 11, 8, 12, 30, 1, 4, 5);

  AppData sample({String name = 'Push, pull\n"Day"'}) => AppData(
    unit: WeightUnit.lb,
    history: [
      WorkoutSession(
        id: 'session-1',
        name: name,
        startedAt: start,
        finishedAt: start.add(const Duration(minutes: 3, microseconds: 42)),
        exercises: [
          WorkoutExercise(
            id: 'empty-exercise',
            exerciseId: 'squat',
            name: 'Empty',
            sets: [],
          ),
          WorkoutExercise(
            id: 'exercise-1',
            exerciseId: 'custom',
            name: '@Press',
            sets: [
              WorkoutSet(
                id: 'set-1',
                reps: 8,
                weightKg: 42.125,
                isCompleted: true,
              ),
              WorkoutSet(id: 'set-2', reps: 0, weightKg: 0),
            ],
          ),
        ],
      ),
      WorkoutSession(
        id: 'empty-session',
        name: 'No exercises',
        startedAt: start,
        finishedAt: start,
        exercises: [],
      ),
    ],
    activeWorkout: WorkoutSession(
      id: 'draft',
      name: 'In progress',
      startedAt: start,
      exercises: [],
    ),
    bodyWeights: [
      BodyWeightEntry(
        id: 'weight-1',
        measuredAt: start,
        weightKg: 75.123456789,
      ),
    ],
  );

  test('roundtrip preserves identifiers, empty records, ordering and exact canonical weights', () {
    final original = sample();
    final restored = codec.decode(codec.encode(original));
    expect(restored.toJson(), original.toJson());
    expect(restored.history.first.duration.inMicroseconds, 180000042);
  });

  test('empty backup retains its chosen display unit', () {
    final restored = codec.decode(codec.encode(AppData(unit: WeightUnit.lb)));
    expect(restored.unit, WeightUnit.lb);
    expect(restored.history, isEmpty);
    expect(restored.activeWorkout, isNull);
  });

  test('spreadsheet formula protection is reversible including original apostrophes', () {
    for (final name in [
      "=HYPERLINK(\"bad\")",
      '+SUM(1)',
      '-10',
      '@cmd',
      '  =1',
      '\t=1',
      "'original",
      "''=1",
      'ordinary',
    ]) {
      final encoded = codec.encode(sample(name: name));
      expect(codec.decode(encoded).history.first.name, name);
      if (name != 'ordinary') {
        expect(encoded, contains("'${name.replaceAll('"', '""')}"));
      }
    }
  });

  test(
    'rejects unknown versions and malformed quoting before restoring data',
    () {
      final valid = codec.encode(sample());
      expect(
        () => codec.decode(valid.replaceFirst('1,backup', '99,backup')),
        throwsFormatException,
      );
      expect(
        () => codec.decode('$valid\r\n"unterminated'),
        throwsFormatException,
      );
    },
  );

  test('rejects duplicate IDs, orphaned sets and inconsistent duration', () {
    final valid = codec.encode(sample());
    expect(
      () => codec.decode(valid.replaceFirst('set-2', 'set-1')),
      throwsFormatException,
    );
    expect(
      () =>
          codec.decode(valid.replaceFirst('set-1,exercise-1', 'set-1,missing')),
      throwsFormatException,
    );
    expect(
      () => codec.decode(valid.replaceFirst('180000042', '180000043')),
      throwsFormatException,
    );
  });

  test('rejects nonfinite canonical weights and unsafe unescaped cells', () {
    final valid = codec.encode(sample(name: 'safe-name'));
    expect(
      () => codec.decode(valid.replaceFirst('42.125', 'NaN')),
      throwsFormatException,
    );
    expect(
      () => codec.decode(valid.replaceFirst('safe-name', '=NOW()')),
      throwsFormatException,
    );
    expect(
      () => codec.decode(
        valid.replaceFirst(
          '2026-11-08T12:30:01.004005Z',
          '2026-02-30T12:30:01.004005Z',
        ),
      ),
      throwsFormatException,
    );
  });

  test('rejects oversized input before parsing', () {
    expect(
      () => codec.decode('x' * (CsvBackupCodec.maxBytes + 1)),
      throwsFormatException,
    );
  });
}
