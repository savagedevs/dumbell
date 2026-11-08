import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'live_workout_snapshot.dart';

abstract interface class LiveWorkoutPlatform {
  bool get supported;
  void setOpenWorkoutHandler(VoidCallback? handler);
  Future<void> updateWorkout(LiveWorkoutSnapshot snapshot);
  Future<bool> getLaunchAction();
  Future<bool> notificationsEnabled();
  Future<bool> requestNotifications();
  Future<bool> requestPinWidget();
}

class AndroidLiveWorkoutPlatform implements LiveWorkoutPlatform {
  AndroidLiveWorkoutPlatform({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('liftlog/live_workout');

  final MethodChannel _channel;

  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void setOpenWorkoutHandler(VoidCallback? handler) {
    if (!supported) return;
    _channel.setMethodCallHandler(
      handler == null
          ? null
          : (call) async {
              if (call.method == 'openWorkout') handler();
            },
    );
  }

  @override
  Future<void> updateWorkout(LiveWorkoutSnapshot snapshot) =>
      _channel.invokeMethod<void>('updateWorkout', snapshot.toMap());
  Future<bool> _flag(String method) async =>
      await _channel.invokeMethod<bool>(method) ?? false;
  @override
  Future<bool> getLaunchAction() => _flag('getLaunchAction');
  @override
  Future<bool> notificationsEnabled() => _flag('notificationsEnabled');
  @override
  Future<bool> requestNotifications() => _flag('requestNotifications');
  @override
  Future<bool> requestPinWidget() => _flag('requestPinWidget');
}
