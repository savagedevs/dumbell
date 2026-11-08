import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/workout_controller.dart';
import '../../../core/theme.dart';
import '../../../data/exercise_catalog.dart';
import '../../exercise_progress/widgets/exercise_graph_preview.dart';
import 'exercise_attribution.dart';
import 'exercise_media_panel.dart';

class ExerciseDetails extends StatelessWidget {
  const ExerciseDetails({
    super.key,
    required this.exercise,
    required this.controller,
    required this.onAdd,
  });
  final ExerciseDefinition exercise;
  final WorkoutController controller;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .88,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              exercise.name,
              style: const TextStyle(
                fontSize: 30,
                height: 1.1,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [exercise.muscleGroup, exercise.equipment]
                  .map(
                    (label) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.elevated,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: Obx(
                () => FilledButton.icon(
                  onPressed: controller.isSaving.value ? null : onAdd,
                  icon: Icon(
                    controller.activeWorkout == null
                        ? Icons.home_rounded
                        : Icons.add_rounded,
                  ),
                  label: Text(
                    controller.activeWorkout == null
                        ? 'Go to Home to start'
                        : 'Add to workout',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ExerciseMediaPanel(exercise: exercise),
            if (exercise.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                exercise.description,
                style: const TextStyle(color: AppColors.muted, height: 1.6),
              ),
            ],
            const SizedBox(height: 18),
            const Text(
              'FORM CUES',
              style: TextStyle(
                color: AppColors.lime,
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            ...List.generate(
              exercise.instructions.length,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.elevated,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: AppColors.lime,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Text(
                        exercise.instructions[index],
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (exercise.tips.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Text(
                'TIPS',
                style: TextStyle(
                  color: AppColors.lime,
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              ...exercise.tips.map(
                (tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Icon(
                          Icons.check_rounded,
                          color: AppColors.lime,
                          size: 17,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tip,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ExerciseGraphPreview(
              workouts: controller,
              exerciseId: exercise.id,
              exerciseName: exercise.name,
            ),
            const SizedBox(height: 18),
            ExerciseAttributionView(exercise: exercise),
          ],
        ),
      ),
    ),
  );
}
