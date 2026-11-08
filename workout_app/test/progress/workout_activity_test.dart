import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/app/workout_controller.dart';
import 'package:workout_app/data/models.dart';
import 'package:workout_app/data/workout_activity.dart';
import 'package:workout_app/features/progress/workout_calendar_controller.dart';

import '../support/memory_repository.dart';

WorkoutSession activitySession(
  String id,
  DateTime start, {
  bool saved = true,
  bool completed = true,
}) => WorkoutSession(
  id: id,
  name: id,
  startedAt: start,
  finishedAt: saved ? start.add(const Duration(minutes: 30)) : null,
  exercises: [
    WorkoutExercise(
      id: '$id-exercise',
      exerciseId: 'repdb_squat',
      name: 'Squat',
      sets: [
        WorkoutSet(
          id: '$id-set',
          reps: 8,
          weightKg: 10,
          isCompleted: completed,
        ),
      ],
    ),
  ],
);

void main() {
  test('activity distinguishes workouts from training days and excludes unfinished work', () {
    final sessions = [
      activitySession('evening', DateTime(2026, 11, 3, 18)),
      activitySession('morning', DateTime(2026, 11, 3, 9)),
      activitySession('sunday', DateTime(2026, 11, 8, 10)),
      activitySession('draft', DateTime(2026, 11, 4), saved: false),
      activitySession('empty-archive', DateTime(2026, 11, 5), completed: false),
    ];
    final original = sessions.map((s) => s.toJson()).toList();
    final activity = WorkoutActivity(sessions);
    expect(activity.onDay(DateTime(2026, 11, 3)).map((s) => s.id), [
      'morning',
      'evening',
    ]);
    expect(activity.onDay(DateTime(2026, 11, 4)), isEmpty);
    expect(activity.inMonth(DateTime(2026, 11)).length, 3);
    expect(activity.trainingDaysInMonth(DateTime(2026, 11)), 2);
    expect(sessions.map((s) => s.toJson()).toList(), original);
    expect(
      () => activity.onDay(DateTime(2026, 11, 3)).clear(),
      throwsUnsupportedError,
    );
  });

  test('activity groups local dates across month and year boundaries', () {
    final activity = WorkoutActivity([
      activitySession('october', DateTime(2026, 10, 31, 23, 59)),
      activitySession('november', DateTime(2026, 11, 1)),
      activitySession('december', DateTime(2026, 12, 31, 23, 59)),
      activitySession('january', DateTime(2027, 1, 1)),
    ]);
    expect(activity.inMonth(DateTime(2026, 10)).map((s) => s.id), ['october']);
    expect(activity.onDay(DateTime(2026, 11, 1, 16)).single.id, 'november');
    expect(activity.inMonth(DateTime(2026, 12)).single.id, 'december');
    expect(activity.inMonth(DateTime(2027, 1)).single.id, 'january');
  });

  test('UTC-stored workouts are assigned to their local calendar date', () {
    final activity = WorkoutActivity([
      activitySession('local-midnight', DateTime(2026, 10, 25, 0, 30).toUtc()),
    ]);
    expect(activity.onDay(DateTime(2026, 10, 25)).single.id, 'local-midnight');
    expect(activity.onDay(DateTime(2026, 10, 24)), isEmpty);
  });

  test(
    'weekly counts use Monday through Sunday and do not count later weeks',
    () {
      final activity = WorkoutActivity([
        activitySession('previous-sunday', DateTime(2026, 11, 1, 23, 59)),
        activitySession('monday', DateTime(2026, 11, 2)),
        activitySession('sunday', DateTime(2026, 11, 8, 23, 59)),
        activitySession('next-monday', DateTime(2026, 11, 9)),
      ]);
      final weeks = activity.recentWeeks(DateTime(2026, 11, 8));
      expect(weeks, hasLength(8));
      expect(weeks.first.startedAt, DateTime(2026, 9, 14));
      expect(weeks.last.startedAt, DateTime(2026, 11, 2));
      expect(weeks.last.workouts, 2);
      expect(weeks[6].workouts, 1);
    },
  );

  test('calendar month changes handle leap years and year rollover', () {
    final workouts = WorkoutController(
      MemoryRepository(),
      AppData(),
      clock: () => DateTime(2024, 3, 31),
    );
    final calendar = WorkoutCalendarController(workouts);
    calendar.changeMonth(-1);
    expect(calendar.month.value, DateTime(2024, 2));
    expect(calendar.selectedDate.value, DateTime(2024, 2, 1));
    expect(calendar.daysInMonth, 29);
    calendar.selectDate(DateTime(2023, 12, 31));
    calendar.changeMonth(1);
    expect(calendar.month.value, DateTime(2024, 1));
    calendar.goToToday();
    expect(calendar.selectedDate.value, DateTime(2024, 3, 31));
    calendar.onClose();
  });

  test(
    'calendar updates Today at midnight without moving a historical selection',
    () {
      final workouts = WorkoutController(
        MemoryRepository(),
        AppData(),
        clock: () => DateTime(2026, 11, 30, 23, 59),
      );
      final calendar = WorkoutCalendarController(workouts);
      final day = calendar.today.value;
      workouts.now.value = DateTime(2026, 11, 30, 23, 59, 30);
      expect(identical(calendar.today.value, day), isTrue);
      workouts.now.value = DateTime(2026, 12, 1);
      expect(calendar.today.value, DateTime(2026, 12, 1));
      expect(calendar.selectedDate.value, DateTime(2026, 12, 1));
      calendar.selectDate(DateTime(2026, 10, 12));
      workouts.now.value = DateTime(2026, 12, 2);
      expect(calendar.selectedDate.value, DateTime(2026, 10, 12));
      calendar.onClose();
      workouts.now.value = DateTime(2026, 12, 3);
      expect(calendar.today.value, DateTime(2026, 12, 2));
    },
  );
}
