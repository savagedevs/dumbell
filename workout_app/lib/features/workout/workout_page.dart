import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../app/workout_controller.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import 'workout_editor.dart';
import 'workout_detail_page.dart';

class WorkoutPage extends GetView<WorkoutController> {
  const WorkoutPage({super.key});

  @override
  Widget build(BuildContext context) => _ActiveWorkoutView(
    controller: controller,
    chooseExercises: Get.arguments == true,
  );
}

class _ActiveWorkoutView extends StatefulWidget {
  const _ActiveWorkoutView({
    required this.controller,
    required this.chooseExercises,
  });
  final WorkoutController controller;
  final bool chooseExercises;

  @override
  State<_ActiveWorkoutView> createState() => _ActiveWorkoutViewState();
}

class _ActiveWorkoutViewState extends State<_ActiveWorkoutView> {
  final _editor = GlobalKey<WorkoutEditorState>();
  bool _busy = false;
  bool _leaving = false;

  WorkoutController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    if (widget.chooseExercises) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && controller.activeWorkout != null) {
          unawaited(_addExercise());
        }
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _flush() async =>
      await _editor.currentState?.saveChanges() ?? true;

  Future<void> _leave() => _run(() async {
    if (!await _flush() || !mounted) return;
    setState(() => _leaving = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Get.offAllNamed<void>(AppRoutes.home);
    }
  });

  Future<void> _addExercise() => _run(() async {
    if (!await _flush() || !mounted) return;
    await Get.toNamed<void>(AppRoutes.exercises, arguments: true);
  });

  Future<void> _rename(WorkoutSession session) => _run(() async {
    if (!await _flush() || !mounted) return;
    final name = await showWorkoutNameDialog(context, session.name);
    if (name != null && name != session.name) {
      await controller.renameWorkout(session.id, name);
    }
  });

  Future<void> _discard() => _run(() async {
    final discard = await confirmWorkoutAction(
      context,
      title: 'Discard this workout?',
      message: 'This session and all its sets will be deleted. Your saved workouts will stay in your history.',
      action: 'Discard workout',
      destructive: true,
    );
    if (!discard || !mounted) return;
    if (await controller.discardWorkout() && mounted) {
      setState(() => _leaving = true);
      Get.offAllNamed<void>(AppRoutes.home);
    }
  });

  Future<void> _finish() => _run(() async {
    if (!await _flush() || !mounted) return;
    final session = controller.activeWorkout;
    if (session == null || session.completedSets == 0) return;
    final finish = await confirmWorkoutAction(
      context,
      title: 'Finish strong.',
      message:
          '${session.completedSets} completed ${session.completedSets == 1 ? 'set' : 'sets'} will count toward your progress. You can edit this workout in your history.',
      action: 'Finish workout',
    );
    if (!finish || !mounted) return;
    if (await controller.finishWorkout() && mounted) {
      setState(() => _leaving = true);
      Get.offNamed<void>(
        AppRoutes.detail,
        arguments: WorkoutDetailArguments(
          workoutId: session.id,
          celebrate: true,
        ),
      );
    }
  });

  Future<void> _saveAndStart() => _run(() async {
    if (!await _flush() || !mounted) return;
    final save = await confirmWorkoutAction(
      context,
      title: 'Save & start new?',
      message: 'This workout, including all unfinished sets, will be saved in your history. A new empty workout will start, and you can choose its first exercise.',
      action: 'Save & start new',
    );
    if (!save || !mounted) return;
    if (await controller.saveAndStartWorkout() && mounted) {
      await Get.toNamed<void>(AppRoutes.exercises, arguments: true);
    }
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      controller.data.value;
      final session = controller.activeWorkout;
      final enabled = !controller.isSaving.value && !_busy;
      if (session == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Workout')),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: EmptyState(
                  icon: Icons.fitness_center_rounded,
                  title: 'Your next session starts here.',
                  message: 'Head to Home to start your next workout, then add exercises and log your sets here.',
                  action: FilledButton.icon(
                    onPressed: enabled
                        ? () => Get.offAllNamed<void>(AppRoutes.home)
                        : null,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Go to Home'),
                  ),
                ),
              ),
            ),
          ),
        );
      }
      return PopScope(
        canPop: _leaving,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _leave();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: enabled ? _leave : null,
              tooltip: 'Keep workout and go back',
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            title: const Text(
              'WORKOUT',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                enabled: enabled,
                tooltip: 'Workout options',
                onSelected: (action) {
                  if (action == 'save-start') {
                    _saveAndStart();
                  } else {
                    _discard();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'save-start',
                    child: Text('Save & start new'),
                  ),
                  PopupMenuItem(
                    value: 'discard',
                    child: Text('Discard workout'),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'ONE SET AT A TIME.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.lime,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                        if (controller.isSaving.value)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            session.name,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.1,
                              height: 1.1,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: enabled ? () => _rename(session) : null,
                          tooltip: 'Rename workout',
                          icon: const Icon(Icons.edit_outlined, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _TimerCard(session: session, controller: controller),
                    const SizedBox(height: 28),
                    SectionHeading(
                      title: 'Your exercises',
                      trailing: Text(
                        '${session.exercises.length}',
                        style: const TextStyle(
                          color: AppColors.lime,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (session.exercises.isEmpty)
                      const AppCard(
                        child: EmptyState(
                          icon: Icons.add_rounded,
                          title: 'Build your session.',
                          message: 'Add an exercise below. Log your weight and reps, then tap the check to complete each set.',
                        ),
                      ),
                    WorkoutEditor(
                      key: _editor,
                      session: session,
                      controller: controller,
                      enabled: enabled,
                      fieldsEnabled: !_busy,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: enabled ? _addExercise : null,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add exercise'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.lime,
                        side: BorderSide(
                          color: AppColors.lime.withValues(alpha: .35),
                        ),
                        padding: const EdgeInsets.all(18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your session saves as you log. Come back whenever you’re ready.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (session.completedSets == 0) ...[
                        const Text(
                          'Complete at least one set to finish.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: enabled && session.completedSets > 0
                              ? _finish
                              : null,
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Finish workout'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
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
    });
  }
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({required this.session, required this.controller});
  final WorkoutSession session;
  final WorkoutController controller;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.circle, size: 7, color: AppColors.lime),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  'SESSION IN PROGRESS',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
              Icon(Icons.timer_outlined, color: AppColors.lime, size: 22),
            ],
          ),
          const SizedBox(height: 10),
          Obx(() {
            final elapsed = controller.now.value.difference(session.startedAt);
            return Text(
              formatDuration(elapsed.isNegative ? Duration.zero : elapsed),
              style: const TextStyle(
                fontSize: 40,
                height: 1.1,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.5,
              ),
            );
          }),
          const SizedBox(height: 16),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              Text(
                '${session.completedSets} sets complete',
                style: const TextStyle(color: AppColors.text, fontSize: 12),
              ),
              Text(
                '${formatWeight(session.volumeKg, controller.unit)} ${controller.unit.label} volume',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
