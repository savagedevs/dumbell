import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme.dart';
import 'live_workout_service.dart';

class LiveWorkoutCard extends GetView<LiveWorkoutService> {
  const LiveWorkoutCard({super.key});

  @override
  Widget build(BuildContext context) => Obx(
    () => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your workout at a glance',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'See your timer and current exercise on your home screen. Tap the widget or workout notification to resume.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: controller.busy.value
                  ? null
                  : controller.addHomeWidget,
              icon: const Icon(Icons.widgets_outlined),
              label: const Text('Add home-screen widget'),
            ),
            if (!controller.notificationsAllowed.value)
              OutlinedButton.icon(
                onPressed: controller.busy.value
                    ? null
                    : controller.enableNotifications,
                icon: const Icon(Icons.notifications_outlined),
                label: const Text('Enable workout notifications'),
              )
            else
              const Text(
                'Workout notifications enabled',
                style: TextStyle(color: AppColors.lime),
              ),
          ],
        ),
        if (controller.message.value.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            controller.message.value,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ],
    ),
  );
}
