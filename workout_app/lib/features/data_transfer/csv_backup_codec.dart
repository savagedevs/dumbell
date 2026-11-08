import 'dart:convert';

import '../../data/models.dart';
import 'csv_cells.dart';

/// Versioned Dumbbell backup. Names, IDs, empty lists, ordering, UTC instants and
/// canonical kilogram values survive an exact roundtrip. Photos/profile are
/// deliberately omitted: a filename cannot back up a private image's bytes.
class CsvBackupCodec {
  static const maxBytes = 8 * 1024 * 1024;
  static const _columns = [
    'format_version',
    'record_type',
    'id',
    'parent_id',
    'position',
    'scope',
    'name',
    'exercise_id',
    'started_at_utc',
    'finished_at_utc',
    'duration_microseconds',
    'reps',
    'weight_kg',
    'completed',
    'display_unit',
    'display_weight',
  ];

  String encode(AppData data) {
    final rows = <List<String>>[_columns];
    void add(String type, Map<String, String> values) {
      final fields = {'format_version': '1', 'record_type': type, ...values};
      rows.add(_columns.map((name) => fields[name] ?? '').toList());
    }

    add('backup', {'id': 'liftlog', 'display_unit': data.unit.name});
    void session(WorkoutSession workout, String scope, int position) {
      add('session', {
        'id': workout.id,
        'position': '$position',
        'scope': scope,
        'name': workout.name,
        'started_at_utc': workout.startedAt.toUtc().toIso8601String(),
        if (workout.finishedAt != null) ...{
          'finished_at_utc': workout.finishedAt!.toUtc().toIso8601String(),
          'duration_microseconds':
              '${workout.finishedAt!.difference(workout.startedAt).inMicroseconds}',
        },
      });
      for (var e = 0; e < workout.exercises.length; e++) {
        final exercise = workout.exercises[e];
        add('exercise', {
          'id': exercise.id,
          'parent_id': workout.id,
          'position': '$e',
          'name': exercise.name,
          'exercise_id': exercise.exerciseId,
        });
        for (var s = 0; s < exercise.sets.length; s++) {
          final set = exercise.sets[s];
          add('set', {
            'id': set.id,
            'parent_id': exercise.id,
            'position': '$s',
            'reps': '${set.reps}',
            'weight_kg': '${set.weightKg}',
            'completed': '${set.isCompleted}',
            'display_unit': data.unit.name,
            'display_weight': '${_display(set.weightKg, data.unit)}',
          });
        }
      }
    }

    for (var i = 0; i < data.history.length; i++) {
      session(data.history[i], 'history', i);
    }
    if (data.activeWorkout != null) session(data.activeWorkout!, 'active', 0);
    for (var i = 0; i < data.bodyWeights.length; i++) {
      final entry = data.bodyWeights[i];
      add('body_weight', {
        'id': entry.id,
        'position': '$i',
        'started_at_utc': entry.measuredAt.toUtc().toIso8601String(),
        'weight_kg': '${entry.weightKg}',
        'display_unit': data.unit.name,
        'display_weight': '${_display(entry.weightKg, data.unit)}',
      });
    }
    final encoded = encodeCsvRows(rows);
    if (utf8.encode(encoded).length > maxBytes) {
      throw const FormatException('This backup exceeds the 8 MiB file limit.');
    }
    // Refuse to create a backup that cannot be restored, including corrupt
    // duplicate IDs or records beyond the import's documented size bounds.
    decode(encoded);
    return encoded;
  }

  AppData decode(String csv) {
    if (csv.length > maxBytes || utf8.encode(csv).length > maxBytes) {
      throw const FormatException(
        'Choose a Dumbbell backup smaller than 8 MiB.',
      );
    }
    final rows = decodeCsvRows(csv);
    if (rows.length < 2 || !_same(rows.first, _columns)) {
      throw const FormatException(
        'Choose a Dumbbell Backup CSV, not a workout download.',
      );
    }
    final ids = <String>{};
    final sessions = <String, _Record>{};
    final exercises = <String, _Record>{};
    final sets = <_Record>[];
    final weights = <_Record>[];
    WeightUnit? unit;
    for (var index = 1; index < rows.length; index++) {
      final row = rows[index];
      if (row.length != _columns.length) {
        throw FormatException(
          'Row ${index + 1} has an incorrect number of columns.',
        );
      }
      final values = Map<String, String>.fromIterables(_columns, row);
      final record = _Record(values, index + 1);
      if (record['format_version'] != '1') {
        throw const FormatException('Unsupported Dumbbell CSV backup version.');
      }
      final type = record['record_type'];
      final allowed = switch (type) {
        'backup' => {'id', 'display_unit'},
        'session' => {
          'id',
          'position',
          'scope',
          'name',
          'started_at_utc',
          'finished_at_utc',
          'duration_microseconds',
        },
        'exercise' => {'id', 'parent_id', 'position', 'name', 'exercise_id'},
        'set' => {
          'id',
          'parent_id',
          'position',
          'reps',
          'weight_kg',
          'completed',
          'display_unit',
          'display_weight',
        },
        'body_weight' => {
          'id',
          'position',
          'started_at_utc',
          'weight_kg',
          'display_unit',
          'display_weight',
        },
        _ => throw FormatException('Unknown record type on row ${index + 1}.'),
      };
      for (final column in _columns.skip(2)) {
        if (!allowed.contains(column) && record[column].isNotEmpty) {
          record.fail('Unexpected $column');
        }
      }
      if (type == 'backup') {
        if (unit != null || index != 1 || record['id'] != 'liftlog') {
          record.fail('Invalid backup metadata');
        }
        unit = switch (record['display_unit']) {
          'kg' => WeightUnit.kg,
          'lb' => WeightUnit.lb,
          _ => throw const FormatException('Invalid backup display unit.'),
        };
        continue;
      }
      if (unit == null) record.fail('Missing backup metadata');
      record.text('id');
      if (!ids.add(record['id'])) record.fail('Duplicate record ID');
      record.integer('position');
      switch (type) {
        case 'session':
          sessions[record['id']] = record;
        case 'exercise':
          exercises[record['id']] = record;
        case 'set':
          sets.add(record);
        case 'body_weight':
          weights.add(record);
      }
    }
    if (unit == null) throw const FormatException('Missing backup metadata.');
    final exercisesBySession = <String, List<_Record>>{};
    final setsByExercise = <String, List<_Record>>{};
    for (final exercise in exercises.values) {
      if (!sessions.containsKey(exercise.text('parent_id'))) {
        exercise.fail('Unknown parent workout');
      }
      (exercisesBySession[exercise['parent_id']] ??= []).add(exercise);
    }
    for (final set in sets) {
      if (!exercises.containsKey(set.text('parent_id'))) {
        set.fail('Unknown parent exercise');
      }
      (setsByExercise[set['parent_id']] ??= []).add(set);
    }
    WorkoutSession buildSession(_Record row) {
      final started = row.date('started_at_utc');
      final finished = row['finished_at_utc'].isEmpty
          ? null
          : row.date('finished_at_utc');
      if (finished == null) {
        if (row['duration_microseconds'].isNotEmpty) {
          row.fail('An unfinished workout has no fixed duration');
        }
      } else if (finished.isBefore(started) ||
          row.integer('duration_microseconds') !=
              finished.difference(started).inMicroseconds) {
        row.fail('Workout dates and duration disagree');
      }
      return WorkoutSession(
        id: row.text('id'),
        name: row.text('name'),
        startedAt: started,
        finishedAt: finished,
        exercises: _ordered(exercisesBySession[row['id']] ?? const [])
            .map(
              (e) => WorkoutExercise(
                id: e.text('id'),
                exerciseId: e.text('exercise_id'),
                name: e.text('name'),
                sets: _ordered(setsByExercise[e['id']] ?? const []).map((s) {
                  final weight = s.weight(unit!);
                  final completed = switch (s['completed']) {
                    'true' => true,
                    'false' => false,
                    _ => throw FormatException(
                      'Invalid set completion on row ${s.number}.',
                    ),
                  };
                  return WorkoutSet(
                    id: s['id'],
                    reps: s.integer('reps'),
                    weightKg: weight,
                    isCompleted: completed,
                  );
                }).toList(),
              ),
            )
            .toList(),
      );
    }

    final history = <_Record>[];
    final active = <_Record>[];
    for (final session in sessions.values) {
      switch (session['scope']) {
        case 'history':
          history.add(session);
        case 'active':
          active.add(session);
        default:
          session.fail('Invalid workout scope');
      }
    }
    if (active.length > 1) {
      throw const FormatException(
        'A backup can contain only one active workout.',
      );
    }
    final draft = active.isEmpty ? null : buildSession(_ordered(active).single);
    if (draft?.finishedAt != null) {
      throw const FormatException('An active workout cannot be finished.');
    }
    return AppData(
      unit: unit,
      history: _ordered(history).map(buildSession).toList(),
      activeWorkout: draft,
      bodyWeights: _ordered(weights)
          .map(
            (row) => BodyWeightEntry(
              id: row['id'],
              measuredAt: row.date('started_at_utc'),
              weightKg: row.weight(unit!, positive: true),
            ),
          )
          .toList(),
    );
  }
}

double _display(double kg, WeightUnit unit) =>
    unit == WeightUnit.lb ? kg * 2.2046226218 : kg;
bool _same(List<String> a, List<String> b) =>
    a.length == b.length &&
    List.generate(a.length, (i) => a[i] == b[i]).every((v) => v);

List<_Record> _ordered(Iterable<_Record> source) {
  final result = source.toList()
    ..sort((a, b) => a.integer('position').compareTo(b.integer('position')));
  for (var i = 0; i < result.length; i++) {
    if (result[i].integer('position') != i) {
      result[i].fail('Missing or duplicate position');
    }
  }
  return result;
}

class _Record {
  _Record(this.values, this.number);
  final Map<String, String> values;
  final int number;
  String operator [](String key) => values[key]!;
  Never fail(String message) =>
      throw FormatException('$message on row $number.');
  String text(String key) {
    final value = this[key];
    if (value.trim().isEmpty || value.contains('\u0000')) fail('Invalid $key');
    return value;
  }

  int integer(String key) {
    final raw = this[key];
    final value = int.tryParse(raw);
    if (!RegExp(r'^\d+$').hasMatch(raw) || value == null || value < 0) {
      fail('Invalid $key');
    }
    return value;
  }

  DateTime date(String key) {
    final raw = this[key];
    final value = DateTime.tryParse(raw);
    // Comparing canonical UTC spelling also rejects Dart's date overflow
    // normalization (e.g. February 30) and timezone-ambiguous timestamps.
    if (value == null ||
        !raw.endsWith('Z') ||
        value.toUtc().toIso8601String() != raw) {
      fail('Invalid UTC $key');
    }
    return value;
  }

  double weight(WeightUnit unit, {bool positive = false}) {
    final value = double.tryParse(this['weight_kg']);
    final displayed = double.tryParse(this['display_weight']);
    if (value == null ||
        !value.isFinite ||
        value < 0 ||
        (positive && value == 0) ||
        displayed == null ||
        !displayed.isFinite ||
        displayed != _display(value, unit) ||
        this['display_unit'] != unit.name) {
      fail('Invalid or inconsistent weight');
    }
    return value;
  }
}
