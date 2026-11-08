import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/features/live_workout/live_workout_platform.dart';
import 'package:workout_app/features/live_workout/live_workout_snapshot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('liftlog/live_workout');
  final calls = <MethodCall>[];
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'updateWorkout' ? null : true;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    channel.setMethodCallHandler(null);
  });
  test('Android bridge publishes one complete snapshot and uses the native capability methods', () async {
    final platform = AndroidLiveWorkoutPlatform();
    const snapshot = LiveWorkoutSnapshot(
      active: true,
      workoutId: 'workout',
      workoutName: 'Push day',
      startedAtMs: 1234567890,
      exerciseName: 'Bench Press',
      completedSets: 2,
      totalSets: 6,
    );
    expect(platform.supported, isTrue);
    await platform.updateWorkout(snapshot);
    expect(calls.single.method, 'updateWorkout');
    expect(calls.single.arguments, {
      'active': true,
      'workoutId': 'workout',
      'workoutName': 'Push day',
      'startedAtMs': 1234567890,
      'exerciseName': 'Bench Press',
      'exerciseAsset': null,
      'completedSets': 2,
      'totalSets': 6,
    });
    expect(await platform.getLaunchAction(), isTrue);
    expect(await platform.notificationsEnabled(), isTrue);
    expect(await platform.requestNotifications(), isTrue);
    expect(await platform.requestPinWidget(), isTrue);
    expect(calls.skip(1).map((c) => c.method), [
      'getLaunchAction',
      'notificationsEnabled',
      'requestNotifications',
      'requestPinWidget',
    ]);
  });
}
