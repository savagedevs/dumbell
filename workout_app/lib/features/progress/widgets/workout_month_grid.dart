import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/theme.dart';
import '../../../data/workout_activity.dart';

class WorkoutMonthGrid extends StatelessWidget {
  const WorkoutMonthGrid({
    super.key,
    required this.month,
    required this.today,
    required this.selectedDate,
    required this.activity,
    required this.onSelected,
  });

  final DateTime month, today, selectedDate;
  final WorkoutActivity activity;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final leading = month.weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final rows = (leading + days + 6) ~/ 7;
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return Column(
      children: [
        Row(
          children: [
            for (final weekday in weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    weekday[0],
                    semanticsLabel: weekday,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        for (var row = 0; row < rows; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                for (var column = 0; column < 7; column++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child:
                          row * 7 + column - leading + 1 < 1 ||
                              row * 7 + column - leading + 1 > days
                          ? const SizedBox(height: 52)
                          : _day(
                              context,
                              DateTime(
                                month.year,
                                month.month,
                                row * 7 + column - leading + 1,
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _day(BuildContext context, DateTime day) {
    final count = activity.onDay(day).length;
    final trained = count > 0;
    final selected = day == selectedDate;
    final isToday = day == today;
    final label =
        '${formatDate(day)}, $count ${count == 1 ? 'workout' : 'workouts'}${isToday ? ', Today' : ''}';
    final foreground = trained ? AppColors.background : AppColors.text;
    final stamp =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: () => onSelected(day),
      child: ExcludeSemantics(
        child: Tooltip(
          message: label,
          child: Material(
            color: trained ? AppColors.lime : AppColors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                width: 2,
                color: selected
                    ? AppColors.text
                    : isToday
                    ? AppColors.lime
                    : Colors.transparent,
              ),
            ),
            child: InkWell(
              key: ValueKey('calendar-day-$stamp'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSelected(day),
              child: SizedBox(
                height: 52,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${day.day}',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.1,
                          fontWeight: trained || isToday
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: foreground,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: trained ? foreground : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
