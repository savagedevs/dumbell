import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes.dart';
import '../../../app/workout_controller.dart';
import '../../../core/formatters.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../../../data/models.dart';
import '../workout_calendar_controller.dart';
import 'workout_month_grid.dart';
import 'workout_weekly_chart.dart';

class WorkoutConsistencyCard extends StatefulWidget {
  const WorkoutConsistencyCard({super.key, required this.workouts});
  final WorkoutController workouts;

  @override
  State<WorkoutConsistencyCard> createState() => _WorkoutConsistencyCardState();
}

class _WorkoutConsistencyCardState extends State<WorkoutConsistencyCard> {
  late WorkoutCalendarController _calendar;

  @override
  void initState() {
    super.initState();
    _calendar = WorkoutCalendarController(widget.workouts);
  }

  @override
  void didUpdateWidget(covariant WorkoutConsistencyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workouts != widget.workouts) {
      _calendar.onClose();
      _calendar = WorkoutCalendarController(widget.workouts);
    }
  }

  @override
  void dispose() {
    _calendar.onClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Obx(() {
    final activity = _calendar.activity;
    final month = _calendar.month.value;
    final selected = _calendar.selectedDate.value;
    final today = _calendar.today.value;
    final sessions = activity.inMonth(month);
    final trainingDays = activity.trainingDaysInMonth(month);
    final selectedSessions = activity.onDay(selected);
    final weeks = activity.recentWeeks(today);
    final recentCount = weeks.fold(0, (count, week) => count + week.workouts);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Workout consistency',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Consistency means how often you train. Highlighted days have a saved workout with completed sets.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    MaterialLocalizations.of(context).formatMonthYear(month),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Previous month',
                  onPressed: () => _calendar.changeMonth(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                IconButton(
                  tooltip: 'Next month',
                  onPressed: () => _calendar.changeMonth(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${sessions.length} ${sessions.length == 1 ? 'workout' : 'workouts'} across $trainingDays ${trainingDays == 1 ? 'training day' : 'training days'}',
              style: const TextStyle(
                color: AppColors.lime,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _calendar.goToToday,
                icon: const Icon(Icons.today_rounded, size: 17),
                label: const Text('Today'),
              ),
            ),
            const SizedBox(height: 4),
            WorkoutMonthGrid(
              month: month,
              today: today,
              selectedDate: selected,
              activity: activity,
              onSelected: _calendar.selectDate,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _legend('Training day', filled: true),
                _legend('Today', filled: false),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Tap a day to see its workouts.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              '${selected == today ? 'Today · ' : ''}${formatDate(selected)}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 8),
            if (selectedSessions.isEmpty)
              const Text(
                'No completed workouts logged on this day.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  height: 1.5,
                ),
              )
            else
              for (final session in selectedSessions)
                _workout(context, session),
            const SizedBox(height: 16),
            ExpansionTile(
              key: const ValueKey('weekly-workout-summary'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              title: const Text(
                'Workouts by week',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '$recentCount ${recentCount == 1 ? 'workout' : 'workouts'} in the last 8 weeks',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              children: [
                const Text(
                  'Each bar shows workouts saved that week (Monday–Sunday). This week is still in progress.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                WorkoutWeeklyChart(weeks: weeks),
                const SizedBox(height: 12),
                const Text(
                  'Dates below the bars are Mondays. Swipe to see earlier weeks.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  });

  Widget _legend(String label, {required bool filled}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: filled ? AppColors.lime : Colors.transparent,
          border: Border.all(color: AppColors.lime),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 7),
      Flexible(
        child: Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
      ),
    ],
  );

  Widget _workout(BuildContext context, WorkoutSession session) {
    final local = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(session.startedAt.toLocal()),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        session.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '$local · ${formatDuration(session.finishedAt!.difference(session.startedAt))} · ${session.completedSets} completed ${session.completedSets == 1 ? 'set' : 'sets'}',
        style: const TextStyle(color: AppColors.muted, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.lime),
      onTap: () => Get.toNamed(AppRoutes.detail, arguments: session.id),
    );
  }
}
