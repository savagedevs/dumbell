import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../data/exercise_catalog.dart';
import 'exercise_image.dart';

class ExerciseThumbnail extends StatelessWidget {
  const ExerciseThumbnail({super.key, required this.exercise});

  final ExerciseDefinition exercise;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: SizedBox.square(
      dimension: 66,
      child: exercise.hasImage
          ? ExerciseImage(
              exerciseName: exercise.name,
              illustration: exercise.illustrations.first,
              compact: true,
            )
          : const ColoredBox(
              color: AppColors.elevated,
              child: Icon(
                Icons.image_outlined,
                color: AppColors.lime,
                size: 27,
              ),
            ),
    ),
  );
}
