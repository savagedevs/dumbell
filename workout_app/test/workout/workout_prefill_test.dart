import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workout_app/app/workout_controller.dart';
import 'package:workout_app/core/theme.dart';
import 'package:workout_app/data/models.dart';
import 'package:workout_app/features/workout/workout_page.dart';

import '../support/exercise_prefill_fixture.dart';
import '../support/memory_repository.dart';

String? fieldHint(WidgetTester tester, Finder formField) => tester
    .widget<TextField>(
      find.descendant(of: formField, matching: find.byType(TextField)),
    )
    .decoration!
    .helperText;

void main() {
  setUp(() => Get.testMode = true);
  tearDown(() => Get.reset());

  Future<WorkoutController> mount(
    WidgetTester tester,
    MemoryRepository store, {
    double width = 390,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final workouts = Get.put(WorkoutController(store, store.value));
    workouts.onClose();
    final adding = workouts.addExercise('repdb_squat');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(workouts.isSaving.value, isFalse);
    expect(await adding, isTrue);
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const WorkoutPage(),
      ),
    );
    await tester.pumpAndSettle();
    return workouts;
  }

  testWidgets(
    'logger fills previous values in fields and labels matching values without a progress panel',
    (tester) async {
      final store = MemoryRepository()..value = exercisePrefillFixture();
      final workouts = await mount(tester, store);
      final sets = workouts.activeWorkout!.exercises.single.sets;
      final firstWeight = find.byKey(ValueKey('weight-${sets.first.id}'));
      final firstReps = find.byKey(ValueKey('reps-${sets.first.id}'));
      final secondWeight = find.byKey(ValueKey('weight-${sets.last.id}'));
      await tester.ensureVisible(firstWeight);
      expect(
        tester.widget<TextFormField>(firstWeight).controller!.text,
        '40.1',
      );
      expect(tester.widget<TextFormField>(firstReps).controller!.text, '10');
      expect(
        tester.widget<TextFormField>(secondWeight).controller!.text,
        '45.5',
      );
      expect(fieldHint(tester, firstWeight), 'Same as last');
      expect(find.textContaining('Last time'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Progress'), findsNothing);

      await tester.enterText(firstWeight, '42.75');
      await tester.pump();
      expect(fieldHint(tester, firstWeight), 'Your entry');
      expect(fieldHint(tester, firstReps), 'Same as last');
      await tester.pump(const Duration(milliseconds: 800));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(
        store.value.activeWorkout!.exercises.single.sets.first.weightKg,
        42.75,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        GetMaterialApp(theme: AppTheme.dark, home: const WorkoutPage()),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(firstWeight).controller!.text,
        '42.8',
      );
      expect(
        store.value.activeWorkout!.exercises.single.sets.first.weightKg,
        42.75,
      );
      expect(fieldHint(tester, firstWeight), 'Your entry');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await Get.delete<WorkoutController>(force: true);
    },
  );

  testWidgets(
    'lb prefilled sets keep exact kg when completed on a narrow large-text logger',
    (tester) async {
      final store = MemoryRepository()
        ..value = exercisePrefillFixture(unit: WeightUnit.lb);
      final workouts = await mount(tester, store, width: 320, textScale: 2);
      final set = workouts.activeWorkout!.exercises.single.sets.first;
      final field = find.byKey(ValueKey('weight-${set.id}'));
      await tester.scrollUntilVisible(
        field,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<TextFormField>(field).controller!.text, '88.5');
      expect(fieldHint(tester, field), 'Same as last');
      final complete = find.byKey(ValueKey('complete-${set.id}'));
      await tester.ensureVisible(complete);
      await tester.pumpAndSettle();
      await tester.tap(complete);
      await tester.pumpAndSettle();
      final saved = store.value.activeWorkout!.exercises.single.sets.first;
      expect(saved.weightKg, closeTo(40.125, .000000001));
      expect(saved.reps, 10);
      expect(saved.isCompleted, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await Get.delete<WorkoutController>(force: true);
    },
  );
}
