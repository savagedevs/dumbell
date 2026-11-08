import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workout_app/app/routes.dart';
import 'package:workout_app/app/workout_controller.dart';
import 'package:workout_app/core/theme.dart';
import 'package:workout_app/data/models.dart';
import 'package:workout_app/features/home/home_page.dart';

import '../support/memory_repository.dart';

void main() {
  setUp(() => Get.testMode = true);
  tearDown(() => Get.reset());

  Future<void> mount(WidgetTester tester, MemoryRepository repository) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final workouts = Get.put(WorkoutController(repository, repository.value));
    workouts.onClose();
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: HomePage()),
        getPages: [
          GetPage(
            name: AppRoutes.workout,
            page: () => Scaffold(
              body: Text(
                Get.arguments == true ? 'Choose an exercise' : 'Resume session',
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('new workout requests the exercise picker after saving', (
    tester,
  ) async {
    final repository = MemoryRepository()
      ..value = AppData(onboardingCompleted: true);
    await mount(tester, repository);
    await tester.ensureVisible(find.text('Start workout'));
    await tester.tap(find.text('Start workout'));
    await tester.pumpAndSettle();
    expect(repository.value.activeWorkout, isNotNull);
    expect(repository.writes, 1);
    expect(Get.arguments, isTrue);
    expect(find.text('Choose an exercise'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('resuming an existing workout does not request the picker', (
    tester,
  ) async {
    final repository = MemoryRepository()
      ..value = AppData(
        onboardingCompleted: true,
        activeWorkout: WorkoutSession(
          id: 'draft',
          name: 'Upper body',
          startedAt: DateTime(2026, 11, 8, 12),
          exercises: const [],
        ),
      );
    await mount(tester, repository);
    await tester.ensureVisible(find.text('Resume workout'));
    await tester.tap(find.text('Resume workout'));
    await tester.pumpAndSettle();
    expect(repository.writes, 0);
    expect(repository.value.activeWorkout!.id, 'draft');
    expect(Get.arguments, isNull);
    expect(find.text('Resume session'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a failed workout save stays on Home', (tester) async {
    final repository = MemoryRepository()
      ..value = AppData(onboardingCompleted: true)
      ..failWrites = true;
    await mount(tester, repository);
    await tester.ensureVisible(find.text('Start workout'));
    await tester.tap(find.text('Start workout'));
    await tester.pumpAndSettle();
    expect(repository.value.activeWorkout, isNull);
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Choose an exercise'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
