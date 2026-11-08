import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../data/exercise_catalog.dart';

/// The bundled source illustration, shared by library and exercise details.
class ExerciseImage extends StatelessWidget {
  const ExerciseImage({
    super.key,
    required this.exerciseName,
    required this.illustration,
    this.compact = false,
  });

  final String exerciseName;
  final ExerciseIllustration illustration;
  final bool compact;

  @override
  Widget build(BuildContext context) => Image.asset(
    illustration.asset,
    fit: BoxFit.contain,
    semanticLabel: '$exerciseName, ${illustration.label.toLowerCase()} pose',
    errorBuilder: (context, error, stackTrace) => ColoredBox(
      color: AppColors.elevated,
      child: Center(
        child: compact
            ? const Icon(Icons.image_not_supported_outlined, color: Colors.grey)
            : const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Illustration unavailable. Form cues are below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
      ),
    ),
  );
}
