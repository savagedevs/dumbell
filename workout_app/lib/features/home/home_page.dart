import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../app/workout_controller.dart';
import '../../core/formatters.dart';
import '../../core/feedback_motion.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../history/widgets/workout_history_card.dart';

class HomePage extends GetView<WorkoutController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Obx(() {
        final now = controller.now.value.toLocal();
        final history = [...controller.data.value.history]
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
        final today = DateTime(now.year, now.month, now.day);
        final weekStart = DateTime(
          today.year,
          today.month,
          today.day - today.weekday + 1,
        );
        final weekEnd = DateTime(
          weekStart.year,
          weekStart.month,
          weekStart.day + 7,
        );
        final weekSessions = history.where((session) {
          final date = session.startedAt.toLocal();
          return !date.isBefore(weekStart) && date.isBefore(weekEnd);
        }).toList();
        final active = controller.activeWorkout;
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.lime,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.fitness_center_rounded,
                    color: AppColors.background,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'DUMBBELL',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'Settings',
                  onPressed: () => Get.toNamed(AppRoutes.settings),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    padding: const EdgeInsets.all(12),
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 21),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _HomeIntro(
              name: controller.profile?.name ?? '',
              controller: controller,
            ),
            const SizedBox(height: 28),
            _WeekActivity(
              weekStart: weekStart,
              today: today,
              sessions: weekSessions,
            ),
            const SizedBox(height: 22),
            EntryMotion(
              delayMilliseconds: 90,
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                child: _StartCard(
                  key: ValueKey(active?.id ?? 'ready'),
                  active: active,
                  now: now,
                  isSaving: controller.isSaving.value,
                  onPressed: () async {
                    if (active != null) {
                      Get.toNamed(AppRoutes.workout);
                    } else if (await controller.startWorkout()) {
                      Get.toNamed(AppRoutes.workout, arguments: true);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(
                  child: _WeekStat(
                    value: '${weekSessions.length}',
                    label: 'WORKOUTS THIS WEEK',
                    icon: Icons.bolt_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _WeekStat(
                    value:
                        '${weekSessions.fold<int>(0, (sum, session) => sum + session.completedSets)}',
                    label: 'SETS COMPLETED',
                    icon: Icons.check_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            SectionHeading(
              title: 'Recent activity',
              trailing: TextButton(
                onPressed: () => Get.toNamed(AppRoutes.history),
                child: const Text('View all'),
              ),
            ),
            const SizedBox(height: 14),
            if (history.isEmpty)
              const EmptyState(
                icon: Icons.fitness_center_rounded,
                title: 'Your first session is ahead',
                message: 'Finish a workout to see your activity here.',
              )
            else
              ...history
                  .take(3)
                  .map(
                    (session) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: WorkoutHistoryCard(
                        session: session,
                        unit: controller.unit,
                      ),
                    ),
                  ),
          ],
        );
      }),
    );
  }
}

class _HomeIntro extends StatefulWidget {
  const _HomeIntro({required this.name, required this.controller});

  final String name;
  final WorkoutController controller;

  @override
  State<_HomeIntro> createState() => _HomeIntroState();
}

class _HomeIntroState extends State<_HomeIntro> {
  late final bool _animate = widget.controller.claimWelcomeAnimation();
  String get name => widget.name;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      WelcomeFade(
        animate: _animate,
        child: Text(
          name.trim().isEmpty
              ? 'YOUR NEXT REP STARTS HERE'
              : 'Welcome back, ${name.trim()}.',
          style: TextStyle(
            fontSize: name.trim().isEmpty ? 10 : 14,
            fontWeight: FontWeight.w800,
            letterSpacing: name.trim().isEmpty ? 1.8 : 0,
            color: AppColors.muted,
          ),
        ),
      ),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final size = scale > 1.5
              ? 32.0
              : constraints.maxWidth < 330
              ? 40.0
              : 48.0;
          return Text.rich(
            const TextSpan(
              children: [
                TextSpan(text: 'SHOW UP.\n'),
                TextSpan(
                  text: 'GET STRONG.',
                  style: TextStyle(color: AppColors.lime),
                ),
              ],
            ),
            style: TextStyle(
              fontSize: size,
              height: 1.05,
              letterSpacing: -2,
              fontWeight: FontWeight.w900,
              color: AppColors.text,
            ),
          );
        },
      ),
      const SizedBox(height: 12),
      const Text(
        'One workout at a time. Make this one count.',
        style: TextStyle(color: AppColors.muted, height: 1.5),
      ),
    ],
  );
}

class _StartCard extends StatelessWidget {
  const _StartCard({
    super.key,
    required this.active,
    required this.now,
    required this.isSaving,
    required this.onPressed,
  });

  final WorkoutSession? active;
  final DateTime now;
  final bool isSaving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final elapsed = active == null ? null : now.difference(active!.startedAt);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.lime,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.fitness_center_rounded,
                color: AppColors.background,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.background.withValues(alpha: 0.25),
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      active == null ? 'YOUR PACE. YOUR PLAN.' : 'IN PROGRESS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.background,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            active == null ? 'Ready when you are.' : active!.name,
            style: const TextStyle(
              color: AppColors.background,
              fontSize: 23,
              letterSpacing: -0.6,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            active == null
                ? 'Build your session. Log every rep.'
                : '${formatDuration(elapsed!)} elapsed · ${active!.completedSets} sets logged',
            style: TextStyle(
              color: AppColors.background.withValues(alpha: 0.75),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isSaving ? null : onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.background,
                foregroundColor: AppColors.text,
                disabledBackgroundColor: AppColors.background.withValues(
                  alpha: 0.45,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      active == null ? 'Start workout' : 'Resume workout',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 21),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekActivity extends StatelessWidget {
  const _WeekActivity({
    required this.weekStart,
    required this.today,
    required this.sessions,
  });

  final DateTime weekStart;
  final DateTime today;
  final List<WorkoutSession> sessions;

  @override
  Widget build(BuildContext context) {
    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 8,
              children: [
                const Text(
                  'THIS WEEK',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${sessions.length} ${sessions.length == 1 ? 'session' : 'sessions'}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: List.generate(7, (index) {
              final day = DateTime(
                weekStart.year,
                weekStart.month,
                weekStart.day + index,
              );
              final isToday = day == today;
              final hasWorkout = sessions.any((session) {
                final date = session.startedAt.toLocal();
                return date.year == day.year &&
                    date.month == day.month &&
                    date.day == day.day;
              });
              return Expanded(
                child: Semantics(
                  label:
                      '${formatDate(day)}${isToday ? ', today' : ''}${hasWorkout ? ', workout completed' : ', no workout'}',
                  child: Column(
                    children: [
                      Text(
                        weekdays[index],
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Container(
                        width: 34,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isToday ? AppColors.lime : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isToday
                                ? AppColors.background
                                : AppColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: hasWorkout
                              ? AppColors.lime
                              : AppColors.elevated,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _WeekStat extends StatelessWidget {
  const _WeekStat({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
              ),
              Icon(icon, size: 21, color: AppColors.lime),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}
