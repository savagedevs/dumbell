import 'models.dart';

DateTime workoutDay(DateTime instant) {
  final local = instant.toLocal();
  return DateTime(local.year, local.month, local.day);
}

class WorkoutWeekActivity {
  const WorkoutWeekActivity({required this.startedAt, required this.workouts});
  final DateTime startedAt;
  final int workouts;
}

/// Calendar activity counts saved work with completed sets, never drafts or
/// empty archives. A training day can contain more than one workout.
class WorkoutActivity {
  WorkoutActivity(Iterable<WorkoutSession> history) {
    final eligible =
        history
            .where(
              (session) =>
                  session.finishedAt != null && session.completedSets > 0,
            )
            .toList()
          ..sort((a, b) {
            final time = a.startedAt.compareTo(b.startedAt);
            return time == 0 ? a.id.compareTo(b.id) : time;
          });
    sessions = List.unmodifiable(eligible);
    final days = <DateTime, List<WorkoutSession>>{};
    for (final session in eligible) {
      days.putIfAbsent(workoutDay(session.startedAt), () => []).add(session);
    }
    _byDay = Map.unmodifiable({
      for (final entry in days.entries)
        entry.key: List<WorkoutSession>.unmodifiable(entry.value),
    });
  }

  late final List<WorkoutSession> sessions;
  late final Map<DateTime, List<WorkoutSession>> _byDay;

  List<WorkoutSession> onDay(DateTime day) =>
      _byDay[workoutDay(day)] ?? const <WorkoutSession>[];

  List<WorkoutSession> inMonth(DateTime month) => List.unmodifiable(
    sessions.where((session) {
      final local = session.startedAt.toLocal();
      return local.year == month.year && local.month == month.month;
    }),
  );

  int trainingDaysInMonth(DateTime month) => _byDay.keys
      .where((day) => day.year == month.year && day.month == month.month)
      .length;

  List<WorkoutWeekActivity> recentWeeks(DateTime today) {
    final day = workoutDay(today);
    final monday = DateTime(day.year, day.month, day.day - day.weekday + 1);
    return List.unmodifiable(
      List.generate(8, (index) {
        // Calendar arithmetic preserves midnight across daylight-saving changes.
        final start = DateTime(
          monday.year,
          monday.month,
          monday.day - (7 - index) * 7,
        );
        final end = DateTime(start.year, start.month, start.day + 7);
        return WorkoutWeekActivity(
          startedAt: start,
          workouts: sessions.where((session) {
            final local = session.startedAt.toLocal();
            return !local.isBefore(start) && local.isBefore(end);
          }).length,
        );
      }),
    );
  }
}
