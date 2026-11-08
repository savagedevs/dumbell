import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workout_app/app/workout_controller.dart';
import 'package:workout_app/core/theme.dart';
import 'package:workout_app/data/models.dart';
import 'package:workout_app/features/exercise_progress/exercise_progress_controller.dart';
import 'package:workout_app/features/exercise_progress/exercise_progress_page.dart';

import '../support/memory_repository.dart';

WorkoutSession workout(
  String id,
  int day,
  double weight, {
  String exerciseId = 'repdb_squat',
}) => WorkoutSession(
  id: id,
  name: 'Strength',
  startedAt: DateTime(2026, 11, day),
  finishedAt: DateTime(2026, 11, day, 1),
  exercises: [
    WorkoutExercise(
      id: '$id-ex',
      exerciseId: exerciseId,
      name: 'Barbell Squat',
      sets: [
        WorkoutSet(id: '$id-set', reps: 8, weightKg: weight, isCompleted: true),
      ],
    ),
  ],
);
void main() {
  setUp(() => Get.testMode = true);
  tearDown(() => Get.reset());
  testWidgets(
    'exercise page selects recorded points and changes chart metric',
    (tester) async {
      final repository = MemoryRepository()
        ..value = AppData(
          history: [workout('old', 1, 10), workout('new', 8, 20)],
        );
      final workouts = Get.put(WorkoutController(repository, repository.value));
      final controller = ExerciseProgressController(
        workouts,
        const ExerciseProgressArguments(
          exerciseId: 'repdb_squat',
          name: 'Barbell Back Squat',
        ),
      );
      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.dark,
          home: ExerciseProgressPage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('2 saved workouts · Completed sets only'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('exercise-trend-chart')),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Volume'));
      await tester.pumpAndSettle();
      expect(controller.metric.value, ExerciseChartMetric.volume);
      expect(find.text('Volume · kg × reps'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await Get.delete<WorkoutController>(force: true);
    },
  );
  testWidgets('empty exercise progress fits a small phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final workouts = Get.put(WorkoutController(MemoryRepository(), AppData()));
    final controller = ExerciseProgressController(
      workouts,
      const ExerciseProgressArguments(
        exerciseId: 'repdb_push-up',
        name: 'Push-Up',
      ),
    );
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: ExerciseProgressPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your first point starts here.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await Get.delete<WorkoutController>(force: true);
  });
}
