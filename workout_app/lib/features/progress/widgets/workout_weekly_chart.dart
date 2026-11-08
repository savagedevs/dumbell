import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/theme.dart';
import '../../../data/workout_activity.dart';

class WorkoutWeeklyChart extends StatelessWidget {
  const WorkoutWeeklyChart({super.key, required this.weeks});
  final List<WorkoutWeekActivity> weeks;

  @override
  Widget build(BuildContext context) {
    final maxCount = weeks.fold(
      1,
      (value, week) => math.max(value, week.workouts),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaled = MediaQuery.textScalerOf(context).scale(10);
        final width = math.max(
          constraints.maxWidth / weeks.length,
          scaled * 4.5,
        );
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var index = 0; index < weeks.length; index++)
                SizedBox(
                  width: width,
                  child: Semantics(
                    label:
                        'Week of ${formatDate(weeks[index].startedAt)}, ${weeks[index].workouts} workouts',
                    child: ExcludeSemantics(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${weeks[index].workouts}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 22,
                            height: 96,
                            alignment: Alignment.bottomCenter,
                            decoration: BoxDecoration(
                              color: AppColors.elevated,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Container(
                              width: 22,
                              height: 96 * weeks[index].workouts / maxCount,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(7),
                                color: AppColors.lime.withValues(
                                  alpha: index == weeks.length - 1 ? 1 : .55,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _weekDate(weeks[index].startedAt),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _weekDate(DateTime date) {
    final label = formatDate(date);
    return label.substring(0, label.lastIndexOf(' '));
  }
}
