import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import 'profile_controller.dart';
import 'widgets/profile_choices.dart';
import 'widgets/profile_hero.dart';

class ProfilePage extends GetView<ProfileController> {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) => Obx(() {
    final busy = controller.busy.value;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    return PopScope(
      canPop: controller.editing && !busy,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: controller.editing && !busy,
          toolbarHeight: largeText ? 80 : kToolbarHeight,
          title: !controller.editing && largeText
              ? null
              : Text(
                  controller.editing ? 'Your profile' : 'Welcome to Dumbbell',
                ),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Form(
                  key: controller.formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      EntryMotion(
                        child: ProfileHero(editing: controller.editing),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        key: const ValueKey('profile-name'),
                        controller: controller.name,
                        enabled: !busy,
                        autofillHints: const [AutofillHints.name],
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        maxLength: 50,
                        validator: controller.validateName,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          hintText: 'What should we call you?',
                          counterText: '',
                          errorMaxLines: 3,
                        ),
                      ),
                      const SizedBox(height: 28),
                      ProfileChoices(
                        label: 'Training goal',
                        values: ProfileController.goals,
                        selected: controller.goal.value,
                        enabled: !busy,
                        onSelected: (value) => controller.goal.value = value,
                      ),
                      const SizedBox(height: 20),
                      ProfileChoices(
                        label: 'Your experience',
                        values: ProfileController.experiences,
                        selected: controller.experience.value,
                        enabled: !busy,
                        onSelected: (value) =>
                            controller.experience.value = value,
                      ),
                      const SizedBox(height: 20),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Your units',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: WeightUnit.values.map((unit) {
                                return ChoiceChip(
                                  key: ValueKey('profile-unit-${unit.name}'),
                                  label: Text(
                                    unit == WeightUnit.kg
                                        ? 'Kilograms'
                                        : 'Pounds',
                                  ),
                                  selected: controller.unit.value == unit,
                                  onSelected: busy
                                      ? null
                                      : (_) => controller.unit.value = unit,
                                );
                              }).toList(),
                            ),
                            if (!controller.editing) ...[
                              const SizedBox(height: 22),
                              TextFormField(
                                key: const ValueKey('profile-weight'),
                                controller: controller.startingWeight,
                                enabled: !busy,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textInputAction: TextInputAction.done,
                                validator: controller.validateStartingWeight,
                                decoration: InputDecoration(
                                  labelText: 'Starting weight (optional)',
                                  suffixText: controller.unit.value.label,
                                  errorMaxLines: 5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Add a starting point for your weight history, or log it later in Progress.',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (controller.error.value.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            controller.error.value,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 26),
                      FilledButton(
                        key: const ValueKey('profile-save'),
                        onPressed: busy ? null : controller.save,
                        child: Text(
                          busy
                              ? 'Saving…'
                              : controller.editing
                              ? 'Save changes'
                              : 'Let’s get started',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        controller.editing
                            ? 'Weight history stays in Progress.'
                            : 'You can change these details in Settings anytime.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  });
}
