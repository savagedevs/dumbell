import 'package:get/get.dart';

import '../../app/workout_controller.dart';
import '../../data/workout_activity.dart';

class WorkoutCalendarController extends GetxController {
  WorkoutCalendarController(this.workouts)
    : today = workoutDay(workouts.now.value).obs,
      selectedDate = workoutDay(workouts.now.value).obs,
      month = DateTime(
        workouts.now.value.toLocal().year,
        workouts.now.value.toLocal().month,
      ).obs {
    _clockWorker = ever(workouts.now, (now) {
      final next = workoutDay(now);
      final previous = today.value;
      if (next == previous) return;
      today.value = next;
      if (selectedDate.value == previous) selectDate(next);
    });
  }

  final WorkoutController workouts;
  final Rx<DateTime> today, selectedDate, month;
  late final Worker _clockWorker;

  WorkoutActivity get activity => WorkoutActivity(workouts.history);
  int get daysInMonth =>
      DateTime(month.value.year, month.value.month + 1, 0).day;

  void changeMonth(int delta) {
    final next = DateTime(month.value.year, month.value.month + delta);
    month.value = next;
    selectedDate.value = next;
  }

  void selectDate(DateTime date) {
    final day = workoutDay(date);
    month.value = DateTime(day.year, day.month);
    selectedDate.value = day;
  }

  void goToToday() => selectDate(today.value);

  @override
  void onClose() {
    _clockWorker.dispose();
    super.onClose();
  }
}
