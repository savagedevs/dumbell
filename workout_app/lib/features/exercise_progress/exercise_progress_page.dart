import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/exercise_performance.dart';
import 'exercise_progress_controller.dart';
import 'widgets/exercise_trend_chart.dart';

class ExerciseProgressPage extends StatelessWidget {
  const ExerciseProgressPage({super.key, required this.controller});
  final ExerciseProgressController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Exercise progress')),
    body: SafeArea(
      top: false,
      child: Obx(() {
        final all = controller.allSessions;
        final points = controller.sessions;
        final selected = controller.selected;
        final unit = controller.unit;
        final definition = definitionForExercise(
          controller.exercise.exerciseId,
          name: controller.exercise.name,
        );
        final title = definition?.name ?? controller.exercise.name;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              children: [
                const Text(
                  'EVERY REP ADDS UP',
                  style: TextStyle(
                    color: AppColors.lime,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 32,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${all.length} saved ${all.length == 1 ? 'workout' : 'workouts'} · Completed sets only',
                  style: const TextStyle(color: AppColors.muted, height: 1.5),
                ),
                const SizedBox(height: 24),
                if (all.isEmpty)
                  const AppCard(
                    child: EmptyState(
                      icon: Icons.show_chart_rounded,
                      title: 'Your first point starts here.',
                      message: 'Complete a set for this exercise and save the workout. Your weights, volume and reps will appear here.',
                    ),
                  )
                else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final metric in ExerciseChartMetric.values)
                        ChoiceChip(
                          label: Text(switch (metric) {
                            ExerciseChartMetric.topWeight => 'Top weight',
                            ExerciseChartMetric.volume => 'Volume',
                            ExerciseChartMetric.reps => 'Reps',
                          }),
                          selected: controller.metric.value == metric,
                          onSelected: (_) => controller.metric.value = metric,
                          showCheckmark: false,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final range in ExerciseChartRange.values)
                        ChoiceChip(
                          label: Text(switch (range) {
                            ExerciseChartRange.month => '4 weeks',
                            ExerciseChartRange.quarter => '12 weeks',
                            ExerciseChartRange.all => 'All time',
                          }),
                          selected: controller.range.value == range,
                          onSelected: (_) => controller.range.value = range,
                          showCheckmark: false,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (points.isEmpty)
                    const AppCard(
                      child: Text(
                        'No completed sets in this period. Choose All time to see older workouts.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    )
                  else ...[
                    AppCard(
                      child: ExerciseTrendChart(
                        points: points,
                        selectedId: selected?.workoutId,
                        valueOf: controller.valueOf,
                        formatValue: controller.formatValue,
                        metricLabel: controller.metricLabel,
                        axisLabel: controller.axisLabel,
                        onSelected: (point) =>
                            controller.selectedWorkoutId.value =
                                point.workoutId,
                      ),
                    ),
                    if (controller.metric.value ==
                            ExerciseChartMetric.topWeight &&
                        points.every((point) => point.topWeightKg == 0)) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Bodyweight sets use the external load you logged. Choose Reps to see repetition progress.',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    if (selected != null)
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatDate(selected.startedAt),
                              style: const TextStyle(
                                color: AppColors.lime,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.end,
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Text(
                                  controller.formatValue(
                                    controller.valueOf(selected),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 7),
                                  child: Text(
                                    controller.axisLabel,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              controller.metricLabel,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                for (var i = 0; i < selected.sets.length; i++)
                                  Text(
                                    '${i + 1}. ${formatWeight(selected.sets[i].weightKg, unit)} ${unit.label} × ${selected.sets[i].reps}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () => Get.toNamed(
                                AppRoutes.detail,
                                arguments: selected.workoutId,
                              ),
                              icon: const Icon(Icons.history_rounded, size: 18),
                              label: const Text('Open workout'),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    const SectionHeading(title: 'Recorded workouts'),
                    const SizedBox(height: 12),
                    for (final point in points.reversed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          tileColor: point.workoutId == selected?.workoutId
                              ? AppColors.elevated
                              : AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          selected: point.workoutId == selected?.workoutId,
                          selectedColor: AppColors.text,
                          onTap: () => controller.selectedWorkoutId.value =
                              point.workoutId,
                          title: Text(
                            formatDate(point.startedAt),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${point.completedSets} completed ${point.completedSets == 1 ? 'set' : 'sets'} · ${formatWeight(point.topWeightKg, unit)} ${unit.label} top weight',
                          ),
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),
        );
      }),
    ),
  );
}
