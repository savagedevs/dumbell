import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workout_app/app/routes.dart';
import 'package:workout_app/app/workout_controller.dart';
import 'package:workout_app/data/models.dart';
import 'package:workout_app/main.dart';

import '../support/memory_repository.dart';
import '../support/no_live_platform.dart';

void main() {
  setUp(() => Get.testMode = true);
  tearDown(() => Get.reset());

  for (final profile in [
    null,
    UserProfile(name: '', goal: 'Stay consistent', experience: 'Beginner'),
  ]) {
    testWidgets(
      'previously completed onboarding with ${profile == null ? 'no profile' : 'a blank name'} requires Name without losing a draft',
      (tester) async {
        final repository = MemoryRepository()
          ..value = AppData(
            onboardingCompleted: true,
            profile: profile,
            activeWorkout: WorkoutSession(
              id: 'old-draft',
              name: 'My session',
              startedAt: DateTime(2026, 11, 8),
              exercises: [],
            ),
          );
        final original = repository.value.toJson();
        await tester.pumpWidget(
          LiftLogApp(
            repository: repository,
            liveWorkoutPlatform: NoLivePlatform(),
          ),
        );
        await tester.pumpAndSettle();
        expect(Get.currentRoute, AppRoutes.profile);
        expect(find.byKey(const ValueKey('profile-name')), findsOneWidget);
        expect(repository.value.toJson(), original);
        expect(repository.writes, 0);
        Get.offAllNamed(AppRoutes.history);
        await tester.pumpAndSettle();
        expect(Get.currentRoute, AppRoutes.profile);
        expect(repository.value.activeWorkout!.id, 'old-draft');
        await tester.pumpWidget(const SizedBox.shrink());
        await Get.delete<WorkoutController>(force: true);
      },
    );
  }
}
