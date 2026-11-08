import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workout_app/app/workout_controller.dart';
import 'package:workout_app/core/theme.dart';
import 'package:workout_app/data/models.dart';
import 'package:workout_app/features/workout/media/workout_photo_service.dart';
import 'package:workout_app/features/workout/widgets/workout_photo_card.dart';

import '../support/memory_repository.dart';
import 'workout_photo_service_test.dart' show MemoryPhotoStore, FakePhotoPicker;

void main() {
  testWidgets(
    'failed recovery cleanup keeps the attachment instead of allowing removed photo resurrection',
    (tester) async {
      Get.testMode = true;
      final session = WorkoutSession(
        id: 'a',
        name: 'Strength',
        startedAt: DateTime.utc(2026),
        finishedAt: DateTime.utc(2026),
        photoPath: 'workout_photos/old.png',
        exercises: [],
      );
      final repository = MemoryRepository();
      final workouts = WorkoutController(
        repository,
        AppData(history: [session]),
      );
      final store = MemoryPhotoStore()
        ..files['workout_photos/old.png'] = Uint8List.fromList([1, 2, 3])
        ..pending = const PendingWorkoutPhoto(
          workoutId: 'a',
          relativePath: 'workout_photos/old.png',
        )
        ..failClear = true;
      final service = WorkoutPhotoService(
        store: store,
        picker: FakePhotoPicker(() async => null),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: WorkoutPhotoCard(
                session: session,
                workouts: workouts,
                service: service,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Remove photo'));
      await tester.tap(find.text('Remove photo'));
      await tester.pumpAndSettle();
      expect(workouts.history.single.photoPath, 'workout_photos/old.png');
      expect(store.files.keys, ['workout_photos/old.png']);
      expect(repository.writes, 0);
      expect(find.textContaining('Could not remove'), findsOneWidget);
    },
  );

  testWidgets(
    'removal deletes the captured old file after the parent rebuilds',
    (tester) async {
      Get.testMode = true;
      final session = WorkoutSession(
        id: 'a',
        name: 'Strength',
        startedAt: DateTime.utc(2026),
        finishedAt: DateTime.utc(2026),
        photoPath: 'workout_photos/old.png',
        exercises: [],
      );
      final workouts = WorkoutController(
        MemoryRepository(),
        AppData(history: [session]),
      );
      final store = MemoryPhotoStore()
        ..files['workout_photos/old.png'] = Uint8List.fromList([1, 2, 3]);
      final service = WorkoutPhotoService(
        store: store,
        picker: FakePhotoPicker(() async => null),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Obx(
                () => WorkoutPhotoCard(
                  session: workouts.history.single,
                  workouts: workouts,
                  service: service,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Remove photo'));
      await tester.tap(find.text('Remove photo'));
      await tester.pumpAndSettle();
      expect(workouts.history.single.photoPath, isNull);
      expect(store.files, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'canceling the gallery keeps the original saved photo and fits large text',
    (tester) async {
      Get.testMode = true;
      tester.view.physicalSize = const Size(320, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final image = Uint8List.fromList(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+lmWQAAAAASUVORK5CYII=',
        ),
      );
      final session = WorkoutSession(
        id: 'a',
        name: 'Strength',
        startedAt: DateTime.utc(2026),
        finishedAt: DateTime.utc(2026),
        photoPath: 'workout_photos/old.png',
        exercises: [],
      );
      final repository = MemoryRepository();
      final workouts = WorkoutController(
        repository,
        AppData(history: [session]),
      );
      final store = MemoryPhotoStore()..files['workout_photos/old.png'] = image;
      final service = WorkoutPhotoService(
        store: store,
        picker: FakePhotoPicker(() async => null),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: SingleChildScrollView(
                child: WorkoutPhotoCard(
                  session: session,
                  workouts: workouts,
                  service: service,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from gallery'));
      await tester.pumpAndSettle();
      expect(workouts.history.single.photoPath, 'workout_photos/old.png');
      expect(repository.writes, 0);
      expect(find.text('Photo selection canceled.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
