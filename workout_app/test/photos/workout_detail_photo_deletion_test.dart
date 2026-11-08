import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workout_app/app/workout_controller.dart';
import 'package:workout_app/core/theme.dart';
import 'package:workout_app/data/models.dart';
import 'package:workout_app/features/workout/media/workout_photo_service.dart';
import 'package:workout_app/features/workout/workout_detail_page.dart';

import '../support/memory_repository.dart';
import 'workout_photo_service_test.dart' show MemoryPhotoStore, FakePhotoPicker;

void main() {
  for (final scenario in [
    'success',
    'database failure',
    'cleanup failure',
    'unrelated recovery',
  ]) {
    testWidgets('workout deletion handles attached photo on $scenario', (
      tester,
    ) async {
      Get.testMode = true;
      final repository = MemoryRepository()
        ..failWrites = scenario == 'database failure';
      final session = WorkoutSession(
        id: 'saved',
        name: 'Strength',
        startedAt: DateTime.utc(2026),
        finishedAt: DateTime.utc(2026),
        exercises: [],
        photoPath: 'workout_photos/saved.png',
      );
      final workouts = Get.put(
        WorkoutController(repository, AppData(history: [session])),
      );
      final store = _DeletionPhotoStore()
        ..files[session.photoPath!] = Uint8List.fromList([1, 2, 3])
        ..pending = PendingWorkoutPhoto(
          workoutId: scenario == 'unrelated recovery'
              ? 'other-workout'
              : session.id,
          relativePath: session.photoPath,
        )
        ..failClear = scenario == 'cleanup failure'
        ..failDelete = scenario == 'cleanup failure';
      if (scenario == 'success' || scenario == 'unrelated recovery') {
        store.files['workout_photos/pending.png'] = Uint8List.fromList([
          4,
          5,
          6,
        ]);
        store.pending = PendingWorkoutPhoto(
          workoutId: scenario == 'success' ? session.id : 'other-workout',
          relativePath: 'workout_photos/pending.png',
        );
      }
      Get.put(
        WorkoutPhotoService(
          store: store,
          picker: FakePhotoPicker(() async => null),
        ),
      );
      try {
        await tester.pumpWidget(
          GetMaterialApp(
            theme: AppTheme.dark,
            home: const Scaffold(body: Text('Workout list')),
          ),
        );
        Get.to<void>(() => const WorkoutDetailPage(), arguments: session.id);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Workout options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete workout'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Delete workout'));
        await tester.pumpAndSettle();
        if (scenario == 'database failure') {
          expect(workouts.history.single.id, session.id);
          expect(store.files.keys, [session.photoPath]);
          expect(store.pending?.workoutId, session.id);
          expect(find.text('WORKOUT DETAILS'), findsOneWidget);
        } else {
          expect(workouts.history, isEmpty);
          expect(find.text('Workout list'), findsOneWidget);
          if (scenario == 'success') {
            expect(store.files, isEmpty);
            expect(store.pending, isNull);
          } else if (scenario == 'unrelated recovery') {
            expect(store.files.keys, ['workout_photos/pending.png']);
            expect(store.pending?.workoutId, 'other-workout');
          }
        }
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await Get.delete<WorkoutController>(force: true);
        workouts.onClose();
        Get.reset();
      }
    });
  }
}

class _DeletionPhotoStore extends MemoryPhotoStore {
  bool failDelete = false;
  @override
  Future<void> deletePhoto(String path) async {
    if (failDelete) throw StateError('Could not delete private file');
    await super.deletePhoto(path);
  }
}
