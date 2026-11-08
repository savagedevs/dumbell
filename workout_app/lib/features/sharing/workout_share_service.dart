import 'dart:typed_data';
import 'dart:ui';

import 'package:share_plus/share_plus.dart';

import 'workout_share_summary.dart';

/// The sole external boundary: opening the OS chooser, never direct posting.
abstract interface class WorkoutShareBoundary {
  Future<ShareResult> share(ShareParams params);
}

class NativeWorkoutShareBoundary implements WorkoutShareBoundary {
  const NativeWorkoutShareBoundary();
  @override
  Future<ShareResult> share(ShareParams params) =>
      SharePlus.instance.share(params);
}

/// Native success reports chooser selection, not proof of a published post.
enum WorkoutShareOutcome { selected, dismissed, unavailable }

class WorkoutShareService {
  const WorkoutShareService({
    this.boundary = const NativeWorkoutShareBoundary(),
  });

  final WorkoutShareBoundary boundary;

  Future<WorkoutShareOutcome> shareImage(
    Uint8List png, {
    required WorkoutShareFormat format,
    required DateTime date,
    required Rect origin,
  }) async {
    if (png.isEmpty || origin.isEmpty || !origin.isFinite) {
      throw ArgumentError('An image and visible share origin are required.');
    }
    final local = date.toLocal();
    final stamp =
        '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
    final result = await boundary.share(
      ShareParams(
        files: [XFile.fromData(png, mimeType: 'image/png')],
        fileNameOverrides: ['Dumbbell_${stamp}_${format.name}.png'],
        title: 'Share workout',
        sharePositionOrigin: origin,
        // If no Web Share API exists, keep the explicit user action local.
        mailToFallbackEnabled: false,
      ),
    );
    return switch (result.status) {
      ShareResultStatus.success => WorkoutShareOutcome.selected,
      ShareResultStatus.dismissed => WorkoutShareOutcome.dismissed,
      ShareResultStatus.unavailable => WorkoutShareOutcome.unavailable,
    };
  }
}
