import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workout_app/app/routes.dart';
import 'package:workout_app/app/workout_controller.dart';
import 'package:workout_app/core/feedback_motion.dart';
import 'package:workout_app/core/theme.dart';
import 'package:workout_app/data/models.dart';
import 'package:workout_app/features/home/home_page.dart';
import 'package:workout_app/features/workout/workout_detail_page.dart';
import 'package:workout_app/features/workout/workout_page.dart';

import '../support/memory_repository.dart';

void main() {
  setUp(() => Get.testMode = true);
  tearDown(() => Get.reset());

  Future<MemoryRepository> mountWorkout(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = MemoryRepository()
      ..value = AppData(
        activeWorkout: WorkoutSession(
          id: 'active',
          name: 'Workout',
          startedAt: DateTime(2026, 11, 8),
          exercises: [
            WorkoutExercise(
              id: 'exercise',
              exerciseId: 'bench',
              name: 'Bench press',
              sets: [
                WorkoutSet(id: 'set', reps: 8, weightKg: 40, isCompleted: true),
              ],
            ),
          ],
        ),
      );
    final controller = Get.put(WorkoutController(repository, repository.value));
    controller.onClose();
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.dark,
        home: const WorkoutPage(),
        getPages: [
          GetPage(
            name: AppRoutes.detail,
            page: () => const WorkoutDetailPage(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish workout'));
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('successful finish sparkles once and history visits stay calm', (
    tester,
  ) async {
    final repository = await mountWorkout(tester);
    await tester.tap(find.text('Finish workout').last);
    for (
      var i = 0;
      i < 10 && find.byType(CompletionSparkle).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final route = ModalRoute.of(
      tester.element(find.byType(CompletionSparkle)),
    )!;
    for (
      var i = 0;
      i < 20 && route.animation!.status != AnimationStatus.completed;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(route.animation!.status, AnimationStatus.completed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(repository.value.activeWorkout, isNull);
    expect(repository.value.history.single.completedSets, 1);
    expect(find.byKey(const ValueKey('completion-sparkles')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('completion-sparkles')), findsNothing);
    Get.toNamed<void>(AppRoutes.detail, arguments: 'active');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('completion-sparkles')), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('IN THE BOOKS.').last, findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('failed finish keeps the workout without celebrating', (
    tester,
  ) async {
    final repository = await mountWorkout(tester);
    repository.failWrites = true;
    await tester.tap(find.text('Finish workout').last);
    await tester.pumpAndSettle();
    expect(repository.value.activeWorkout, isNotNull);
    expect(repository.value.history, isEmpty);
    expect(find.byType(WorkoutDetailPage), findsNothing);
    expect(find.byKey(const ValueKey('completion-sparkles')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('returning Home does not fade the greeting again', (
    tester,
  ) async {
    final repository = MemoryRepository();
    final controller = Get.put(WorkoutController(repository, repository.value));
    controller.onClose();
    Widget home(int visit) => GetMaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: HomePage(key: ValueKey(visit))),
    );
    double opacity() => tester
        .widget<Opacity>(
          find.descendant(
            of: find.byType(WelcomeFade),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;
    await tester.pumpWidget(home(1));
    expect(opacity(), 0);
    await tester.pumpAndSettle();
    expect(opacity(), 1);
    await tester.pumpWidget(home(2));
    expect(opacity(), 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
