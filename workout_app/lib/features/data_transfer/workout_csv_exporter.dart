import '../../core/formatters.dart';
import '../../data/models.dart';
import 'csv_cells.dart';

/// A readable training log for a person or a spreadsheet, separate from the
/// versioned backup format needed to restore exact identifiers and empty lists.
class WorkoutCsvExporter {
  String encode(AppData data) {
    final rows = <List<String>>[
      [
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
      ],
    ];
    var workoutNumber = 0;
    for (final workout in [
      ...data.history,
      if (data.activeWorkout != null) data.activeWorkout!,
    ]) {
      final start = workout.startedAt.toLocal();
      final prefix = [
        '${++workoutNumber}',
        workout.name,
        '${start.year.toString().padLeft(4, '0')}-${_two(start.month)}-${_two(start.day)}',
        '${_two(start.hour)}:${_two(start.minute)}',
        workout.finishedAt == null
            ? 'In progress'
            : _duration(workout.finishedAt!.difference(workout.startedAt)),
      ];
      if (workout.exercises.isEmpty) {
        rows.add([
          ...prefix,
          'No exercises recorded',
          '',
          '',
          data.unit.label,
          '',
          '',
        ]);
      }
      for (final exercise in workout.exercises) {
        if (exercise.sets.isEmpty) {
          rows.add([...prefix, exercise.name, '', '', data.unit.label, '', '']);
        }
        for (var index = 0; index < exercise.sets.length; index++) {
          final set = exercise.sets[index];
          final weight = displayWeight(
            set.weightKg,
            data.unit,
          ).toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
          rows.add([
            ...prefix,
            exercise.name,
            '${index + 1}',
            weight,
            data.unit.label,
            '${set.reps}',
            set.isCompleted ? 'Yes' : 'No',
          ]);
        }
      }
    }
    return encodeCsvRows(rows);
  }
}

String _two(int value) => value.toString().padLeft(2, '0');
String _duration(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  final seconds = value.inSeconds.remainder(60);
  return '${hours > 0 ? '${hours}h ' : ''}${minutes}m ${seconds}s';
}
