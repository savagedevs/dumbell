import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workout_app/app/routes.dart';
import 'package:workout_app/app/workout_controller.dart';
import 'package:workout_app/core/theme.dart';
import 'package:workout_app/data/models.dart';
import 'package:workout_app/features/workout/workout_detail_page.dart';
import 'package:workout_app/features/workout/workout_page.dart';

import '../support/memory_repository.dart';

WorkoutSession _session({
  String id = 'active',
  bool finished = false,
  double weightKg = 40,
}) => WorkoutSession(
  id: id,
  name: 'Upper body',
  startedAt: DateTime(2026, 11, 8, 12),
  finishedAt: finished ? DateTime(2026, 11, 8, 12, 30) : null,
  exercises: [
    WorkoutExercise(
      id: 'exercise',
      exerciseId: 'barbell-bench-press',
      name: 'Barbell bench press',
      sets: [
        WorkoutSet(id: 'set', reps: 8, weightKg: weightKg, isCompleted: true),
      ],
    ),
  ],
);

void main() {
  setUp(() => Get.testMode = true);
  tearDown(() async => Get.reset());

  Future<WorkoutController> mount(
    WidgetTester tester,
    MemoryRepository repository, {
    double width = 390,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = Get.put(
      WorkoutController(
        repository,
        repository.value,
        clock: () => DateTime(2026, 11, 8, 12, 1),
      ),
    );
    // This fixture drives now explicitly, avoiding a live periodic app timer.
    controller.onClose();
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
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
    return controller;
  }

  testWidgets('timer ticks preserve focused entry and idle typing persists', (
    tester,
  ) async {
    final repository = MemoryRepository()
      ..value = AppData(activeWorkout: _session());
    final controller = await mount(tester, repository);
    final weight = find.byKey(const ValueKey('weight-set'));
    await tester.ensureVisible(weight);
    await tester.enterText(weight, '62.5');
    await tester.pump(const Duration(milliseconds: 200));
    controller.now.value = controller.now.value.add(const Duration(seconds: 2));
    await tester.pump();
    expect(tester.widget<TextFormField>(weight).controller!.text, '62.5');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(
      repository.value.activeWorkout!.exercises.single.sets.single.weightKg,
      62.5,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('failed flush retains typed values and keeps workout open', (
    tester,
  ) async {
    final repository = MemoryRepository()
      ..value = AppData(activeWorkout: _session())
      ..failWrites = true;
    await mount(tester, repository);
    final weight = find.byKey(const ValueKey('weight-set'));
    await tester.ensureVisible(weight);
    await tester.enterText(weight, '55');
    await tester.tap(find.text('Finish workout'));
    await tester.pumpAndSettle();
    expect(repository.value.activeWorkout, isNotNull);
    expect(
      repository.value.activeWorkout!.exercises.single.sets.single.weightKg,
      40,
    );
    expect(tester.widget<TextFormField>(weight).controller!.text, '55');
    expect(find.text('Finish strong.'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('saved edits persist before the first back action', (
    tester,
  ) async {
    final repository = MemoryRepository()
      ..value = AppData(
        activeWorkout: _session(),
        history: [_session(id: 'saved', finished: true)],
      );
    await mount(tester, repository);
    Get.toNamed<void>(AppRoutes.detail, arguments: 'saved');
    await tester.pumpAndSettle();
    final reps = find.byKey(const ValueKey('reps-set')).last;
    await tester.ensureVisible(reps);
    await tester.enterText(reps, '12');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(
      repository.value.history.single.exercises.single.sets.single.reps,
      12,
    );
    expect(
      repository.value.activeWorkout!.exercises.single.sets.single.reps,
      8,
    );
    expect(find.byType(WorkoutDetailPage), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final example in [(WeightUnit.kg, 1.25), (WeightUnit.lb, 50.0)]) {
    testWidgets(
      'completion and reps edits preserve ${example.$2} kg in ${example.$1.label}',
      (tester) async {
        final repository = MemoryRepository()
          ..value = AppData(
            activeWorkout: _session(weightKg: example.$2),
            unit: example.$1,
          );
        await mount(tester, repository);
        final complete = find.byKey(const ValueKey('complete-set'));
        await tester.ensureVisible(complete);
        await tester.tap(complete);
        await tester.pumpAndSettle();
        var set = repository.value.activeWorkout!.exercises.single.sets.single;
        expect(set.isCompleted, isFalse);
        expect(set.weightKg, closeTo(example.$2, 0.0000001));
        final reps = find.byKey(const ValueKey('reps-set'));
        await tester.enterText(reps, '12');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        set = repository.value.activeWorkout!.exercises.single.sets.single;
        expect(set.reps, 12);
        expect(set.weightKg, closeTo(example.$2, 0.0000001));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('immediate completion keeps the weight just typed', (
    tester,
  ) async {
    final repository = MemoryRepository()
      ..value = AppData(activeWorkout: _session());
    await mount(tester, repository);
    final weight = find.byKey(const ValueKey('weight-set'));
    await tester.ensureVisible(weight);
    await tester.enterText(weight, '62.5');
    // Do not pump the debounce or a data rebuild before toggling completion.
    await tester.tap(find.byKey(const ValueKey('complete-set')));
    await tester.pumpAndSettle();
    final set = repository.value.activeWorkout!.exercises.single.sets.single;
    expect(set.weightKg, 62.5);
    expect(set.isCompleted, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deleting a set does not require its unfinished input to save', (
    tester,
  ) async {
    final repository = MemoryRepository()
      ..value = AppData(activeWorkout: _session());
    await mount(tester, repository);
    final reps = find.byKey(const ValueKey('reps-set'));
    await tester.ensureVisible(reps);
    await tester.enterText(reps, '');
    await tester.tap(find.byTooltip('Set 1 options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete set'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete set'));
    await tester.pumpAndSettle();
    expect(repository.value.activeWorkout!.exercises.single.sets, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('320 wide workout entry supports doubled text', (tester) async {
    final repository = MemoryRepository()
      ..value = AppData(activeWorkout: _session());
    await mount(tester, repository, width: 320, textScale: 2);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('reps-set')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
