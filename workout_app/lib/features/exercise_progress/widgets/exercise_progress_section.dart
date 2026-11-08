import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes.dart';
import '../../../app/workout_controller.dart';
import '../../../core/formatters.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../../../data/exercise_performance.dart';
import '../exercise_progress_controller.dart';

class ExerciseProgressSection extends GetView<WorkoutController> {
  const ExerciseProgressSection({super.key});
  @override
  Widget build(BuildContext context) => Obx(() {
    final trends = ExercisePerformance(controller.history).exercises;
    final unit = controller.unit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(title: 'Exercise progress'),
        const SizedBox(height: 10),
        const Text(
          'See your weights, reps and volume for each movement.',
          style: TextStyle(color: AppColors.muted, height: 1.5),
        ),
        const SizedBox(height: 14),
        if (trends.isEmpty)
          const AppCard(
            child: Text(
              'Complete a set and save the workout to start tracking an exercise.',
              style: TextStyle(color: AppColors.muted),
            ),
          )
        else
          for (final trend in trends)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => Get.toNamed(
                  AppRoutes.exerciseProgress,
                  arguments: ExerciseProgressArguments(
                    exerciseId: trend.key,
                    name: trend.name,
                  ),
                ),
                borderRadius: BorderRadius.circular(20),
                child: AppCard(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.show_chart_rounded,
                        color: AppColors.lime,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trend.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${trend.sessions.length} ${trend.sessions.length == 1 ? 'workout' : 'workouts'} · Best ${formatWeight(trend.bestWeightKg, unit)} ${unit.label}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  });
}
