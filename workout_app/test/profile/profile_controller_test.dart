import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workout_app/app/workout_controller.dart';
import 'package:workout_app/data/models.dart';
import 'package:workout_app/features/profile/profile_controller.dart';

import '../support/memory_repository.dart';

class _DelayedRepository extends MemoryRepository {
  final gate = Completer<void>();

  @override
  Future<void> save(AppData data) async {
    await gate.future;
    await super.save(data);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => Get.testMode = true);
  tearDown(() => Get.reset());

  ProfileController form(
    MemoryRepository repository, {
    bool editing = false,
    void Function()? onFinished,
  }) {
    final workouts = WorkoutController(repository, repository.value);
    final profile = ProfileController(
      workouts,
      editing: editing,
      onFinished: onFinished ?? () {},
    );
    addTearDown(profile.onClose);
    return profile;
  }

  for (final name in ['', '  \t  ']) {
    test('a blank name never writes or continues: "$name"', () async {
      final repository = MemoryRepository();
      var finished = false;
      final profile = form(repository, onFinished: () => finished = true);
      profile.name.text = name;

      expect(await profile.save(), isFalse);
      expect(profile.error.value, 'Enter your name.');
      expect(profile.busy.value, isFalse);
      expect(repository.writes, 0);
      expect(repository.value.onboardingCompleted, isFalse);
      expect(repository.value.profile, isNull);
      expect(finished, isFalse);
    });
  }

  test(
    'a trimmed multiword name saves with the other details optional',
    () async {
      final repository = MemoryRepository();
      final profile = form(repository);
      profile.name.text = '  Karti Sharma  ';

      expect(await profile.save(), isTrue);
      expect(repository.value.onboardingCompleted, isTrue);
      expect(repository.value.profile!.name, 'Karti Sharma');
      expect(repository.value.profile!.goal, 'Stay consistent');
      expect(repository.value.profile!.experience, 'Beginner');
      expect(repository.value.bodyWeights, isEmpty);
      expect(repository.value.activeWorkout, isNull);
    },
  );

  test(
    'saving waits for storage before continuing and prevents double taps',
    () async {
      final repository = _DelayedRepository();
      var finished = 0;
      final profile = form(repository, onFinished: () => finished++);
      profile.name.text = '  Karti  ';
      profile.unit.value = WeightUnit.lb;
      profile.startingWeight.text = '220.46226218';
      final saving = profile.save();
      expect(profile.busy.value, isTrue);
      expect(finished, 0);
      expect(repository.value.profile, isNull);
      expect(await profile.save(), isFalse);
      repository.gate.complete();
      expect(await saving, isTrue);
      expect(finished, 1);
      expect(repository.value.profile!.name, 'Karti');
      expect(repository.value.unit, WeightUnit.lb);
      expect(
        repository.value.bodyWeights.single.weightKg,
        closeTo(100, 0.0001),
      );
    },
  );

  test('failed save retains form and does not continue', () async {
    final repository = MemoryRepository()..failWrites = true;
    var finished = false;
    final profile = form(repository, onFinished: () => finished = true);
    profile.name.text = 'Karti';
    expect(await profile.save(), isFalse);
    expect(profile.error.value, contains('Could not save'));
    expect(profile.name.text, 'Karti');
    expect(finished, isFalse);
    expect(repository.value.onboardingCompleted, isFalse);
    expect(finished, isFalse);
    expect(profile.busy.value, isFalse);
  });

  test('invalid optional fields never write', () async {
    final repository = MemoryRepository();
    final profile = form(repository);
    profile.name.text = 'Karti';
    for (final value in ['0', '-3', 'NaN', 'Infinity', '1001', 'abc']) {
      profile.startingWeight.text = value;
      expect(await profile.save(), isFalse, reason: value);
    }
    profile.startingWeight.clear();
    profile.name.text = 'a' * 51;
    expect(await profile.save(), isFalse);
    expect(repository.writes, 0);
  });

  test('a name of 50 characters is accepted after trimming', () async {
    final repository = MemoryRepository();
    final profile = form(repository);
    profile.name.text = '  ${'a' * 50}  ';

    expect(await profile.save(), isTrue);
    expect(repository.value.profile!.name, 'a' * 50);
  });

  test(
    'editing preloads details and cannot seed another initial body weight',
    () async {
      final entry = BodyWeightEntry(
        id: 'initial',
        measuredAt: DateTime(2026, 11, 8),
        weightKg: 80,
      );
      final repository = MemoryRepository()
        ..value = AppData(
          onboardingCompleted: true,
          profile: UserProfile(
            name: 'Karti',
            goal: 'Build strength',
            experience: 'Intermediate',
          ),
          bodyWeights: [entry],
        );
      final profile = form(repository, editing: true);
      expect(profile.name.text, 'Karti');
      expect(profile.goal.value, 'Build strength');
      expect(profile.experience.value, 'Intermediate');
      profile.name.text = '   ';
      expect(await profile.save(), isFalse);
      expect(profile.error.value, 'Enter your name.');
      expect(repository.writes, 0);
      expect(repository.value.profile!.name, 'Karti');
      profile.name.text = 'New name';
      profile.startingWeight.text = 'Invalid and ignored during edit';
      profile.unit.value = WeightUnit.lb;
      expect(await profile.save(), isTrue);
      expect(repository.value.bodyWeights.single.weightKg, 80);
      expect(repository.value.bodyWeights.single.id, 'initial');
      expect(repository.value.profile!.name, 'New name');
      expect(repository.value.unit, WeightUnit.lb);
    },
  );
}
