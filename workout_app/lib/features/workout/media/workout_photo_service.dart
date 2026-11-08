import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'workout_photo_picker.dart';
import 'workout_photo_store_stub.dart'
    if (dart.library.io) 'workout_photo_store_io.dart'
    as storage;
import 'workout_photo_types.dart';

export 'workout_photo_types.dart';

class WorkoutPhotoService {
  WorkoutPhotoService({WorkoutPhotoStore? store, WorkoutImagePicker? picker})
    : _store = store ?? storage.createWorkoutPhotoStore(),
      _picker = picker ?? NativeWorkoutImagePicker();

  static const maxPhotoBytes = maxWorkoutPhotoBytes;
  final WorkoutPhotoStore _store;
  final WorkoutImagePicker _picker;
  bool _busy = false;
  Future<void> _pendingOperations = Future<void>.value();

  Future<T> _withPendingLock<T>(Future<T> Function() action) {
    final result = Completer<T>();
    _pendingOperations = _pendingOperations.then((_) async {
      try {
        result.complete(await action());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  Future<String?> pickPhoto(String workoutId, WorkoutPhotoSource source) async {
    if (_busy) throw StateError('A photo picker is already open.');
    if (workoutId.trim().isEmpty) {
      throw const FormatException('A saved workout is required.');
    }
    _busy = true;
    try {
      // Android can destroy the activity while its picker is on screen.
      // Persist the exact target before handing over to the native activity.
      await _withPendingLock(
        () => _store.writePending(PendingWorkoutPhoto(workoutId: workoutId)),
      );
      final picked = await _picker.pick(source);
      if (picked == null) {
        await completeRecovery(workoutId: workoutId);
        return null;
      }
      return await _storePicked(workoutId, picked);
    } catch (_) {
      try {
        await completeRecovery(workoutId: workoutId);
      } catch (_) {
        /* Keep the persisted target available for recovery. */
      }
      rethrow;
    } finally {
      _busy = false;
    }
  }

  Future<String> _storePicked(String target, PickedWorkoutImage photo) async {
    if (photo.bytes.length > maxPhotoBytes) {
      throw const FormatException('Choose a photo smaller than 12 MiB.');
    }
    final extension = _imageExtension(photo.bytes);
    final token =
        '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';
    final path = 'workout_photos/$token.$extension';
    await _store.writePhoto(path, photo.bytes);
    try {
      await _withPendingLock(() async {
        final pending = await _store.readPending();
        if (pending?.workoutId != target || pending?.relativePath != null) {
          throw StateError('This photo selection was canceled.');
        }
        await _store.writePending(
          PendingWorkoutPhoto(workoutId: target, relativePath: path),
        );
      });
    } catch (_) {
      try {
        await _store.deletePhoto(path);
      } catch (_) {
        /* The previous attachment remains safe. */
      }
      rethrow;
    }
    return path;
  }

  Future<RecoveredWorkoutPhoto?> recoverLostPhoto() async {
    final pending = await _withPendingLock(_store.readPending);
    if (pending == null) return null;
    var path = pending.relativePath;
    if (path == null) {
      final picked = await _picker.recover();
      if (picked == null) {
        await completeRecovery(workoutId: pending.workoutId);
        return null;
      }
      path = await _storePicked(pending.workoutId, picked);
    }
    validatePhotoPath(path);
    return RecoveredWorkoutPhoto(
      workoutId: pending.workoutId,
      relativePath: path,
    );
  }

  /// Only clear the pending recovery after WorkoutController has committed the
  /// attachment. A failed repository write must be recoverable on next launch.
  Future<void> completeRecovery({String? expectedPath, String? workoutId}) =>
      _withPendingLock(() async {
        final pending = await _store.readPending();
        if (pending == null) return;
        if (expectedPath != null && pending.relativePath != expectedPath) {
          return;
        }
        if (workoutId != null && pending.workoutId != workoutId) return;
        await _store.writePending(null);
      });

  Future<Uint8List> readPhoto(String relativePath) {
    validatePhotoPath(relativePath);
    return _store.readPhoto(relativePath);
  }

  /// Call after the workout deletion has committed. Capture and clear only this
  /// workout's pending replacement under the same queue as picker updates,
  /// then remove both distinct files. Attempt all cleanup even if one fails.
  Future<void> cleanupDeletedWorkout({
    required String workoutId,
    String? attachedPath,
  }) async {
    final paths = <String>{?attachedPath};
    Object? firstError;
    StackTrace? firstStack;
    Future<void> attempt(Future<void> Function() action) async {
      try {
        await action();
      } catch (error, stack) {
        firstError ??= error;
        firstStack ??= stack;
      }
    }

    await attempt(
      () => _withPendingLock(() async {
        final pending = await _store.readPending();
        if (pending?.workoutId != workoutId) return;
        final pendingPath = pending?.relativePath;
        if (pendingPath != null) paths.add(pendingPath);
        await _store.writePending(null);
      }),
    );
    for (final path in paths) {
      await attempt(() => deletePhoto(path));
    }
    if (firstError != null) Error.throwWithStackTrace(firstError!, firstStack!);
  }

  Future<void> deletePhoto(String relativePath) {
    validatePhotoPath(relativePath);
    return _store.deletePhoto(relativePath);
  }
}

String _imageExtension(Uint8List bytes) {
  bool prefix(List<int> value) =>
      bytes.length >= value.length &&
      List.generate(value.length, (i) => bytes[i] == value[i]).every((v) => v);
  if (prefix([137, 80, 78, 71, 13, 10, 26, 10])) return 'png';
  if (prefix([255, 216, 255])) return 'jpg';
  if (prefix([71, 73, 70, 56])) return 'gif';
  if (bytes.length >= 12 &&
      prefix([82, 73, 70, 70]) &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return 'webp';
  }
  throw const FormatException('Choose a JPEG, PNG, WebP or GIF photo.');
}
