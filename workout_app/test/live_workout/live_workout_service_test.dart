import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workout_app/app/workout_controller.dart';
import 'package:workout_app/data/models.dart';
import 'package:workout_app/features/live_workout/live_workout_platform.dart';
import 'package:workout_app/features/live_workout/live_workout_service.dart';
import 'package:workout_app/features/live_workout/live_workout_snapshot.dart';

import '../support/memory_repository.dart';

class FakePlatform implements LiveWorkoutPlatform {
  @override
  bool supported = true;
  bool permission = false;
  bool launch = false;
  void Function()? open;
  final snapshots = <LiveWorkoutSnapshot>[];
  Completer<void>? gate;
  @override
  void setOpenWorkoutHandler(void Function()? handler) => open = handler;
  @override
  Future<void> updateWorkout(LiveWorkoutSnapshot snapshot) async {
    await gate?.future;
    snapshots.add(snapshot);
  }

  @override
  Future<bool> getLaunchAction() async => launch;
  @override
  Future<bool> notificationsEnabled() async => permission;
  @override
  Future<bool> requestNotifications() async => permission;
  @override
  Future<bool> requestPinWidget() async => false;
}

AppData records({bool named = true}) => AppData(
  onboardingCompleted: true,
  profile: named
      ? UserProfile(
          name: 'Asha Sharma',
          goal: 'Build strength',
          experience: 'Beginner',
        )
      : null,
  activeWorkout: WorkoutSession(
    id: 'session',
    name: 'Strength',
    startedAt: DateTime.utc(2026, 11, 8, 12),
    exercises: [
      WorkoutExercise(
        id: 'entry',
        exerciseId: 'repdb_squat',
        name: 'Barbell Back Squat',
        sets: [WorkoutSet(id: 'set', reps: 8, weightKg: 40)],
      ),
    ],
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => Get.testMode = true);
  tearDown(() => Get.reset());

  test('live display uses the saved start and focused exercise without per-second writes', () async {
    final repository = MemoryRepository()..value = records();
    final workouts = WorkoutController(repository, repository.value);
    final platform = FakePlatform();
    final service = LiveWorkoutService(
      workouts,
      platform: platform,
      onOpenWorkout: () {},
    );
    await service.initialize();
    expect(platform.snapshots.last.toMap(), {
      'active': true,
      'workoutId': 'session',
      'workoutName': 'Strength',
      'startedAtMs': DateTime.utc(2026, 11, 8, 12).millisecondsSinceEpoch,
      'exerciseName': 'Barbell Back Squat',
      'exerciseAsset': 'assets/exercises/repdb/flat/squat-start.webp',
      'completedSets': 0,
      'totalSets': 1,
    });
    final calls = platform.snapshots.length;
    workouts.now.value = DateTime.utc(2026, 11, 8, 12, 10);
    await service.flush();
    expect(platform.snapshots.length, calls);
    expect(repository.writes, 0);
    service.onClose();
  });

  test(
    'a pending older update is followed by the final cleared workout state',
    () async {
      final repository = MemoryRepository()..value = records();
      final workouts = WorkoutController(repository, repository.value);
      final platform = FakePlatform()..gate = Completer<void>();
      final service = LiveWorkoutService(
        workouts,
        platform: platform,
        onOpenWorkout: () {},
      );
      final initialization = service.initialize();
      await Future<void>.delayed(Duration.zero);
      expect(await workouts.discardWorkout(), isTrue);
      platform.gate!.complete();
      await initialization;
      await service.flush();
      expect(platform.snapshots.last.toMap()['workoutId'], isNull);
      expect(platform.snapshots.last.toMap()['active'], isFalse);
      expect(repository.value.activeWorkout, isNull);
      service.onClose();
    },
  );

  test('notification denial and an unsupported launcher never affect saved workouts', () async {
    final repository = MemoryRepository()..value = records();
    final workouts = WorkoutController(repository, repository.value);
    final platform = FakePlatform();
    final service = LiveWorkoutService(
      workouts,
      platform: platform,
      onOpenWorkout: () {},
    );
    await service.initialize();
    await service.enableNotifications();
    expect(service.notificationsAllowed.value, isFalse);
    await service.addHomeWidget();
    expect(service.message.value, contains('Widgets'));
    expect(repository.writes, 0);
    expect(repository.value.activeWorkout!.id, 'session');
    service.onClose();
  });

  test(
    'cold launch waits for routing and required Name, then opens once',
    () async {
      final repository = MemoryRepository()..value = records(named: false);
      final workouts = WorkoutController(repository, repository.value);
      final platform = FakePlatform()..launch = true;
      var opened = 0;
      final service = LiveWorkoutService(
        workouts,
        platform: platform,
        onOpenWorkout: () => opened++,
      );
      await service.initialize();
      service.markNavigationReady();
      await Future<void>.delayed(Duration.zero);
      expect(opened, 0);
      expect(
        await workouts.saveProfile(
          UserProfile(
            name: 'Asha',
            goal: 'Build strength',
            experience: 'Beginner',
          ),
          unit: WeightUnit.kg,
        ),
        isTrue,
      );
      await service.flush();
      await Future<void>.delayed(Duration.zero);
      expect(opened, 1);
      service.markNavigationReady();
      await Future<void>.delayed(Duration.zero);
      expect(opened, 1);
      service.onClose();
    },
  );

  test('unsupported platforms do not invoke a native bridge', () async {
    final platform = FakePlatform()..supported = false;
    final service = LiveWorkoutService(
      WorkoutController(MemoryRepository(), AppData()),
      platform: platform,
      onOpenWorkout: () {},
    );
    await service.initialize();
    expect(platform.snapshots, isEmpty);
    service.onClose();
  });

  test(
    'returning to the previous exercise wins over a pending native update',
    () async {
      final initial = records();
      final draft = initial.activeWorkout!;
      final repository = MemoryRepository()
        ..value = initial.copyWith(
          activeWorkout: draft.copyWith(
            exercises: [
              ...draft.exercises,
              WorkoutExercise(
                id: 'second',
                exerciseId: 'repdb_bench-press',
                name: 'Barbell Bench Press',
                sets: [WorkoutSet(id: 'second-set', reps: 8, weightKg: 40)],
              ),
            ],
          ),
        );
      final workouts = WorkoutController(repository, repository.value);
      final platform = FakePlatform();
      final service = LiveWorkoutService(
        workouts,
        platform: platform,
        onOpenWorkout: () {},
      );
      await service.initialize();
      expect(platform.snapshots.last.exerciseName, 'Barbell Back Squat');
      platform.gate = Completer<void>();
      workouts.focusExercise('second');
      workouts.focusExercise('entry');
      platform.gate!.complete();
      await service.flush();
      expect(platform.snapshots.last.exerciseName, 'Barbell Back Squat');
      service.onClose();
    },
  );
}
