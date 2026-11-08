import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'workout_photo_types.dart';

WorkoutPhotoStore createWorkoutPhotoStore() => PrivateWorkoutPhotoStore();

class PrivateWorkoutPhotoStore implements WorkoutPhotoStore {
  PrivateWorkoutPhotoStore({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;
  final Future<Directory> Function() _directoryProvider;
  Future<Directory>? _rootFuture;
  Future<Directory> _root() => _rootFuture ??= _directoryProvider();

  Future<File> _photo(String relativePath) async {
    validatePhotoPath(relativePath);
    return File(p.join((await _root()).path, relativePath));
  }

  Future<File> _pendingFile() async =>
      File(p.join((await _root()).path, 'pending_workout_photo.json'));

  @override
  Future<PendingWorkoutPhoto?> readPending() async {
    final file = await _pendingFile();
    if (!await file.exists()) return null;
    final raw = jsonDecode(await file.readAsString());
    if (raw is! Map ||
        raw['workoutId'] is! String ||
        (raw['workoutId'] as String).trim().isEmpty) {
      throw const FormatException(
        'The pending photo target could not be read.',
      );
    }
    final path = raw['relativePath'];
    if (path != null) {
      if (path is! String) {
        throw const FormatException('Invalid pending photo.');
      }
      validatePhotoPath(path);
    }
    return PendingWorkoutPhoto(
      workoutId: raw['workoutId'] as String,
      relativePath: path as String?,
    );
  }

  @override
  Future<void> writePending(PendingWorkoutPhoto? pending) async {
    final file = await _pendingFile();
    if (pending == null) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'workoutId': pending.workoutId,
        'relativePath': pending.relativePath,
      }),
      flush: true,
    );
    await temporary.rename(file.path);
  }

  @override
  Future<void> writePhoto(String relativePath, Uint8List bytes) async {
    final file = await _photo(relativePath);
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(file.path);
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }

  @override
  Future<Uint8List> readPhoto(String relativePath) async {
    final file = await _photo(relativePath);
    if (await file.length() > maxWorkoutPhotoBytes) {
      throw const FormatException('This photo exceeds 12 MiB.');
    }
    return file.readAsBytes();
  }

  @override
  Future<void> deletePhoto(String relativePath) async {
    final file = await _photo(relativePath);
    if (await file.exists()) await file.delete();
  }
}
