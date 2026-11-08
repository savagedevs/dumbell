import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/data/exercise_performance.dart';
import 'package:workout_app/data/models.dart';

void main() {
  group('exercise identity', () {
    test('the original IDs resolve to their exact RepDB movements', () {
      const expected = {
        'squat': ('repdb_squat', 'Barbell Back Squat', 'Barbell'),
        'bench_press': ('repdb_bench-press', 'Barbell Bench Press', 'Barbell'),
        'deadlift': ('repdb_deadlift', 'Barbell Deadlift', 'Barbell'),
        'overhead_press': ('repdb_ohp', 'Barbell Overhead Press', 'Barbell'),
        'barbell_row': (
          'repdb_barbell-row',
          'Bent-Over Barbell Row',
          'Barbell',
        ),
        'romanian_deadlift': (
          'repdb_romanian-deadlift',
          'Romanian Deadlift',
          'Barbell',
        ),
        'dumbbell_bench_press': (
          'repdb_db-bench-press',
          'Dumbbell Bench Press',
          'Dumbbell',
        ),
        'dumbbell_row': (
          'repdb_single-arm-db-row',
          'Single-Arm Dumbbell Row',
          'Dumbbell',
        ),
        'lateral_raise': (
          'repdb_lateral-raise',
          'Dumbbell Lateral Raise',
          'Dumbbell',
        ),
        'biceps_curl': ('repdb_bicep-curl', 'Dumbbell Bicep Curl', 'Dumbbell'),
        'triceps_pushdown': (
          'repdb_tricep-pushdown',
          'Cable Tricep Pushdown',
          'Cable Machine',
        ),
        'lat_pulldown': ('repdb_lat-pulldown', 'Lat Pulldown', 'Cable Machine'),
        'seated_cable_row': (
          'repdb_seated-cable-row',
          'Seated Cable Row',
          'Cable Machine',
        ),
        'leg_press': ('repdb_leg-press', 'Leg Press', 'Leg Press'),
        'goblet_squat': (
          'repdb_db-goblet-squat',
          'Dumbbell Goblet Squat',
          'Dumbbell',
        ),
        'push_up': ('repdb_push-up', 'Push-Up', 'Bodyweight'),
        'reverse_lunge': ('repdb_reverse-lunge', 'Reverse Lunge', 'Dumbbell'),
        'calf_raise': (
          'repdb_dumbbell-calf-raise',
          'Dumbbell Calf Raise',
          'Dumbbell',
        ),
      };

      for (final entry in expected.entries) {
        expect(exerciseKey(entry.key, name: 'My saved name'), entry.value.$1);
        final definition = definitionForExercise(entry.key);
        expect(definition?.id, entry.value.$1);
        expect(definition?.name, entry.value.$2);
        expect(definition?.equipment, entry.value.$3);
        expect(exerciseKey(entry.value.$1), entry.value.$1);
      }
    });

    test('only recovered IDs can use exact known or catalogue names', () {
      const recovered = {
        'Barbell Squat': 'repdb_squat',
        'Seated Cable Row': 'repdb_seated-cable-row',
        'Push-Up': 'repdb_push-up',
        'dUmBbElL gObLeT sQuAt': 'repdb_db-goblet-squat',
        'Goblet Squat': 'repdb_db-goblet-squat',
        'Standing Calf Raise': 'repdb_dumbbell-calf-raise',
      };
      for (final entry in recovered.entries) {
        expect(exerciseKey('csv-recovered-42', name: entry.key), entry.value);
        expect(
          definitionForExercise('csv-recovered-42', name: entry.key)?.id,
          entry.value,
        );
      }

      expect(
        exerciseKey('custom_squat', name: 'Barbell Squat'),
        'custom_squat',
      );
      expect(exerciseKey('wger_83', name: 'Seated Cable Row'), 'wger_83');
      expect(
        exerciseKey('csv-recovered-42', name: 'Barbell Squat variant'),
        'csv-recovered-42',
      );
      expect(
        exerciseKey('csv-recovered-42', name: 'SeatedCableRow'),
        'csv-recovered-42',
      );
      expect(
        exerciseKey('csv-recovered-42', name: 'Push Up'),
        'csv-recovered-42',
      );
      expect(
        definitionForExercise('custom_squat', name: 'Barbell Squat'),
        isNull,
      );
      expect(definitionForExercise('csv-recovered-unknown'), isNull);
      expect(exerciseKey('repdb_goblet-squat'), 'repdb_goblet-squat');
      expect(
        definitionForExercise('repdb_goblet-squat')?.equipment,
        'Kettlebell',
      );
    });
  });

  group('saved exercise performance', () {
    test('merges repeated movement entries and counts completed sets once', () {
      final session = workout('legs', 2, [
        exercise('old-entry', 'squat', 'Old squat name', [
          set('warmup', 8, 200, completed: false),
          set('first', 8, 40),
          set('second', 5, 50),
        ]),
        exercise('other-movement', 'repdb_deadlift', 'Barbell Deadlift', [
          set('deadlift', 4, 100),
        ]),
        exercise('new-entry', 'repdb_squat', 'Barbell Back Squat', [
          set('third', 3, 60),
          set('unchecked', 20, 500, completed: false),
        ]),
      ]);

      final performance = ExercisePerformance([session]);
      final point = performance.sessionsFor('squat').single;
      expect(point.workoutId, 'legs');
      expect(point.workoutName, 'Workout legs');
      expect(point.startedAt, DateTime.utc(2026, 11, 2, 9));
      expect(point.exerciseKey, 'repdb_squat');
      expect(point.exerciseName, 'Barbell Back Squat');
      expect(point.sets.map((value) => value.id), ['first', 'second', 'third']);
      expect(point.topWeightKg, 60);
      expect(point.volumeKg, 750); // 8×40 + 5×50 + 3×60.
      expect(point.reps, 16);
      expect(point.completedSets, 3);
      final trend = performance.exercises.singleWhere(
        (value) => value.key == 'repdb_squat',
      );
      expect(trend.name, 'Barbell Back Squat');
      expect(trend.bestWeightKg, 60);
      expect(trend.sessions.single, same(point));
      expect(performance.exercises.length, 2);
    });

    test('ignores unfinished workouts and entries with no completed sets', () {
      final performance = ExercisePerformance([
        workout('unfinished', 3, [
          exercise('draft', 'squat', 'Barbell Squat', [
            set('draft-set', 1, 200),
          ]),
        ], finished: false),
        workout('unchecked', 2, [
          exercise('entry', 'squat', 'Barbell Squat', [
            set('unchecked-set', 1, 150, completed: false),
          ]),
        ]),
        workout('empty', 1, [
          exercise('empty-entry', 'push_up', 'Push-Up', []),
        ]),
      ]);

      expect(performance.exercises, isEmpty);
      expect(performance.sessionsFor('squat'), isEmpty);
      expect(ExercisePerformance([]).sessionsFor('unknown'), isEmpty);
    });

    test('orders dates and resolves same-date ties by workout ID', () {
      final a = workout('a', 3, [
        exercise('entry-a', 'squat', 'Barbell Squat', [set('a', 3, 60)]),
      ]);
      final b = workout('b', 3, [
        exercise('entry-b', 'repdb_squat', 'Saved squat', [set('b', 2, 70)]),
      ]);
      final early = workout('early', 1, [
        exercise('entry-early', 'squat', 'Old squat', [set('early', 8, 40)]),
      ]);
      final performance = ExercisePerformance([b, early, a]);

      expect(performance.sessionsFor('squat').map((point) => point.workoutId), [
        'early',
        'a',
        'b',
      ]);
      expect(
        performance.exercises.single.sessions.map((point) => point.workoutId),
        ['early', 'a', 'b'],
      );
      expect(performance.exercises.single.bestWeightKg, 70);
      expect(
        ExercisePerformance([a, b, early])
            .sessionsFor('repdb_squat')
            .map((point) => point.workoutId),
        ['early', 'a', 'b'],
      );
    });

    test(
      'before is strict and workout exclusion does not discard other dates',
      () {
        final performance = ExercisePerformance([
          for (final day in [4, 2, 3, 1])
            workout('day-$day', day, [
              exercise('entry-$day', 'squat', 'Barbell Squat', [
                set('set-$day', 5, 40.0 + day),
              ]),
            ]),
        ]);

        expect(
          performance
              .sessionsFor(
                'repdb_squat',
                before: DateTime.utc(2026, 11, 3, 9),
                excludingWorkoutId: 'day-1',
              )
              .map((point) => point.workoutId),
          ['day-2'],
        );
        expect(
          performance
              .sessionsFor('squat', excludingWorkoutId: 'day-3')
              .map((point) => point.workoutId),
          ['day-1', 'day-2', 'day-4'],
        );
      },
    );

    test('previous excludes self, same-start sessions and future workouts', () {
      final currentExercise = exercise('current-entry', 'squat', 'My squat', [
        set('current-set', 2, 80),
      ]);
      final current = workout('current', 3, [currentExercise]);
      final performance = ExercisePerformance([
        workout('future', 4, [
          exercise('future-entry', 'repdb_squat', 'Squat', [
            set('future', 2, 90),
          ]),
        ]),
        workout('same-time', 3, [
          exercise('same-entry', 'repdb_squat', 'Squat', [set('same', 2, 85)]),
        ]),
        current,
        // Even a stale copy of the current ID cannot compare against itself.
        workout('current', 2, [
          exercise('stale-entry', 'squat', 'Squat', [set('stale', 2, 75)]),
        ]),
        workout('previous', 1, [
          exercise('previous-entry', 'repdb_squat', 'Squat', [
            set('previous', 5, 50),
          ]),
        ]),
      ]);

      final previous = performance.previousFor(current, currentExercise)!;
      expect(previous.workoutId, 'previous');
      expect(previous.topWeightKg, 50);
      expect(previous.reps, 5);
      expect(previous.volumeKg, 250);
      expect(
        performance.previousFor(
          workout('first', 1, [currentExercise], finished: false),
          currentExercise,
        ),
        isNull,
      );
    });

    test('recovered workouts participate in the correct canonical history', () {
      final performance = ExercisePerformance([
        workout('recovered', 1, [
          exercise('csv-squat', 'csv-recovered-1', 'Barbell Squat', [
            set('squat-set', 5, 50),
          ]),
          exercise('csv-row', 'csv-recovered-2', 'Seated Cable Row', [
            set('row-set', 10, 35),
          ]),
          exercise('csv-push', 'csv-recovered-3', 'Push-Up', [
            set('push-set', 12, 0),
          ]),
        ]),
      ]);
      final nextExercise = exercise(
        'next',
        'repdb_squat',
        'Barbell Back Squat',
        [],
      );

      expect(
        performance
            .previousFor(
              workout('next', 2, [nextExercise], finished: false),
              nextExercise,
            )
            ?.workoutId,
        'recovered',
      );
      expect(performance.sessionsFor('seated_cable_row').single.volumeKg, 350);
      expect(performance.sessionsFor('push_up').single.reps, 12);
      expect(performance.sessionsFor('push_up').single.topWeightKg, 0);
      expect(performance.sessionsFor('push_up').single.volumeKg, 0);
      expect(performance.sessionsFor('push_up').single.completedSets, 1);
    });

    test(
      'custom identities and dumbbell or kettlebell variants stay distinct',
      () {
        final performance = ExercisePerformance([
          workout('mixed', 1, [
            for (final entry in [
              ('goblet_squat', 'Goblet Squat', 20.0),
              ('repdb_goblet-squat', 'Goblet Squat', 24.0),
              ('custom-one', 'Goblet Squat', 30.0),
              ('custom-two', 'Goblet Squat', 40.0),
            ])
              exercise(entry.$1, entry.$1, entry.$2, [
                set(entry.$1, 10, entry.$3),
              ]),
          ]),
        ]);

        expect(performance.exercises.length, 4);
        expect(performance.sessionsFor('goblet_squat').single.topWeightKg, 20);
        expect(
          performance.sessionsFor('repdb_goblet-squat').single.topWeightKg,
          24,
        );
        expect(performance.sessionsFor('custom-one').single.topWeightKg, 30);
        expect(performance.sessionsFor('custom-two').single.topWeightKg, 40);
        expect(
          performance.sessionsFor('unknown', name: 'Goblet Squat'),
          isEmpty,
        );
      },
    );

    test('unknown movement uses its chronologically first saved name', () {
      final performance = ExercisePerformance([
        workout('late', 3, [
          exercise('new-name', 'custom-carry', 'Renamed carry', [
            set('late', 3, 30),
          ]),
        ]),
        workout('early', 1, [
          exercise('original', 'custom-carry', 'My original carry', [
            set('early', 5, 20),
          ]),
        ]),
      ]);

      expect(performance.exercises.single.name, 'My original carry');
      expect(
        performance
            .sessionsFor('custom-carry')
            .map((point) => point.exerciseName),
        ['My original carry', 'My original carry'],
      );
    });

    test('a new derivation reflects edits and deletions without changing snapshots', () {
      final original = workout('saved', 1, [
        exercise('entry', 'squat', 'Saved squat', [set('saved-set', 5, 50)]),
      ]);
      final originalPerformance = ExercisePerformance([original]);
      final edited = original.copyWith(
        exercises: [
          original.exercises.single.copyWith(
            sets: [
              original.exercises.single.sets.single.copyWith(weightKg: 62.5),
            ],
          ),
        ],
      );

      expect(ExercisePerformance([edited]).exercises.single.bestWeightKg, 62.5);
      expect(
        ExercisePerformance([edited]).sessionsFor('squat').single.volumeKg,
        312.5,
      );
      expect(ExercisePerformance([]).exercises, isEmpty);
      expect(originalPerformance.exercises.single.bestWeightKg, 50);
      expect(original.exercises.single.sets.single.weightKg, 50);
    });

    test('derived collections cannot be mutated by consumers', () {
      final history = [
        workout('saved', 1, [
          exercise('entry', 'squat', 'Squat', [set('set', 5, 50)]),
        ]),
      ];
      final performance = ExercisePerformance(history);
      history.clear();

      expect(performance.exercises.length, 1);
      expect(() => performance.exercises.clear(), throwsUnsupportedError);
      expect(
        () => performance.exercises.single.sessions.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => performance.sessionsFor('squat').clear(),
        throwsUnsupportedError,
      );
      expect(
        () => performance.sessionsFor('squat').single.sets.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => performance.sessionsFor('unknown').clear(),
        throwsUnsupportedError,
      );
    });
  });
}

WorkoutSet set(String id, int reps, double weight, {bool completed = true}) =>
    WorkoutSet(id: id, reps: reps, weightKg: weight, isCompleted: completed);

WorkoutExercise exercise(
  String id,
  String exerciseId,
  String name,
  List<WorkoutSet> sets,
) => WorkoutExercise(id: id, exerciseId: exerciseId, name: name, sets: sets);

WorkoutSession workout(
  String id,
  int day,
  List<WorkoutExercise> exercises, {
  bool finished = true,
}) => WorkoutSession(
  id: id,
  name: 'Workout $id',
  startedAt: DateTime.utc(2026, 11, day, 9),
  finishedAt: finished ? DateTime.utc(2026, 11, day, 10) : null,
  exercises: exercises,
);
