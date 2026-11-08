import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workout_app/app/routes.dart';
import 'package:workout_app/app/workout_controller.dart';
import 'package:workout_app/core/theme.dart';
import 'package:workout_app/data/models.dart';
import 'package:workout_app/features/progress/widgets/workout_consistency_card.dart';
import 'package:workout_app/features/workout/workout_detail_page.dart';

import '../support/memory_repository.dart';
import 'workout_activity_test.dart' show activitySession;

void main() {
  setUp(() => Get.testMode = true);
  tearDown(() => Get.reset());

  Future<WorkoutController> mount(
    WidgetTester tester, {
    double width = 390,
    double scale = 1,
    bool empty = false,
  }) async {
    tester.view.physicalSize = Size(width, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = AppData(
      onboardingCompleted: true,
      profile: UserProfile(
        name: 'Test',
        goal: 'Build strength',
        experience: 'Beginner',
      ),
      history: empty
          ? []
          : [
              activitySession('Morning strength', DateTime(2026, 11, 3, 9)),
              activitySession('Evening strength', DateTime(2026, 11, 3, 18)),
              activitySession('Sunday strength', DateTime(2026, 11, 8, 10)),
              activitySession(
                'Unfinished archive',
                DateTime(2026, 11, 4),
                completed: false,
              ),
            ],
    );
    final repository = MemoryRepository()..value = data;
    final workouts = Get.put(
      WorkoutController(
        repository,
        data,
        clock: () => DateTime(2026, 11, 8, 12),
      ),
    );
    workouts.onClose();
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: WorkoutConsistencyCard(workouts: workouts),
          ),
        ),
        getPages: AppRoutes.pages,
      ),
    );
    await tester.pumpAndSettle();
    return workouts;
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await Get.delete<WorkoutController>(force: true);
  }

  testWidgets('calendar explains counts and opens a selected day workout', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await mount(tester);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('3 Nov 2026, 2 workouts'))
            .getSemanticsData()
            .hasAction(ui.SemanticsAction.tap),
        isTrue,
      );
      expect(find.text('3 workouts across 2 training days'), findsOneWidget);
      expect(
        find.textContaining('Consistency means how often you train.'),
        findsOneWidget,
      );
      final day = find.byKey(const ValueKey('calendar-day-2026-11-03'));
      await tester.ensureVisible(day);
      await tester.tap(day);
      await tester.pumpAndSettle();
      final morning = find.text('Morning strength');
      await tester.ensureVisible(morning);
      await tester.tap(morning);
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutDetailPage), findsOneWidget);
      expect(find.text('Morning strength'), findsOneWidget);
      expect(find.text('Evening strength'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
      await dispose(tester);
    }
  });

  testWidgets(
    'calendar browses months, returns to Today and reacts to deleted workouts',
    (tester) async {
      try {
        final workouts = await mount(tester);
        await tester.tap(find.byTooltip('Previous month'));
        await tester.pumpAndSettle();
        expect(find.text('October 2026'), findsOneWidget);
        expect(find.text('0 workouts across 0 training days'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Today'));
        await tester.pumpAndSettle();
        expect(find.text('November 2026'), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const ValueKey('calendar-day-2026-11-03')),
        );
        await tester.tap(find.byKey(const ValueKey('calendar-day-2026-11-03')));
        await tester.pumpAndSettle();
        final deleting = workouts.deleteWorkout('Morning strength');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        expect(await deleting, isTrue);
        await tester.pumpAndSettle();
        expect(find.text('2 workouts across 2 training days'), findsOneWidget);
        expect(find.text('Morning strength'), findsNothing);
        expect(find.text('Evening strength'), findsOneWidget);
        final deletingLastOnDay = workouts.deleteWorkout('Evening strength');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        expect(await deletingLastOnDay, isTrue);
        await tester.pumpAndSettle();
        expect(find.text('1 workout across 1 training day'), findsOneWidget);
        expect(
          find.text('No completed workouts logged on this day.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await dispose(tester);
      }
    },
  );

  testWidgets(
    'empty calendar and weekly explanation fit 320px with doubled text',
    (tester) async {
      try {
        await mount(tester, width: 320, scale: 2, empty: true);
        expect(find.text('0 workouts across 0 training days'), findsOneWidget);
        await tester.ensureVisible(find.text('Workouts by week'));
        await tester.tap(find.text('Workouts by week'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.textContaining('Each bar shows'));
        expect(find.textContaining('Monday–Sunday'), findsOneWidget);
        expect(
          find.textContaining('This week is still in progress.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await dispose(tester);
      }
    },
  );
}
