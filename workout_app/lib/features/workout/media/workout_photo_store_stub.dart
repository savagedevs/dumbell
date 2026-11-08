import 'dart:typed_data';

import 'workout_photo_types.dart';

WorkoutPhotoStore createWorkoutPhotoStore() => _UnsupportedPhotoStore();

class _UnsupportedPhotoStore implements WorkoutPhotoStore {
  Never _unsupported() => throw UnsupportedError(
    'Durable workout photos are available in the mobile app.',
  );
  @override
  Future<PendingWorkoutPhoto?> readPending() async => null;
  @override
  Future<void> writePending(PendingWorkoutPhoto? pending) async =>
      _unsupported();
  @override
  Future<void> writePhoto(String relativePath, Uint8List bytes) async =>
      _unsupported();
  @override
  Future<Uint8List> readPhoto(String relativePath) async => _unsupported();
  @override
  Future<void> deletePhoto(String relativePath) async => _unsupported();
}
