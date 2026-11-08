import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workout_app/app/routes.dart';
import 'package:workout_app/app/workout_controller.dart';
import 'package:workout_app/core/theme.dart';
import 'package:workout_app/data/exercise_catalog.dart';
import 'package:workout_app/data/models.dart';
import 'package:workout_app/features/exercises/exercises_page.dart';
import 'package:workout_app/features/exercises/widgets/exercise_media_panel.dart';
import 'package:workout_app/features/exercises/widgets/exercise_thumbnail.dart';
import 'package:workout_app/features/exercises/widgets/exercise_details.dart';
import 'package:workout_app/features/exercise_progress/exercise_progress_page.dart';
import 'package:workout_app/features/exercise_progress/widgets/exercise_trend_chart.dart';

import '../support/memory_repository.dart';

Future<void> dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await Get.delete<WorkoutController>(force: true);
  Get.reset();
}

String panelAsset(WidgetTester tester) {
  final image = tester.widget<Image>(
    find.descendant(
      of: find.byType(ExerciseMediaPanel),
      matching: find.byType(Image),
    ),
  );
  expect(image.image, isA<AssetImage>());
  return (image.image as AssetImage).assetName;
}

Finder exerciseName(String name) =>
    find.byWidgetPredicate((widget) => widget is Text && widget.data == name);

void expectStillControls() {
  expect(find.text('Play demo'), findsNothing);
  expect(find.textContaining('Download'), findsNothing);
  expect(find.text('Remove download'), findsNothing);
  expect(find.byIcon(Icons.download_rounded), findsNothing);
}

void main() {
  setUp(() => Get.testMode = true);

  Future<WorkoutController> mountLibrary(
    WidgetTester tester, {
    MemoryRepository? repository,
  }) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = repository ?? MemoryRepository();
    final controller = Get.put(WorkoutController(store, store.value));
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.dark,
        initialRoute: AppRoutes.exercises,
        getPages: [
          GetPage(
            name: AppRoutes.exercises,
            page: () => const Scaffold(body: ExercisesPage()),
          ),
          GetPage(
            name: AppRoutes.home,
            page: () => const Scaffold(body: Text('Home destination')),
          ),
          GetPage(
            name: AppRoutes.workout,
            page: () => const Scaffold(body: Text('Workout destination')),
          ),
          ...AppRoutes.pages.where(
            (page) => page.name == AppRoutes.exerciseProgress,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  MemoryRepository recordedSquats() => MemoryRepository()
    ..value = AppData(
      onboardingCompleted: true,
      profile: UserProfile(
        name: 'Test',
        goal: 'Build strength',
        experience: 'Beginner',
      ),
      history: [
        for (final (id, day, weight) in [
          ('older', 1, 10.0),
          ('latest', 5, 20.0),
        ])
          WorkoutSession(
            id: id,
            name: 'Strength',
            startedAt: DateTime(2026, 11, day),
            finishedAt: DateTime(2026, 11, day, 1),
            exercises: [
              WorkoutExercise(
                id: '$id-exercise',
                exerciseId: 'squat',
                name: 'Barbell Squat',
                sets: [
                  WorkoutSet(
                    id: '$id-set',
                    reps: 8,
                    weightKg: weight,
                    isCompleted: true,
                  ),
                ],
              ),
            ],
          ),
      ],
    );

  testWidgets('exercise list opens its own graph without adding a movement', (
    tester,
  ) async {
    try {
      final repository = recordedSquats();
      final controller = await mountLibrary(tester, repository: repository);
      await tester.tap(find.byTooltip('View graph for Barbell Back Squat'));
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseProgressPage), findsOneWidget);
      expect(find.byType(ExerciseTrendChart), findsOneWidget);
      expect(
        find.text('2 saved workouts · Completed sets only'),
        findsOneWidget,
      );
      expect(controller.activeWorkout, isNull);
      expect(repository.writes, 0);
    } finally {
      await dispose(tester);
    }
  });

  testWidgets('exercise details show an interactive graph inline', (
    tester,
  ) async {
    try {
      await mountLibrary(tester, repository: recordedSquats());
      await tester.tap(find.byType(ExerciseThumbnail).first);
      await tester.pumpAndSettle();
      final detail = find.byType(ExerciseDetails);
      final chart = find.descendant(
        of: detail,
        matching: find.byType(ExerciseTrendChart),
      );
      expect(chart, findsOneWidget);
      expect(tester.widget<ExerciseTrendChart>(chart).points, hasLength(2));
      final volume = find.descendant(
        of: detail,
        matching: find.widgetWithText(ChoiceChip, 'Volume'),
      );
      await tester.ensureVisible(volume);
      await tester.tap(volume);
      await tester.pumpAndSettle();
      expect(find.text('160 kg × reps · 5 Nov 2026'), findsOneWidget);
      final plot = find.descendant(
        of: detail,
        matching: find.byKey(const ValueKey('exercise-trend-chart')),
      );
      await tester.ensureVisible(plot);
      await tester.tapAt(tester.getTopLeft(plot) + const Offset(6, 90));
      await tester.pumpAndSettle();
      expect(find.text('80 kg × reps · 1 Nov 2026'), findsOneWidget);
      expect(find.byType(ExerciseProgressPage), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await dispose(tester);
    }
  });

  testWidgets(
    'details put add first, illustration and cues next, progress last',
    (tester) async {
      try {
        final repository = recordedSquats();
        repository.value = repository.value.copyWith(
          activeWorkout: WorkoutSession(
            id: 'active',
            name: 'Today',
            startedAt: DateTime(2026, 11, 8),
            exercises: [],
          ),
        );
        await mountLibrary(tester, repository: repository);
        await tester.tap(find.byType(ExerciseThumbnail).first);
        await tester.pumpAndSettle();
        final add = find.widgetWithText(FilledButton, 'Add to workout');
        final media = find.byType(ExerciseMediaPanel);
        final graph = find.byType(ExerciseTrendChart);
        expect(
          tester.getTopLeft(add).dy,
          lessThan(tester.getTopLeft(media).dy),
        );
        expect(
          tester.getBottomLeft(media).dy,
          lessThan(tester.getTopLeft(graph).dy),
        );
        expect(
          tester
              .getBottomLeft(
                find.text('Keep your chest up throughout the movement.'),
              )
              .dy,
          lessThan(tester.getTopLeft(graph).dy),
        );
        expect(add.hitTestable(), findsOneWidget);
        expect(find.textContaining('Last time'), findsNothing);
        await tester.tap(add);
        await tester.pumpAndSettle();
        expect(
          repository.value.activeWorkout!.exercises.single.exerciseId,
          'repdb_squat',
        );
        expect(
          repository.value.activeWorkout!.exercises.single.sets.single.weightKg,
          20,
        );
      } finally {
        await dispose(tester);
      }
    },
  );

  testWidgets('unlogged exercise explains missing graph in its details', (
    tester,
  ) async {
    try {
      await mountLibrary(tester);
      await tester.tap(find.byType(ExerciseThumbnail).first);
      await tester.pumpAndSettle();
      expect(find.text('Your progress'), findsOneWidget);
      expect(
        find.text(
          'Complete a set and save a workout for this exercise to see your graph.',
        ),
        findsOneWidget,
      );
      expect(find.byType(ExerciseTrendChart), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await dispose(tester);
    }
  });

  testWidgets('library offers Home without creating a session', (tester) async {
    try {
      final repository = MemoryRepository();
      final controller = await mountLibrary(tester, repository: repository);
      await tester.tap(find.byType(ExerciseThumbnail).first);
      await tester.pumpAndSettle();
      expect(find.text('Go to Home to start'), findsOneWidget);
      await tester.ensureVisible(find.text('Go to Home to start'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go to Home to start'));
      await tester.pumpAndSettle();
      expect(find.text('Home destination'), findsOneWidget);
      expect(controller.activeWorkout, isNull);
      expect(repository.writes, 0);
    } finally {
      await dispose(tester);
    }
  });

  testWidgets('library searches the offline catalogue without image filters', (
    tester,
  ) async {
    try {
      await mountLibrary(tester);
      expect(find.text('With images'), findsNothing);
      expect(find.text('Offline images'), findsNothing);
      expect(find.text('701 movements'), findsOneWidget);
      expect(find.text('Exercise data by RepDB (repdb.co)'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Barbell Bench Press');
      await tester.pumpAndSettle();
      expect(exerciseName('Barbell Bench Press'), findsOneWidget);
      expect(find.text('Barbell Back Squat'), findsNothing);
      await tester.enterText(find.byType(TextField), 'no matching exercise');
      await tester.pumpAndSettle();
      expect(find.text('No matching movements'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('Barbell Back Squat'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await dispose(tester);
    }
  });

  testWidgets('paired poses use local images and change only when selected', (
    tester,
  ) async {
    try {
      await mountLibrary(tester);
      final thumbnailImage = tester.widget<Image>(
        find.descendant(
          of: find.byType(ExerciseThumbnail).first,
          matching: find.byType(Image),
        ),
      );
      expect(thumbnailImage.image, isA<AssetImage>());
      expect(
        (thumbnailImage.image as AssetImage).assetName,
        'assets/exercises/repdb/flat/squat-start.webp',
      );
      await tester.tap(find.byType(ExerciseThumbnail).first);
      await tester.pumpAndSettle();
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Peak'), findsOneWidget);
      expect(
        panelAsset(tester),
        'assets/exercises/repdb/flat/squat-start.webp',
      );
      await tester.ensureVisible(find.text('Peak'));
      await tester.tap(find.text('Peak'));
      await tester.pumpAndSettle();
      expect(panelAsset(tester), 'assets/exercises/repdb/flat/squat-peak.webp');
      await tester.pump(const Duration(seconds: 5));
      expect(panelAsset(tester), 'assets/exercises/repdb/flat/squat-peak.webp');
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(
        panelAsset(tester),
        'assets/exercises/repdb/flat/squat-start.webp',
      );
      expectStillControls();
      await tester.ensureVisible(find.text('FORM CUES'));
      expect(
        find.text('Position the bar on your upper traps.'),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.text('Keep your chest up throughout the movement.'),
      );
      expect(
        find.text('Keep your chest up throughout the movement.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      await dispose(tester);
    }
  });

  testWidgets('single-pose movement has no redundant selector or downloads', (
    tester,
  ) async {
    try {
      await mountLibrary(tester);
      await tester.enterText(find.byType(TextField), '90/90 Hold');
      await tester.pumpAndSettle();
      expect(exerciseName('90/90 Hold'), findsOneWidget);
      await tester.tap(exerciseName('90/90 Hold'));
      await tester.pumpAndSettle();
      expect(
        panelAsset(tester),
        'assets/exercises/repdb/flat/90-90-hold-main.webp',
      );
      expect(
        find.descendant(
          of: find.byType(ExerciseMediaPanel),
          matching: find.byType(ChoiceChip),
        ),
        findsNothing,
      );
      expect(find.text('Start'), findsNothing);
      expect(find.text('Peak'), findsNothing);
      expectStillControls();
      expect(tester.takeException(), isNull);
    } finally {
      await dispose(tester);
    }
  });

  testWidgets('pose selector fits narrow screens with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ExerciseMediaPanel(exercise: exerciseCatalog.first),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Start'), findsOneWidget);
    await tester.ensureVisible(find.text('Peak'));
    await tester.tap(find.text('Peak'));
    await tester.pumpAndSettle();
    expect(panelAsset(tester), 'assets/exercises/repdb/flat/squat-peak.webp');
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting a movement returns to the existing workout', (
    tester,
  ) async {
    try {
      final repository = MemoryRepository()
        ..value = AppData(
          activeWorkout: WorkoutSession(
            id: 'existing-session',
            name: 'Workout',
            startedAt: DateTime(2026, 11, 8),
            exercises: const [],
          ),
        );
      final controller = Get.put(
        WorkoutController(repository, repository.value),
      );
      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: TextButton(
              onPressed: () =>
                  Get.toNamed(AppRoutes.exercises, arguments: true),
              child: const Text('Choose movement'),
            ),
          ),
          getPages: [
            GetPage(
              name: AppRoutes.exercises,
              page: () => const Scaffold(body: ExercisesPage()),
            ),
          ],
        ),
      );
      await tester.tap(find.text('Choose movement'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Add Barbell Back Squat'));
      await tester.tap(find.byTooltip('Add Barbell Back Squat'));
      await tester.pumpAndSettle();
      expect(find.text('Choose movement'), findsOneWidget);
      expect(controller.activeWorkout!.id, 'existing-session');
      expect(
        controller.activeWorkout!.exercises.single.exerciseId,
        'repdb_squat',
      );
      expect(repository.writes, 1);
      expect(tester.takeException(), isNull);
    } finally {
      await dispose(tester);
    }
  });
}
