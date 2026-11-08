import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workout_app/app/workout_controller.dart';
import 'package:workout_app/data/models.dart';

import '../support/memory_repository.dart';

void main() {
  setUp(() => Get.testMode = true);

  test(
    'import rejects global and nested ID collisions before any write',
    () async {
      final repository = MemoryRepository();
      final current = AppData(
        history: [
          WorkoutSession(
            id: 'saved',
            name: 'Existing',
            startedAt: DateTime.utc(2026, 1, 1),
            finishedAt: DateTime.utc(2026, 1, 1, 1),
            exercises: [
              WorkoutExercise(
                id: 'exercise',
                exerciseId: 'squat',
                name: 'Squat',
                sets: [WorkoutSet(id: 'set', reps: 8, weightKg: 50)],
              ),
            ],
          ),
        ],
      );
      final controller = WorkoutController(repository, current);
      final collision = AppData(
        bodyWeights: [
          BodyWeightEntry(
            id: 'saved',
            measuredAt: DateTime.utc(2026, 1, 1),
            weightKg: 80,
          ),
        ],
      );
      expect(await controller.importData(collision), isFalse);
      expect(repository.writes, 0);
      expect(identical(controller.data.value, current), isTrue);
      final nested = AppData(
        history: [
          WorkoutSession(
            id: 'incoming',
            name: 'Imported',
            startedAt: DateTime.utc(2026, 2, 1),
            finishedAt: DateTime.utc(2026, 2, 1, 1),
            exercises: [
              WorkoutExercise(
                id: 'incoming-exercise',
                exerciseId: 'squat',
                name: 'Squat',
                sets: [WorkoutSet(id: 'set', reps: 12, weightKg: 20)],
              ),
            ],
          ),
        ],
      );
      expect(await controller.importData(nested), isFalse);
      expect(repository.writes, 0);
      expect(identical(controller.data.value, current), isTrue);
    },
  );

  test('profile and starting weight persist atomically only once', () async {
    final repository = MemoryRepository();
    final controller = WorkoutController(repository, AppData());
    final profile = UserProfile(
      name: '  Alex  ',
      goal: 'Build strength',
      experience: 'Beginner',
    );
    expect(
      await controller.saveProfile(
        profile,
        unit: WeightUnit.lb,
        startingWeight: 220.46226218,
      ),
      isTrue,
    );
    expect(controller.data.value.onboardingCompleted, isTrue);
    expect(repository.value.profile!.name, 'Alex');
    expect(repository.value.bodyWeights.single.weightKg, closeTo(100, .00001));
    expect(
      await controller.saveProfile(
        profile,
        unit: WeightUnit.kg,
        startingWeight: 80,
      ),
      isTrue,
    );
    expect(controller.bodyWeights.length, 1);
  });

  test('blank names cannot complete onboarding or write a profile', () async {
    final repository = MemoryRepository();
    final controller = WorkoutController(repository, AppData());
    expect(
      await controller.saveProfile(
        UserProfile(
          name: '   ',
          goal: 'Stay consistent',
          experience: 'Beginner',
        ),
        unit: WeightUnit.kg,
      ),
      isFalse,
    );
    expect(repository.value.onboardingCompleted, isFalse);
    expect(repository.value.profile, isNull);
    expect(repository.value.bodyWeights, isEmpty);
    expect(repository.writes, 0);
  });

  test(
    'failed profile save leaves initial onboarding and records intact',
    () async {
      final repository = MemoryRepository()..failWrites = true;
      final controller = WorkoutController(repository, AppData());
      final saved = await controller.saveProfile(
        UserProfile(name: 'Alex', goal: 'Build muscle', experience: 'Advanced'),
        unit: WeightUnit.kg,
        startingWeight: 80,
      );
      expect(saved, isFalse);
      expect(controller.data.value.onboardingCompleted, isFalse);
      expect(controller.bodyWeights, isEmpty);
      expect(controller.profile, isNull);
    },
  );

  test('import merges unique IDs while preserving draft, existing IDs and preferences', () async {
    final repository = MemoryRepository();
    final saved = WorkoutSession(
      id: 'saved',
      name: 'Existing',
      startedAt: DateTime.utc(2026, 1, 1),
      finishedAt: DateTime.utc(2026, 1, 1, 1),
      exercises: [],
    );
    final controller = WorkoutController(
      repository,
      AppData(history: [saved], unit: WeightUnit.lb, onboardingCompleted: true),
    );
    await controller.startWorkout();
    final draftId = controller.activeWorkout!.id;
    final incoming = WorkoutSession(
      id: 'incoming',
      name: 'Imported',
      startedAt: DateTime.utc(2026, 2, 1),
      finishedAt: DateTime.utc(2026, 2, 1, 1),
      exercises: [],
    );
    final backup = AppData(
      history: [
        saved.copyWith(name: 'Overwrite'),
        incoming,
      ],
      activeWorkout: WorkoutSession(
        id: 'other-draft',
        name: 'Other draft',
        startedAt: DateTime.utc(2026, 3, 1),
        exercises: [],
      ),
      bodyWeights: [
        BodyWeightEntry(
          id: 'body',
          measuredAt: DateTime.utc(2026, 2, 1),
          weightKg: 80,
        ),
      ],
    );
    expect(await controller.importData(backup), isTrue);
    expect(controller.history.length, 2);
    expect(controller.sessionById('saved')!.name, 'Existing');
    expect(controller.activeWorkout!.id, draftId);
    expect(controller.unit, WeightUnit.lb);
    expect(controller.data.value.onboardingCompleted, isTrue);
    await controller.importData(backup);
    expect(controller.history.length, 2);
    expect(controller.bodyWeights.length, 1);
  });

  test('restore imports a draft when no current draft exists', () async {
    final repository = MemoryRepository();
    final controller = WorkoutController(repository, AppData());
    final draft = WorkoutSession(
      id: 'draft',
      name: 'Resume me',
      startedAt: DateTime.utc(2026, 1, 1),
      exercises: [],
    );
    await controller.importData(AppData(activeWorkout: draft));
    expect(controller.activeWorkout!.id, 'draft');
  });

  test(
    'photo references persist and reject paths outside private storage',
    () async {
      final repository = MemoryRepository();
      final controller = WorkoutController(repository, AppData());
      await controller.startWorkout();
      final id = controller.activeWorkout!.id;
      expect(
        await controller.setWorkoutPhoto(id, 'workout_photos/abc.jpg'),
        isTrue,
      );
      expect(
        repository.value.activeWorkout!.photoPath,
        'workout_photos/abc.jpg',
      );
      for (final path in [
        '/tmp/photo.jpg',
        '../photo.jpg',
        'https://example.com/photo.jpg',
      ]) {
        expect(await controller.setWorkoutPhoto(id, path), isFalse);
        expect(controller.activeWorkout!.photoPath, 'workout_photos/abc.jpg');
      }
      expect(await controller.setWorkoutPhoto(id, null), isTrue);
      expect(repository.value.activeWorkout!.photoPath, isNull);
    },
  );
}
