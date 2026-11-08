import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workout_app/app/workout_controller.dart';
import 'package:workout_app/data/exercise_catalog.dart';
import 'package:workout_app/main.dart';

import 'support/memory_repository.dart';
import 'support/no_live_platform.dart';

void main() {
  setUp(() => Get.testMode = true);
  tearDown(() async => Get.reset());

  testWidgets('start, select exercise, log a set, finish and return to home', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = MemoryRepository();
    await tester.pumpWidget(
      LiftLogApp(repository: repository, liveWorkoutPlatform: NoLivePlatform()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Name'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('profile-name')),
      'Karti Sharma',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('profile-save')));
    await tester.tap(find.byKey(const ValueKey('profile-save')));
    await tester.pumpAndSettle();
    expect(find.text('Start workout'), findsOneWidget);
    await tester.ensureVisible(find.text('Start workout'));
    await tester.tap(find.text('Start workout'));
    await tester.pumpAndSettle();
    expect(repository.value.activeWorkout, isNotNull);
    expect(Get.find<WorkoutController>().activeWorkout, isNotNull);
    expect(Get.currentRoute, '/exercises');
    await tester.tap(find.byTooltip('Add ${exerciseCatalog.first.name}'));
    await tester.pumpAndSettle();
    expect(Get.currentRoute, '/workout');
    final draft = Get.find<WorkoutController>().activeWorkout!;
    final setId = draft.exercises.first.sets.first.id;
    final weightField = find.byKey(ValueKey('weight-$setId'));
    final repsField = find.byKey(ValueKey('reps-$setId'));
    await tester.ensureVisible(weightField);
    await tester.enterText(weightField, '42.5');
    await tester.enterText(repsField, '12');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    final complete = find.byTooltip('Complete set');
    await tester.ensureVisible(complete);
    await tester.tap(complete);
    await tester.pumpAndSettle();
    expect(repository.value.activeWorkout!.completedSets, 1);
    await tester.tap(find.text('Finish workout'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Finish workout'),
      ),
    );
    await tester.pumpAndSettle();
    expect(Get.currentRoute, '/workout-detail');
    expect(repository.value.activeWorkout, isNull);
    expect(
      repository.value.history.single.exercises.first.sets.first.weightKg,
      42.5,
    );
    expect(repository.value.history.single.exercises.first.sets.first.reps, 12);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(Get.currentRoute, '/');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    Get.delete<WorkoutController>(force: true);
    Get.reset();
  });
}
