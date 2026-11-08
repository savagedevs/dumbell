import 'package:workout_app/data/models.dart';

AppData exercisePrefillFixture({WeightUnit unit = WeightUnit.kg}) => AppData(
  unit: unit,
  activeWorkout: WorkoutSession(
    id: 'current',
    name: 'Today',
    startedAt: DateTime(2026, 11, 8, 12),
    exercises: [],
  ),
  history: [
    WorkoutSession(
      id: 'future',
      name: 'Future',
      startedAt: DateTime(2026, 11, 9),
      finishedAt: DateTime(2026, 11, 9, 1),
      exercises: [
        WorkoutExercise(
          id: 'future-entry',
          exerciseId: 'repdb_squat',
          name: 'Barbell Back Squat',
          sets: [
            WorkoutSet(
              id: 'future-set',
              reps: 99,
              weightKg: 999,
              isCompleted: true,
            ),
          ],
        ),
      ],
    ),
    WorkoutSession(
      id: 'previous',
      name: 'Previous',
      startedAt: DateTime(2026, 11, 7, 12),
      finishedAt: DateTime(2026, 11, 7, 13),
      exercises: [
        WorkoutExercise(
          id: 'previous-entry',
          exerciseId: 'squat',
          name: 'Barbell Squat',
          sets: [
            WorkoutSet(
              id: 'previous-first',
              reps: 10,
              weightKg: 40.125,
              isCompleted: true,
            ),
            WorkoutSet(id: 'previous-unfinished', reps: 50, weightKg: 99),
          ],
        ),
        WorkoutExercise(
          id: 'repeated-entry',
          exerciseId: 'repdb_squat',
          name: 'Barbell Back Squat',
          sets: [
            WorkoutSet(
              id: 'previous-second',
              reps: 6,
              weightKg: 45.5,
              isCompleted: true,
            ),
          ],
        ),
      ],
    ),
    WorkoutSession(
      id: 'unfinished',
      name: 'Unfinished',
      startedAt: DateTime(2026, 11, 8, 11),
      exercises: [
        WorkoutExercise(
          id: 'unfinished-entry',
          exerciseId: 'repdb_squat',
          name: 'Barbell Back Squat',
          sets: [
            WorkoutSet(
              id: 'unfinished-set',
              reps: 12,
              weightKg: 90,
              isCompleted: true,
            ),
          ],
        ),
      ],
    ),
  ],
);
