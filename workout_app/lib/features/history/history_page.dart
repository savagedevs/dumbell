import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../app/workout_controller.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'widgets/workout_history_card.dart';

class HistoryPage extends GetView<WorkoutController> {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Obx(() {
        final sessions = [...controller.data.value.history]
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
        final totalSets = sessions.fold<int>(
          0,
          (sum, session) => sum + session.completedSets,
        );
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          children: [
            const Text(
              'THE WORK ADDS UP',
              style: TextStyle(
                color: AppColors.lime,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.7,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Text(
                    'Your history.',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Get.toNamed(AppRoutes.downloads),
                  tooltip: 'Downloads & backups',
                  icon: const Icon(
                    Icons.download_rounded,
                    color: AppColors.lime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            const Text(
              'Every session, every set. All your work in one place.',
              style: TextStyle(color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 26),
            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: _Summary(
                      value: '${sessions.length}',
                      label: 'WORKOUTS',
                    ),
                  ),
                  Container(width: 1, height: 42, color: AppColors.elevated),
                  Expanded(
                    child: _Summary(
                      value: '$totalSets',
                      label: 'SETS COMPLETED',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            if (sessions.isEmpty)
              EmptyState(
                icon: Icons.history_rounded,
                title: 'Your story starts with a set',
                message: 'Completed workouts will appear here, ready to review and edit.',
                action: FilledButton.icon(
                  onPressed: controller.isSaving.value
                      ? null
                      : () => Get.offAllNamed(AppRoutes.home),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Go to Home'),
                ),
              )
            else
              ...List.generate(sessions.length, (index) {
                final session = sessions[index];
                final date = session.startedAt.toLocal();
                final previous = index == 0
                    ? null
                    : sessions[index - 1].startedAt.toLocal();
                final showMonth =
                    previous == null ||
                    previous.month != date.month ||
                    previous.year != date.year;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showMonth) ...[
                      if (index > 0) const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                          '${_months[date.month - 1]} ${date.year}'
                              .toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                    WorkoutHistoryCard(session: session, unit: controller.unit),
                    const SizedBox(height: 12),
                  ],
                );
              }),
          ],
        );
      }),
    );
  }
}

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class _Summary extends StatelessWidget {
  const _Summary({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: AppColors.muted,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
