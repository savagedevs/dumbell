import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workout_app/app/workout_controller.dart';
import 'package:workout_app/core/theme.dart';
import 'package:workout_app/data/exercise_catalog.dart';
import 'package:workout_app/data/models.dart';
import 'package:workout_app/features/exercises/exercises_page.dart';
import 'package:workout_app/features/history/history_page.dart';
import 'package:workout_app/features/home/home_page.dart';
import 'package:workout_app/features/progress/progress_page.dart';

import '../support/memory_repository.dart';

Future<void> _disposeScreen(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await Get.delete<WorkoutController>(force: true);
  Get.reset();
}

Widget _screen(Widget page, {String state = '', double textScale = 1}) =>
    GetMaterialApp(
      key: ValueKey('${page.runtimeType}-$state'),
      theme: AppTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(body: page),
    );

void main() {
  for (final page in [
    const HomePage(),
    const HistoryPage(),
    const ExercisesPage(),
    const ProgressPage(),
  ]) {
    testWidgets(
      '${page.runtimeType} fits 320px with doubled text through all content',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        try {
          Get.put(
            WorkoutController(
              MemoryRepository(),
              AppData(
                unit: WeightUnit.lb,
                history: [
                  WorkoutSession(
                    id: 'saved',
                    name: 'Upper body strength workout',
                    startedAt: DateTime(2026, 11, 8, 9),
                    finishedAt: DateTime(2026, 11, 8, 10),
                    exercises: [
                      WorkoutExercise(
                        id: 'move',
                        exerciseId: 'bench',
                        name: 'Bench press',
                        sets: [
                          WorkoutSet(
                            id: 'set',
                            reps: 8,
                            weightKg: 50,
                            isCompleted: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
                bodyWeights: [
                  BodyWeightEntry(
                    id: 'one',
                    measuredAt: DateTime(2026, 11, 6),
                    weightKg: 75,
                  ),
                  BodyWeightEntry(
                    id: 'two',
                    measuredAt: DateTime(2026, 11, 7),
                    weightKg: 75.5,
                  ),
                ],
              ),
              clock: () => DateTime(2026, 11, 8, 12),
            ),
          );
          await tester.pumpWidget(_screen(page, textScale: 2));
          await tester.pump();
          expect(tester.takeException(), isNull);
          final scrollable = find.byType(Scrollable).first;
          for (var step = 0; step < 30; step++) {
            final position = tester.state<ScrollableState>(scrollable).position;
            if (position.pixels >= position.maxScrollExtent) break;
            await tester.drag(scrollable, const Offset(0, -350));
            await tester.pump();
            expect(tester.takeException(), isNull);
          }
          if (page is ProgressPage) {
            expect(find.text('Weight history'), findsOneWidget);
            expect(find.text('166.4 lb'), findsOneWidget);
          }
        } finally {
          await _disposeScreen(tester);
        }
      },
    );
  }

  testWidgets('empty and recorded screens fit a narrow mobile viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    try {
      final controller = Get.put(
        WorkoutController(MemoryRepository(), AppData()),
      );
      for (final page in [
        const HomePage(),
        const HistoryPage(),
        const ExercisesPage(),
        const ProgressPage(),
      ]) {
        await tester.pumpWidget(_screen(page));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      controller.data.value = AppData(
        unit: WeightUnit.lb,
        history: [
          WorkoutSession(
            id: 'session',
            name: 'A long but valid recorded strength workout name',
            startedAt: DateTime(2026, 11, 7, 10),
            finishedAt: DateTime(2026, 11, 7, 10, 35),
            exercises: [
              WorkoutExercise(
                id: 'exercise',
                exerciseId: 'bench',
                name: 'Bench press',
                sets: [
                  WorkoutSet(
                    id: 'set',
                    reps: 8,
                    weightKg: 50,
                    isCompleted: true,
                  ),
                ],
              ),
            ],
          ),
        ],
        bodyWeights: [
          BodyWeightEntry(
            id: 'one',
            measuredAt: DateTime(2026, 11, 6),
            weightKg: 75,
          ),
          BodyWeightEntry(
            id: 'two',
            measuredAt: DateTime(2026, 11, 7),
            weightKg: 75.5,
          ),
        ],
      );
      for (final page in [
        const HomePage(),
        const HistoryPage(),
        const ProgressPage(),
      ]) {
        await tester.pumpWidget(_screen(page, state: 'recorded'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -650));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    } finally {
      await _disposeScreen(tester);
    }
  });

  testWidgets('exercise search and instructions use real catalogue records', (
    tester,
  ) async {
    try {
      Get.put(WorkoutController(MemoryRepository(), AppData()));
      await tester.pumpWidget(_screen(const ExercisesPage()));
      await tester.enterText(find.byType(TextField), 'not-a-real-exercise');
      await tester.pump();
      expect(find.text('No matching movements'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pump();
      await tester.tap(find.text(exerciseCatalog.first.name));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('FORM CUES'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await _disposeScreen(tester);
    }
  });

  testWidgets('body weight dialog validates and converts pounds', (
    tester,
  ) async {
    try {
      final controller = Get.put(
        WorkoutController(MemoryRepository(), AppData(unit: WeightUnit.lb)),
      );
      await tester.pumpWidget(_screen(const ProgressPage()));
      await tester.scrollUntilVisible(
        find.text('Log weight'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Log weight'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Save weight'));
      await tester.pump();
      expect(find.text('Enter a weight greater than zero.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '220.46226218');
      await tester.tap(find.text('Save weight'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.bodyWeights.single.weightKg, closeTo(100, 0.0001));
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await _disposeScreen(tester);
    }
  });
}
