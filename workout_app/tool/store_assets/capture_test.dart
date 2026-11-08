// Capture the actual app widgets with isolated example data; never opens the
// user's on-device repository. Run explicitly to refresh store source images.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workout_app/app/shell.dart';
import 'package:workout_app/app/workout_controller.dart';
import 'package:workout_app/core/theme.dart';
import 'package:workout_app/data/models.dart';
import 'package:workout_app/features/home/home_page.dart';
import 'package:workout_app/features/workout/workout_page.dart';
import 'package:workout_app/features/exercises/exercises_page.dart';
import 'package:workout_app/features/exercise_progress/exercise_progress_controller.dart';
import 'package:workout_app/features/exercise_progress/exercise_progress_page.dart';
import 'package:workout_app/features/progress/progress_page.dart';

import '../../test/support/memory_repository.dart';

void main() {
  for (final screen in [
    '01-home',
    '02-workout',
    '03-exercises',
    '04-exercise-details',
    '05-exercise-progress',
    '06-calendar',
  ]) {
    testWidgets('capture $screen for store artwork', (tester) async {
      Get.testMode = true;
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(Get.reset);
      final fontRoot =
          '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts';
      await tester.runAsync(() async {
        for (final family in ['Roboto', 'Ahem', 'MaterialIcons']) {
          final fonts = FontLoader(family);
          for (final file
              in family != 'MaterialIcons'
                  ? [
                      'Roboto-Regular.ttf',
                      'Roboto-Bold.ttf',
                      'Roboto-Black.ttf',
                    ]
                  : ['MaterialIcons-Regular.otf']) {
            fonts.addFont(
              File('$fontRoot/$file')
                  .readAsBytes()
                  .then((bytes) => ByteData.sublistView(bytes)),
            );
          }
          await fonts.load();
        }
      });
      final now = DateTime(2026, 11, 8, 14);
      List<WorkoutExercise> movements(
        String prefix,
        double weight, {
        bool active = false,
      }) => [
        WorkoutExercise(
          id: '$prefix-bench',
          exerciseId: 'repdb_bench-press',
          name: 'Barbell Bench Press',
          sets: List.generate(
            3,
            (i) => WorkoutSet(
              id: '$prefix-bench-$i',
              reps: 8,
              weightKg: weight,
              isCompleted: !active || i < 2,
            ),
          ),
        ),
        WorkoutExercise(
          id: '$prefix-squat',
          exerciseId: 'repdb_db-goblet-squat',
          name: 'Dumbbell Goblet Squat',
          sets: List.generate(
            3,
            (i) => WorkoutSet(
              id: '$prefix-squat-$i',
              reps: 12,
              weightKg: 20,
              isCompleted: !active,
            ),
          ),
        ),
        WorkoutExercise(
          id: '$prefix-row',
          exerciseId: 'repdb_bent-over-row',
          name: 'Barbell Bent-Over Row',
          sets: List.generate(
            3,
            (i) => WorkoutSet(
              id: '$prefix-row-$i',
              reps: 10,
              weightKg: 35,
              isCompleted: !active,
            ),
          ),
        ),
      ];
      final history = List.generate(16, (i) {
        final start = now.subtract(Duration(days: (15 - i) * 3 + 1, hours: 7));
        return WorkoutSession(
          id: 'example-$i',
          name: i.isEven ? 'Full body strength' : 'Upper body',
          startedAt: start,
          finishedAt: start.add(const Duration(minutes: 46)),
          exercises: movements('example-$i', 40 + (i ~/ 2) * 2.5),
        );
      }).reversed.toList();
      final repository = MemoryRepository()
        ..value = AppData(
          onboardingCompleted: true,
          profile: UserProfile(
            name: 'Alex',
            goal: 'Build strength',
            experience: 'Intermediate',
          ),
          history: history,
          bodyWeights: List.generate(
            7,
            (i) => BodyWeightEntry(
              id: 'bw-$i',
              measuredAt: now.subtract(Duration(days: (6 - i) * 7)),
              weightKg: 76.5 - i * .2,
            ),
          ),
        );
      if (screen != '01-home') {
        repository.value = repository.value.copyWith(
          activeWorkout: WorkoutSession(
            id: 'active-example',
            name: 'Full body strength',
            startedAt: now.subtract(const Duration(minutes: 34, seconds: 12)),
            exercises: movements('active', 57.5, active: true),
          ),
        );
      }
      final controller = Get.put(
        WorkoutController(repository, repository.value, clock: () => now),
      );
      controller.onClose();
      final boundary = GlobalKey();
      final currentScreen = ValueNotifier<Widget>(const SizedBox.shrink());
      var mounted = false;
      Future<void> mount(Widget screen) async {
        debugPrint('Mounting ${screen.runtimeType}');
        currentScreen.value = screen;
        if (!mounted) {
          await tester.pumpWidget(
            GetMaterialApp(
              theme: AppTheme.dark,
              debugShowCheckedModeBanner: false,
              builder: (context, child) => RepaintBoundary(
                key: boundary,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    disableAnimations: true,
                    padding: const EdgeInsets.only(top: 26, bottom: 12),
                  ),
                  child: child!,
                ),
              ),
              home: ValueListenableBuilder<Widget>(
                valueListenable: currentScreen,
                builder: (context, screen, _) => screen,
              ),
            ),
          );
          mounted = true;
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        debugPrint('Mounted ${screen.runtimeType}');
      }

      Future<void> capture(String name) async {
        debugPrint('Capturing $name');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        final visibleImages = find.byType(Image).evaluate().toList();
        await tester.runAsync(() async {
          for (final element in visibleImages) {
            await precacheImage((element.widget as Image).image, element);
          }
        });
        await tester.pump();
        // flutter_tester forces the Ahem font for otherwise unspecified families.
        // Android uses Roboto for those labels; use that same fallback here.
        InlineSpan androidFonts(InlineSpan span) => span is TextSpan
            ? TextSpan(
                text: span.text,
                style: (span.style ?? const TextStyle()).copyWith(
                  fontFamily: span.style?.fontFamily ?? 'Roboto',
                ),
                children: span.children?.map(androidFonts).toList(),
                recognizer: span.recognizer,
                semanticsLabel: span.semanticsLabel,
              )
            : span;
        for (final element in find.byType(RichText).evaluate()) {
          final render = element.renderObject;
          if (render is RenderParagraph) {
            render.text = androidFonts(render.text);
          }
        }
        await tester.pump();
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await render.toImage(pixelRatio: 2.7);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('../store-assets/raw/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(), isNull);
        debugPrint('Captured $name');
      }

      ExerciseProgressController? progress;
      switch (screen) {
        case '01-home':
          await mount(const AppShell(index: 0, child: HomePage()));
        case '02-workout':
          await mount(const WorkoutPage());
        case '03-exercises' || '04-exercise-details':
          await mount(const AppShell(index: 3, child: ExercisesPage()));
          if (screen == '04-exercise-details') {
            await tester.tap(find.text('Barbell Bench Press').first);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 700));
          }
        case '05-exercise-progress':
          progress = ExerciseProgressController(
            controller,
            const ExerciseProgressArguments(
              exerciseId: 'repdb_bench-press',
              name: 'Barbell Bench Press',
            ),
            clock: () => now,
          );
          await mount(ExerciseProgressPage(controller: progress));
        case '06-calendar':
          await mount(const AppShell(index: 2, child: ProgressPage()));
          await tester.scrollUntilVisible(
            find.text('Workout consistency'),
            180,
            scrollable: find.byType(Scrollable).first,
          );
          await Scrollable.ensureVisible(
            tester.element(find.text('Workout consistency')),
            alignment: 0.02,
          );
      }
      await capture(screen);
      progress?.onClose();
    });
  }
}
