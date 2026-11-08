import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes.dart';
import '../../../app/workout_controller.dart';
import '../../../core/formatters.dart';
import '../../../core/theme.dart';
import '../exercise_progress_controller.dart';
import 'exercise_trend_chart.dart';

/// Inline exercise history, with state scoped to this details sheet.
class ExerciseGraphPreview extends StatefulWidget {
  const ExerciseGraphPreview({
    super.key,
    required this.workouts,
    required this.exerciseId,
    required this.exerciseName,
  });

  final WorkoutController workouts;
  final String exerciseId, exerciseName;

  @override
  State<ExerciseGraphPreview> createState() => _ExerciseGraphPreviewState();
}

class _ExerciseGraphPreviewState extends State<ExerciseGraphPreview> {
  late ExerciseProgressController _progress;

  ExerciseProgressArguments get _arguments => ExerciseProgressArguments(
    exerciseId: widget.exerciseId,
    name: widget.exerciseName,
  );

  @override
  void initState() {
    super.initState();
    _progress = ExerciseProgressController(widget.workouts, _arguments);
  }

  @override
  void didUpdateWidget(covariant ExerciseGraphPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exerciseId != widget.exerciseId ||
        oldWidget.workouts != widget.workouts) {
      _progress.onClose();
      _progress = ExerciseProgressController(widget.workouts, _arguments);
    }
  }

  @override
  void dispose() {
    _progress.onClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Obx(() {
    final points = _progress.allSessions;
    final selected = _progress.selected;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.elevated),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Your progress',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              TextButton.icon(
                onPressed: () => Get.toNamed(
                  AppRoutes.exerciseProgress,
                  arguments: _arguments,
                ),
                icon: const Icon(Icons.open_in_full_rounded, size: 16),
                label: const Text('Full graph'),
              ),
            ],
          ),
          if (points.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Complete a set and save a workout for this exercise to see your graph.',
                style: TextStyle(color: AppColors.muted, height: 1.5),
              ),
            )
          else ...[
            Text(
              '${points.length} saved ${points.length == 1 ? 'workout' : 'workouts'} · Completed sets only',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final metric in ExerciseChartMetric.values)
                  ChoiceChip(
                    label: Text(switch (metric) {
                      ExerciseChartMetric.topWeight => 'Top weight',
                      ExerciseChartMetric.volume => 'Volume',
                      ExerciseChartMetric.reps => 'Reps',
                    }),
                    selected: _progress.metric.value == metric,
                    onSelected: (_) => _progress.metric.value = metric,
                    showCheckmark: false,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ExerciseTrendChart(
              points: points,
              selectedId: selected?.workoutId,
              valueOf: _progress.valueOf,
              formatValue: _progress.formatValue,
              metricLabel: _progress.metricLabel,
              axisLabel: _progress.axisLabel,
              onSelected: (point) =>
                  _progress.selectedWorkoutId.value = point.workoutId,
            ),
            if (selected != null) ...[
              const SizedBox(height: 12),
              Text(
                '${_progress.formatValue(_progress.valueOf(selected))} ${_progress.axisLabel} · ${formatDate(selected.startedAt)}',
                style: const TextStyle(
                  color: AppColors.lime,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (_progress.metric.value == ExerciseChartMetric.topWeight &&
                points.every((point) => point.topWeightKg == 0)) ...[
              const SizedBox(height: 8),
              const Text(
                'Only added weight is shown. Choose Reps to track repetition progress.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ],
        ],
      ),
    );
  });
}
