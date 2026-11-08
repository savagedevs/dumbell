import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workout_app/app/routes.dart';
import 'package:workout_app/app/workout_controller.dart';
import 'package:workout_app/core/theme.dart';
import 'package:workout_app/data/models.dart';
import 'package:workout_app/features/exercises/exercises_page.dart';
import 'package:workout_app/features/workout/workout_detail_page.dart';
import 'package:workout_app/features/workout/workout_page.dart';

import '../support/memory_repository.dart';

WorkoutSession _session(String id) => WorkoutSession(
  id: id,
  name: 'Upper body',
  startedAt: DateTime(2026, 11, 8, 12),
  exercises: [
    for (final entry in ['first', 'second'])
      WorkoutExercise(
        id: '$id-$entry',
        exerciseId: 'barbell-bench-press',
        name: 'Exercise $entry',
        sets: [WorkoutSet(id: '$id-set-$entry', reps: 8, weightKg: 40)],
      ),
  ],
);

void main() {
  setUp(() => Get.testMode = true);
  tearDown(() async => Get.reset());

  Future<WorkoutController> mount(
    WidgetTester tester,
    MemoryRepository repository,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = Get.put(
      WorkoutController(
        repository,
        repository.value,
        clock: () => DateTime(2026, 11, 8, 12, 5),
      ),
    );
    controller.onClose();
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.dark,
        home: const WorkoutPage(),
        getPages: [
          GetPage(
            name: AppRoutes.exercises,
            page: () => const Scaffold(body: ExercisesPage()),
          ),
          GetPage(
            name: AppRoutes.detail,
            page: () => const WorkoutDetailPage(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  Future<void> chooseSaveAndStart(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Workout options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save & start new'));
    await tester.pumpAndSettle();
  }

  testWidgets('save and start flushes pending values and opens one picker', (
    tester,
  ) async {
    final repository = MemoryRepository()
      ..value = AppData(activeWorkout: _session('active'));
    final controller = await mount(tester, repository);
    final weight = find.byKey(const ValueKey('weight-active-set-first'));
    await tester.ensureVisible(weight);
    await tester.enterText(weight, '62.5');
    // Open the action before the input debounce has time to save.
    await chooseSaveAndStart(tester);
    expect(find.textContaining('unfinished sets'), findsOneWidget);
    expect(
      repository.value.activeWorkout!.exercises.first.sets.single.weightKg,
      62.5,
    );
    expect(repository.value.history, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, 'Save & start new'));
    await tester.pumpAndSettle();
    expect(controller.history.single.id, 'active');
    expect(
      controller.history.single.exercises.first.sets.single.weightKg,
      62.5,
    );
    expect(
      controller.history.single.exercises.first.sets.single.isCompleted,
      isFalse,
    );
    expect(controller.activeWorkout!.id, isNot('active'));
    expect(controller.activeWorkout!.exercises, isEmpty);
    expect(find.text('ADD TO YOUR WORKOUT'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to workout'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutPage), findsOneWidget);
    expect(find.byType(ExercisesPage), findsNothing);
    expect(find.text('Build your session.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'failed pending flush keeps values and does not start a workout',
    (tester) async {
      final repository = MemoryRepository()
        ..value = AppData(activeWorkout: _session('active'))
        ..failWrites = true;
      await mount(tester, repository);
      final weight = find.byKey(const ValueKey('weight-active-set-first'));
      await tester.ensureVisible(weight);
      await tester.enterText(weight, '62.5');
      await chooseSaveAndStart(tester);
      expect(repository.value.activeWorkout!.id, 'active');
      expect(repository.value.history, isEmpty);
      expect(
        find.widgetWithText(FilledButton, 'Save & start new'),
        findsNothing,
      );
      expect(find.byType(ExercisesPage), findsNothing);
      expect(tester.widget<TextFormField>(weight).controller!.text, '62.5');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('active fields and visible action select an earlier exercise', (
    tester,
  ) async {
    final repository = MemoryRepository()
      ..value = AppData(activeWorkout: _session('active'));
    final controller = await mount(tester, repository);
    final second = find.byKey(const ValueKey('weight-active-set-second'));
    await tester.ensureVisible(second);
    await tester.pumpAndSettle();
    await tester.tap(second);
    await tester.pump();
    expect(controller.currentExercise?.id, 'active-second');
    final firstAction = find.byKey(
      const ValueKey('current-exercise-active-first'),
    );
    await tester.ensureVisible(firstAction);
    await tester.pumpAndSettle();
    await tester.tap(firstAction);
    await tester.pump();
    expect(controller.currentExercise?.id, 'active-first');
    expect(
      find.descendant(of: firstAction, matching: find.text('Current exercise')),
      findsOneWidget,
    );
    expect(repository.writes, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('historical fields never change current exercise', (
    tester,
  ) async {
    final repository = MemoryRepository()
      ..value = AppData(
        activeWorkout: _session('active'),
        history: [_session('saved')],
      );
    final controller = await mount(tester, repository);
    Get.toNamed<void>(AppRoutes.detail, arguments: 'saved');
    await tester.pumpAndSettle();
    final historical = find.byKey(const ValueKey('weight-saved-set-second'));
    await tester.ensureVisible(historical);
    await tester.enterText(historical, '55');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(controller.currentExercise?.id, 'active-first');
    expect(
      repository.value.history.single.exercises.last.sets.single.weightKg,
      55,
    );
    expect(
      find.byKey(const ValueKey('current-exercise-saved-second')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
