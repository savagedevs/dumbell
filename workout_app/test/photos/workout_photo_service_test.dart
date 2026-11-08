import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/features/workout/media/workout_photo_service.dart';

final png = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0]);

void main() {
  test(
    'deleted workout cleanup removes attached and pending replacement photos',
    () async {
      final store = MemoryPhotoStore()
        ..files['workout_photos/attached.png'] = png
        ..files['workout_photos/replacement.png'] = png
        ..pending = const PendingWorkoutPhoto(
          workoutId: 'deleted',
          relativePath: 'workout_photos/replacement.png',
        );
      final service = WorkoutPhotoService(
        store: store,
        picker: FakePhotoPicker(() async => null),
      );
      await service.cleanupDeletedWorkout(
        workoutId: 'deleted',
        attachedPath: 'workout_photos/attached.png',
      );
      expect(store.files, isEmpty);
      expect(store.pending, isNull);
    },
  );

  test(
    'deleted workout cleanup preserves another workout pending photo',
    () async {
      final store = MemoryPhotoStore()
        ..files['workout_photos/attached.png'] = png
        ..files['workout_photos/other.png'] = png
        ..pending = const PendingWorkoutPhoto(
          workoutId: 'other',
          relativePath: 'workout_photos/other.png',
        );
      final service = WorkoutPhotoService(
        store: store,
        picker: FakePhotoPicker(() async => null),
      );
      await service.cleanupDeletedWorkout(
        workoutId: 'deleted',
        attachedPath: 'workout_photos/attached.png',
      );
      expect(store.files.keys, ['workout_photos/other.png']);
      expect(store.pending?.workoutId, 'other');
      expect(store.pending?.relativePath, 'workout_photos/other.png');
    },
  );

  test(
    'completing an older attachment cannot clear a newer picker recovery',
    () async {
      final store = MemoryPhotoStore();
      final service = WorkoutPhotoService(
        store: store,
        picker: FakePhotoPicker(() async => PickedWorkoutImage(bytes: png)),
      );
      final old = await service.pickPhoto(
        'old-workout',
        WorkoutPhotoSource.gallery,
      );
      final latest = await service.pickPhoto(
        'new-workout',
        WorkoutPhotoSource.gallery,
      );
      await service.completeRecovery(
        expectedPath: old,
        workoutId: 'old-workout',
      );
      final recovered = await service.recoverLostPhoto();
      expect(recovered?.relativePath, latest);
      expect(recovered?.workoutId, 'new-workout');
      await service.completeRecovery(
        expectedPath: latest,
        workoutId: 'new-workout',
      );
      expect(await service.recoverLostPhoto(), isNull);
    },
  );

  test('persists target before picker and retains durable result until attachment commits', () async {
    final store = MemoryPhotoStore();
    final picker = FakePhotoPicker(() async {
      expect(store.pending?.workoutId, 'workout-a');
      return PickedWorkoutImage(bytes: png);
    });
    final service = WorkoutPhotoService(store: store, picker: picker);
    final path = await service.pickPhoto(
      'workout-a',
      WorkoutPhotoSource.gallery,
    );
    expect(path, startsWith('workout_photos/'));
    expect(store.files[path], png);
    expect((await service.recoverLostPhoto())?.workoutId, 'workout-a');
    expect((await service.recoverLostPhoto())?.relativePath, path);
    await service.completeRecovery();
    expect(store.pending, isNull);
    expect(store.files[path], png);
  });

  test('cancel and invalid file preserve existing durable photo', () async {
    final store = MemoryPhotoStore()..files['workout_photos/old.jpg'] = png;
    final canceled = WorkoutPhotoService(
      store: store,
      picker: FakePhotoPicker(() async => null),
    );
    expect(
      await canceled.pickPhoto('workout-a', WorkoutPhotoSource.camera),
      isNull,
    );
    expect(store.pending, isNull);
    final invalid = WorkoutPhotoService(
      store: store,
      picker: FakePhotoPicker(
        () async => PickedWorkoutImage(bytes: Uint8List.fromList([1, 2, 3])),
      ),
    );
    await expectLater(
      invalid.pickPhoto('workout-a', WorkoutPhotoSource.gallery),
      throwsFormatException,
    );
    expect(store.files.keys, ['workout_photos/old.jpg']);
  });

  test(
    'lost Android picker result attaches only to its persisted target',
    () async {
      final store = MemoryPhotoStore()
        ..pending = const PendingWorkoutPhoto(workoutId: 'correct-target');
      final picker = FakePhotoPicker(() async => null)
        ..lost = PickedWorkoutImage(bytes: png);
      final service = WorkoutPhotoService(store: store, picker: picker);
      final recovered = await service.recoverLostPhoto();
      expect(recovered?.workoutId, 'correct-target');
      expect(store.pending?.relativePath, recovered?.relativePath);
      expect(await service.readPhoto(recovered!.relativePath), png);
    },
  );

  test('orphan lost picker data cannot be applied to a workout', () async {
    final store = MemoryPhotoStore();
    final picker = FakePhotoPicker(() async => null)
      ..lost = PickedWorkoutImage(bytes: png);
    expect(
      await WorkoutPhotoService(
        store: store,
        picker: picker,
      ).recoverLostPhoto(),
      isNull,
    );
    expect(store.files, isEmpty);
  });

  test(
    'oversized photo and failed durable write never publish a path',
    () async {
      final store = MemoryPhotoStore();
      final huge = WorkoutPhotoService(
        store: store,
        picker: FakePhotoPicker(
          () async => PickedWorkoutImage(
            bytes: Uint8List(WorkoutPhotoService.maxPhotoBytes + 1),
          ),
        ),
      );
      await expectLater(
        huge.pickPhoto('a', WorkoutPhotoSource.gallery),
        throwsFormatException,
      );
      expect(store.files, isEmpty);
      store.failWrite = true;
      final service = WorkoutPhotoService(
        store: store,
        picker: FakePhotoPicker(() async => PickedWorkoutImage(bytes: png)),
      );
      await expectLater(
        service.pickPhoto('a', WorkoutPhotoSource.gallery),
        throwsStateError,
      );
      expect(store.pending?.relativePath, isNull);
    },
  );
}

class MemoryPhotoStore implements WorkoutPhotoStore {
  PendingWorkoutPhoto? pending;
  final files = <String, Uint8List>{};
  bool failWrite = false;
  bool failClear = false;
  @override
  Future<PendingWorkoutPhoto?> readPending() async => pending;
  @override
  Future<void> writePending(PendingWorkoutPhoto? value) async {
    if (value == null && failClear) {
      throw StateError('Pending state could not be cleared');
    }
    pending = value;
  }

  @override
  Future<void> writePhoto(String path, Uint8List bytes) async {
    if (failWrite) throw StateError('Disk full');
    files[path] = bytes;
  }

  @override
  Future<Uint8List> readPhoto(String path) async =>
      files[path] ?? (throw StateError('Missing photo'));
  @override
  Future<void> deletePhoto(String path) async {
    files.remove(path);
  }
}

class FakePhotoPicker implements WorkoutImagePicker {
  FakePhotoPicker(this.onPick);
  final Future<PickedWorkoutImage?> Function() onPick;
  PickedWorkoutImage? lost;
  @override
  Future<PickedWorkoutImage?> pick(WorkoutPhotoSource source) => onPick();
  @override
  Future<PickedWorkoutImage?> recover() async => lost;
}
