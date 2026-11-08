import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/workout_controller.dart';
import '../../app/routes.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../exercises/widgets/exercise_attribution.dart';
import '../data_transfer/data_transfer_card.dart';
import '../live_workout/live_workout_service.dart';
import '../live_workout/live_workout_card.dart';
import 'privacy_policy_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final workouts = Get.find<WorkoutController>();
    final live = Get.isRegistered<LiveWorkoutService>()
        ? Get.find<LiveWorkoutService>()
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings & data')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              const SectionHeading(title: 'YOUR PROFILE'),
              const SizedBox(height: 16),
              AppCard(
                child: Obx(
                  () => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workouts.profile?.name.isNotEmpty == true
                            ? workouts.profile!.name
                            : 'Make this space yours',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        workouts.profile == null
                            ? 'Your name and training preferences stay on this device.'
                            : '${workouts.profile!.goal} · ${workouts.profile!.experience}',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () =>
                            Get.toNamed(AppRoutes.profile, arguments: true),
                        icon: const Icon(Icons.person_outline),
                        label: const Text('Edit profile'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const SectionHeading(title: 'YOUR PREFERENCES'),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weight units',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Change your display units at any time. Your recorded weights stay the same.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 18),
                    Obx(
                      () => Wrap(
                        spacing: 12,
                        children: WeightUnit.values
                            .map(
                              (unit) => ChoiceChip(
                                label: Text(
                                  unit == WeightUnit.kg
                                      ? 'Kilograms · kg'
                                      : 'Pounds · lb',
                                ),
                                selected: workouts.unit == unit,
                                onSelected: workouts.isSaving.value
                                    ? null
                                    : (_) => workouts.setUnit(unit),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              if (live?.supported == true) ...[
                const SectionHeading(title: 'LIVE WORKOUT'),
                const SizedBox(height: 16),
                const AppCard(child: LiveWorkoutCard()),
                const SizedBox(height: 28),
              ],
              const DataTransferCard(),
              const SizedBox(height: 28),
              const SectionHeading(title: 'ON YOUR DEVICE'),
              const SizedBox(height: 16),
              const AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, color: AppColors.lime),
                    SizedBox(height: 12),
                    Text(
                      'Your training stays local',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Workouts, photos and profile details stay on this device. Download your workout CSV or a backup regularly. Photos are kept separately on this device and are not included in CSV backups. Uninstalling the app or losing the device can remove local records.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About Dumbbell',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'General fitness logging and exercise information. Dumbbell is not a medical device and does not diagnose, treat, cure, or prevent any medical condition.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyPage(),
                        ),
                      ),
                      icon: const Icon(Icons.privacy_tip_outlined),
                      label: const Text('Privacy policy'),
                    ),
                    TextButton.icon(
                      onPressed: () => showLicensePage(
                        context: context,
                        applicationName: 'Dumbbell',
                      ),
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Open-source licenses'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sources & licenses',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      children: [
                        const RepDbCredit(),
                        TextButton(
                          onPressed: () => showRepDbLicense(context),
                          child: const Text('Read license'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
