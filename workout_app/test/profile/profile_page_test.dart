import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workout_app/app/workout_controller.dart';
import 'package:workout_app/core/theme.dart';
import 'package:workout_app/data/models.dart';
import 'package:workout_app/features/home/home_page.dart';
import 'package:workout_app/features/profile/profile_controller.dart';
import 'package:workout_app/features/profile/profile_page.dart';

import '../support/memory_repository.dart';

void main() {
  setUp(() => Get.testMode = true);
  tearDown(() => Get.reset());

  Future<ProfileController> mount(
    WidgetTester tester, {
    bool editing = false,
    double width = 390,
    double textScale = 1,
    bool reducedMotion = false,
    MemoryRepository? repository,
    VoidCallback? onFinished,
  }) async {
    tester.view.physicalSize = Size(width, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = repository ?? MemoryRepository();
    final workouts = Get.put(WorkoutController(data, data.value));
    workouts.onClose();
    final form = Get.put(
      ProfileController(
        workouts,
        editing: editing,
        onFinished: onFinished ?? () {},
      ),
    );
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reducedMotion,
          ),
          child: child!,
        ),
        home: const ProfilePage(),
      ),
    );
    await tester.pumpAndSettle();
    return form;
  }

  testWidgets('onboarding requires a name before saving optional details', (
    tester,
  ) async {
    final repository = MemoryRepository();
    var finished = false;
    await mount(
      tester,
      repository: repository,
      onFinished: () => finished = true,
    );
    expect(find.text('Skip for now'), findsNothing);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Starting weight (optional)'), findsOneWidget);
    final save = find.byKey(const ValueKey('profile-save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Enter your name.'), findsWidgets);
    expect(repository.writes, 0);
    expect(repository.value.onboardingCompleted, isFalse);
    expect(finished, isFalse);

    final name = find.byKey(const ValueKey('profile-name'));
    await tester.ensureVisible(name);
    await tester.enterText(name, '  Karti Sharma  ');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repository.value.onboardingCompleted, isTrue);
    expect(repository.value.profile!.name, 'Karti Sharma');
    expect(repository.value.profile!.goal, 'Stay consistent');
    expect(repository.value.profile!.experience, 'Beginner');
    expect(repository.value.bodyWeights, isEmpty);
    expect(finished, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'invalid starting weight stays on the form with inline feedback',
    (tester) async {
      final repository = MemoryRepository();
      await mount(tester, repository: repository);
      await tester.enterText(
        find.byKey(const ValueKey('profile-name')),
        'Karti',
      );
      final weight = find.byKey(const ValueKey('profile-weight'));
      await tester.ensureVisible(weight);
      await tester.enterText(weight, '-5');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('profile-save')));
      await tester.tap(find.byKey(const ValueKey('profile-save')));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a weight greater than zero, or leave this blank.'),
        findsWidgets,
      );
      expect(repository.writes, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('editing requires a name and hides initial weight', (
    tester,
  ) async {
    final repository = MemoryRepository()
      ..value = AppData(
        onboardingCompleted: true,
        profile: UserProfile(
          name: 'Karti',
          goal: 'Build muscle',
          experience: 'Advanced',
        ),
      );
    await mount(tester, editing: true, repository: repository);
    expect(find.text('Skip for now'), findsNothing);
    expect(find.byKey(const ValueKey('profile-weight')), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('profile-name')))
          .controller!
          .text,
      'Karti',
    );
    final name = find.byKey(const ValueKey('profile-name'));
    await tester.enterText(name, '   ');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your name.'), findsWidgets);
    expect(repository.writes, 0);
    expect(repository.value.profile!.name, 'Karti');

    await tester.ensureVisible(name);
    await tester.enterText(name, 'Asha');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(repository.value.profile!.name, 'Asha');
    expect(repository.value.bodyWeights, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final editing in [false, true]) {
    testWidgets(
      '320px doubled text and reduced motion fit ${editing ? 'editing' : 'onboarding'}',
      (tester) async {
        await mount(
          tester,
          editing: editing,
          width: 320,
          textScale: 2,
          reducedMotion: true,
        );
        expect(tester.takeException(), isNull);
        final scrollable = find.byType(Scrollable).first;
        for (var step = 0; step < 35; step++) {
          final position = tester.state<ScrollableState>(scrollable).position;
          if (position.pixels >= position.maxScrollExtent) break;
          await tester.drag(scrollable, const Offset(0, -320));
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
        expect(find.byKey(const ValueKey('profile-save')), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('Home greets the saved name and shows actual weekly records', (
    tester,
  ) async {
    final repository = MemoryRepository()
      ..value = AppData(
        profile: UserProfile(
          name: 'Karti',
          goal: 'Build strength',
          experience: 'Beginner',
        ),
        onboardingCompleted: true,
        history: [
          WorkoutSession(
            id: 'saved',
            name: 'Upper body',
            startedAt: DateTime(2026, 11, 8, 9),
            finishedAt: DateTime(2026, 11, 8, 10),
            exercises: [
              WorkoutExercise(
                id: 'ex',
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
      );
    final workouts = Get.put(
      WorkoutController(
        repository,
        repository.value,
        clock: () => DateTime(2026, 11, 8, 12),
      ),
    );
    workouts.onClose();
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: HomePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome back, Karti.'), findsOneWidget);
    expect(find.text('1 session'), findsOneWidget);
    expect(workouts.activeWorkout, isNull);
    expect(repository.writes, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
