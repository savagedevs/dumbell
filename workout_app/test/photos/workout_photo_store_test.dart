import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/features/workout/media/workout_photo_store_io.dart';
import 'package:workout_app/features/workout/media/workout_photo_types.dart';

void main() {
  test(
    'private photos and pending targets survive recreating the storage service',
    () async {
      final root = await Directory.systemTemp.createTemp('liftlog-photo-test-');
      addTearDown(() => root.delete(recursive: true));
      final store = PrivateWorkoutPhotoStore(
        directoryProvider: () async => root,
      );
      const path = 'workout_photos/retained.png';
      final bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
      await store.writePending(
        const PendingWorkoutPhoto(workoutId: 'target', relativePath: path),
      );
      await store.writePhoto(path, bytes);
      final restarted = PrivateWorkoutPhotoStore(
        directoryProvider: () async => root,
      );
      expect((await restarted.readPending())?.workoutId, 'target');
      expect((await restarted.readPending())?.relativePath, path);
      expect(await restarted.readPhoto(path), bytes);
      await restarted.writePending(null);
      expect(await restarted.readPending(), isNull);
      expect(await restarted.readPhoto(path), bytes);
      await restarted.deletePhoto(path);
      await expectLater(
        restarted.readPhoto(path),
        throwsA(isA<FileSystemException>()),
      );
    },
  );

  test(
    'photo paths cannot read or overwrite outside private photo directory',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'liftlog-photo-path-test-',
      );
      addTearDown(() => root.delete(recursive: true));
      final store = PrivateWorkoutPhotoStore(
        directoryProvider: () async => root,
      );
      for (final path in [
        '../secret.jpg',
        '/tmp/photo.jpg',
        'workout_photos/../photo.jpg',
        'https://example.com/a.jpg',
        'workout_photos/a\\b.jpg',
      ]) {
        await expectLater(
          store.writePhoto(path, Uint8List(1)),
          throwsFormatException,
        );
        await expectLater(store.readPhoto(path), throwsFormatException);
      }
      expect(await root.list().toList(), isEmpty);
    },
  );
}
