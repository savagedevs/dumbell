import 'package:workout_app/features/live_workout/live_workout_platform.dart';
import 'package:workout_app/features/live_workout/live_workout_snapshot.dart';

class NoLivePlatform implements LiveWorkoutPlatform {
  @override
  bool get supported => false;
  @override
  void setOpenWorkoutHandler(void Function()? handler) {}
  @override
  Future<void> updateWorkout(LiveWorkoutSnapshot snapshot) async {}
  @override
  Future<bool> getLaunchAction() async => false;
  @override
  Future<bool> notificationsEnabled() async => false;
  @override
  Future<bool> requestNotifications() async => false;
  @override
  Future<bool> requestPinWidget() async => false;
}
