import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workout_app/app/routes.dart';
import 'package:workout_app/app/workout_controller.dart';
import 'package:workout_app/core/theme.dart';
import 'package:workout_app/data/models.dart';
import 'package:workout_app/features/exercise_progress/exercise_progress_controller.dart';
import 'package:workout_app/features/exercise_progress/exercise_progress_page.dart';
import 'package:workout_app/features/sharing/workout_share_preview.dart';
import 'package:workout_app/features/workout/workout_detail_page.dart';

import '../support/memory_repository.dart';

void main() {
  setUp(() => Get.testMode = true);
  tearDown(() => Get.reset());

  for (final failWrites in [false, true]) {
    testWidgets('sharing flushes typed history edits; failure=$failWrites', (
      tester,
    ) async {
      final repository = MemoryRepository()
        ..failWrites = failWrites
        ..value = AppData(
          unit: WeightUnit.lb,
          history: [
            WorkoutSession(
              id: 'saved',
              name: 'Strength',
              startedAt: DateTime(2026, 11, 1, 12),
              finishedAt: DateTime(2026, 11, 1, 13),
              exercises: [
                WorkoutExercise(
                  id: 'exercise',
                  exerciseId: 'repdb_squat',
                  name: 'Barbell Back Squat',
                  sets: [
                    WorkoutSet(
                      id: 'set',
                      reps: 8,
                      weightKg: 10,
                      isCompleted: true,
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      final controller = Get.put(
        WorkoutController(repository, repository.value),
      );
      controller.onClose();
      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: Text('History')),
        ),
      );
      Get.to<void>(() => const WorkoutDetailPage(), arguments: 'saved');
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('weight-set'));
      await tester.scrollUntilVisible(
        field,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(field, '55');
      // Flush before the 700 ms autosave, using the always-visible app bar.
      await tester.tap(find.byTooltip('Share workout'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      if (failWrites) {
        expect(find.byType(WorkoutSharePreviewPage), findsNothing);
        expect(
          repository.value.history.single.exercises.single.sets.single.weightKg,
          10,
        );
        expect(tester.widget<TextFormField>(field).controller!.text, '55');
      } else {
        final preview = tester.widget<WorkoutSharePreviewPage>(
          find.byType(WorkoutSharePreviewPage),
        );
        expect(preview.unit, WeightUnit.lb);
        expect(
          preview.session.exercises.single.sets.single.weightKg,
          closeTo(55 / 2.2046226218, .000001),
        );
        expect(
          preview.session.toJson(),
          repository.value.history.single.toJson(),
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await Get.delete<WorkoutController>(force: true);
    });
  }

  testWidgets(
    'GetX exercise route binds the selected exercise and disposes on back',
    (tester) async {
      final data = AppData(
        onboardingCompleted: true,
        profile: UserProfile(
          name: 'Test',
          goal: 'Build strength',
          experience: 'Beginner',
        ),
      );
      final controller = Get.put(WorkoutController(MemoryRepository(), data));
      controller.onClose();
      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: Text('History')),
          getPages: AppRoutes.pages,
        ),
      );
      Get.toNamed<void>(
        AppRoutes.exerciseProgress,
        arguments: const ExerciseProgressArguments(
          exerciseId: 'repdb_squat',
          name: 'Squat',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseProgressPage), findsOneWidget);
      expect(
        Get.find<ExerciseProgressController>(tag: 'repdb_squat')
            .exercise
            .exerciseId,
        'repdb_squat',
      );
      Get.back<void>();
      await tester.pumpAndSettle();
      expect(
        Get.isRegistered<ExerciseProgressController>(tag: 'repdb_squat'),
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await Get.delete<WorkoutController>(force: true);
    },
  );
}
