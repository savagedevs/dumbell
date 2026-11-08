import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/data/models.dart';
import 'package:workout_app/features/data_transfer/csv_cells.dart';
import 'package:workout_app/features/data_transfer/workout_csv_exporter.dart';

void main() {
  test('download groups workouts with readable dates, pounds, empty exercises and empty workouts', () {
    final start = DateTime(2026, 11, 8, 9, 5);
    final data = AppData(
      unit: WeightUnit.lb,
      history: [
        WorkoutSession(
          id: 'internal-id',
          name: 'Morning strength',
          startedAt: start,
          finishedAt: start.add(const Duration(minutes: 25, seconds: 12)),
          exercises: [
            WorkoutExercise(
              id: 'e1',
              exerciseId: 'squat',
              name: 'Back squat',
              sets: [
                WorkoutSet(id: 's1', reps: 8, weightKg: 10, isCompleted: true),
              ],
            ),
            WorkoutExercise(id: 'e2', exerciseId: 'row', name: 'Row', sets: []),
          ],
        ),
        WorkoutSession(
          id: 'empty',
          name: 'Recovery',
          startedAt: start,
          finishedAt: start,
          exercises: [],
        ),
      ],
    );
    final csv = WorkoutCsvExporter().encode(data);
    final rows = decodeCsvRows(csv);
    expect(rows.first, [
      'Workout #',
      'Workout',
      'Date',
      'Start time',
      'Duration',
      'Exercise',
      'Set',
      'Weight',
      'Unit',
      'Reps',
      'Completed',
    ]);
    expect(rows[1], [
      '1',
      'Morning strength',
      '2026-11-08',
      '09:05',
      '25m 12s',
      'Back squat',
      '1',
      '22.05',
      'lb',
      '8',
      'Yes',
    ]);
    expect(rows[2][0], '1');
    expect(rows[2][5], 'Row');
    expect(rows[2][6], '');
    expect(rows[3][0], '2');
    expect(rows[3][1], 'Recovery');
    expect(rows[3][5], 'No exercises recorded');
    expect(csv, isNot(contains('internal-id')));
    expect(csv, isNot(contains('record_type')));
  });
}
