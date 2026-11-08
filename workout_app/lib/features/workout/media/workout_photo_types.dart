import 'dart:typed_data';

const maxWorkoutPhotoBytes = 12 * 1024 * 1024;

enum WorkoutPhotoSource { camera, gallery }

class PickedWorkoutImage {
  const PickedWorkoutImage({required this.bytes});
  final Uint8List bytes;
}

class PendingWorkoutPhoto {
  const PendingWorkoutPhoto({required this.workoutId, this.relativePath});
  final String workoutId;
  final String? relativePath;
}

class RecoveredWorkoutPhoto {
  const RecoveredWorkoutPhoto({
    required this.workoutId,
    required this.relativePath,
  });
  final String workoutId;
  final String relativePath;
  String get path => relativePath;
}

abstract interface class WorkoutImagePicker {
  Future<PickedWorkoutImage?> pick(WorkoutPhotoSource source);
  Future<PickedWorkoutImage?> recover();
}

abstract interface class WorkoutPhotoStore {
  Future<PendingWorkoutPhoto?> readPending();
  Future<void> writePending(PendingWorkoutPhoto? pending);
  Future<void> writePhoto(String relativePath, Uint8List bytes);
  Future<Uint8List> readPhoto(String relativePath);
  Future<void> deletePhoto(String relativePath);
}

void validatePhotoPath(String path) {
  if (!RegExp(r'^workout_photos/[a-zA-Z0-9_-]+\.(jpg|png|webp|gif)$')
      .hasMatch(path)) {
    throw const FormatException('Invalid private photo path.');
  }
}
