import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'workout_photo_types.dart';

class NativeWorkoutImagePicker implements WorkoutImagePicker {
  final _picker = ImagePicker();

  @override
  Future<PickedWorkoutImage?> pick(WorkoutPhotoSource source) async {
    final image = await _picker.pickImage(
      source: source == WorkoutPhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 2400,
      requestFullMetadata: false,
    );
    return image == null ? null : _read(image);
  }

  @override
  Future<PickedWorkoutImage?> recover() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final result = await _picker.retrieveLostData();
    if (result.exception != null) throw result.exception!;
    final images = result.files;
    if (images == null || images.isEmpty) return null;
    return _read(images.first);
  }

  Future<PickedWorkoutImage> _read(XFile image) async {
    if (await image.length() > maxWorkoutPhotoBytes) {
      throw const FormatException('Choose a photo smaller than 12 MiB.');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in image.openRead()) {
      if (builder.length + chunk.length > maxWorkoutPhotoBytes) {
        throw const FormatException('Choose a photo smaller than 12 MiB.');
      }
      builder.add(chunk);
    }
    return PickedWorkoutImage(bytes: builder.takeBytes());
  }
}
