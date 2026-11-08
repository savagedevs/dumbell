import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../app/workout_controller.dart';
import '../../core/formatters.dart';
import '../../core/feedback_motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../sharing/workout_share_preview.dart';
import 'media/workout_photo_service.dart';
import 'workout_editor.dart';
import 'widgets/workout_photo_card.dart';

class WorkoutDetailArguments {
  const WorkoutDetailArguments({
    required this.workoutId,
    this.celebrate = false,
  });
  final String workoutId;
  final bool celebrate;
}

class WorkoutDetailPage extends GetView<WorkoutController> {
  const WorkoutDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final arguments = Get.arguments;
    return _WorkoutDetailView(
      controller: controller,
      workoutId: arguments is WorkoutDetailArguments
          ? arguments.workoutId
          : arguments is String
          ? arguments
          : '',
      celebrate: arguments is WorkoutDetailArguments && arguments.celebrate,
    );
  }
}

class _WorkoutDetailView extends StatefulWidget {
  const _WorkoutDetailView({
    required this.controller,
    required this.workoutId,
    required this.celebrate,
  });
  final WorkoutController controller;
  final String workoutId;
  final bool celebrate;

  @override
  State<_WorkoutDetailView> createState() => _WorkoutDetailViewState();
}

class _WorkoutDetailViewState extends State<_WorkoutDetailView> {
  final _editor = GlobalKey<WorkoutEditorState>();
  bool _busy = false;
  bool _leaving = false;

  WorkoutController get controller => widget.controller;

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

  Future<void> _share() => _run(() async {
    if (!await _flush() || !mounted) return;
    final session = controller.sessionById(widget.workoutId);
    if (session == null || session.finishedAt == null) return;
    await showWorkoutSharePreview(
      context,
      session: session,
      unit: controller.unit,
    );
  });

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

  Future<void> _rename(WorkoutSession session) => _run(() async {
    if (!await _flush() || !mounted) return;
    final name = await showWorkoutNameDialog(context, session.name);
    if (name != null && name != session.name) {
      await controller.renameWorkout(session.id, name);
    }
  });

  Future<void> _delete(WorkoutSession session) => _run(() async {
    final remove = await confirmWorkoutAction(
      context,
      title: 'Delete this workout?',
      message:
          '${session.name} and all its sets will be permanently removed from your history and progress.',
      action: 'Delete workout',
      destructive: true,
    );
    if (!remove || !mounted) return;
    if (!await controller.deleteWorkout(session.id)) return;
    // The deleted session is an immutable snapshot: keep its attachment path
    // even when the controller publishes the history without that session.
    // File cleanup cannot undo a successful database deletion or hold up back.
    unawaited(_cleanupDeletedPhoto(session));
    if (mounted) {
      setState(() => _leaving = true);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Get.offAllNamed<void>(AppRoutes.history);
      }
    }
  });

  Future<void> _cleanupDeletedPhoto(WorkoutSession session) async {
    final photos = Get.isRegistered<WorkoutPhotoService>()
        ? Get.find<WorkoutPhotoService>()
        : WorkoutPhotoService();
    try {
      await photos.cleanupDeletedWorkout(
        workoutId: session.id,
        attachedPath: session.photoPath,
      );
    } catch (_) {
      debugPrint('Workout deleted; private photo cleanup could not finish.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      controller.data.value;
      final session = controller.sessionById(widget.workoutId);
      final enabled = !controller.isSaving.value && !_busy;
      if (session == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Workout')),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: EmptyState(
                  icon: Icons.history_rounded,
                  title: 'Workout not found.',
                  message: 'This workout may have been deleted. Your other sessions are in your history.',
                  action: FilledButton(
                    onPressed: () => Get.offAllNamed<void>(AppRoutes.history),
                    child: const Text('View history'),
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
              tooltip: 'Save edits and go back',
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            title: const Text(
              'WORKOUT DETAILS',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Share workout',
                onPressed: enabled ? _share : null,
                icon: const Icon(Icons.ios_share_rounded),
              ),
              PopupMenuButton<String>(
                enabled: enabled,
                tooltip: 'Workout options',
                onSelected: (action) {
                  if (action == 'rename') {
                    _rename(session);
                  } else {
                    _delete(session);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename workout')),
                  PopupMenuItem(value: 'delete', child: Text('Delete workout')),
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
                        CompletionSparkle(
                          enabled: widget.celebrate,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppColors.lime,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: AppColors.background,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'IN THE BOOKS.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.lime,
                              fontWeight: FontWeight.w800,
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
                    const SizedBox(height: 18),
                    Text(
                      session.name,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.2,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      formatDate(session.startedAt),
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 24),
                    _SessionStats(session: session, controller: controller),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: enabled ? _share : null,
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('Share workout'),
                    ),
                    const SizedBox(height: 20),
                    WorkoutPhotoCard(session: session),
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
                    const SizedBox(height: 8),
                    const Text(
                      'Tap a value to edit. Changes save as you log.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    if (session.exercises.isEmpty)
                      const AppCard(
                        child: EmptyState(
                          icon: Icons.fitness_center_rounded,
                          title: 'No exercises left.',
                          message: 'You can keep this session in your history or delete it from the workout menu.',
                        ),
                      ),
                    WorkoutEditor(
                      key: _editor,
                      session: session,
                      controller: controller,
                      enabled: enabled,
                      fieldsEnabled: !_busy,
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
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: enabled ? _leave : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: const Text('Done'),
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
}

class _SessionStats extends StatelessWidget {
  const _SessionStats({required this.session, required this.controller});
  final WorkoutSession session;
  final WorkoutController controller;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final largeText = MediaQuery.textScalerOf(context).scale(14) > 19;
          final columns = largeText || constraints.maxWidth < 290 ? 2 : 3;
          final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
          return Wrap(
            spacing: 16,
            runSpacing: 24,
            children: [
              SizedBox(
                width: width,
                child: WorkoutStat(
                  icon: Icons.timer_outlined,
                  label: 'Duration',
                  value: formatDuration(session.duration),
                ),
              ),
              SizedBox(
                width: width,
                child: WorkoutStat(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Sets complete',
                  value: '${session.completedSets}',
                ),
              ),
              SizedBox(
                width: width,
                child: WorkoutStat(
                  icon: Icons.fitness_center_rounded,
                  label: 'Volume (${controller.unit.label})',
                  value: formatWeight(session.volumeKg, controller.unit),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
