import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/workout_controller.dart';
import '../../core/formatters.dart';
import '../../core/feedback_motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/exercise_performance.dart';

/// Keeps draft fields alive independently of session and timer rebuilds.
class WorkoutEditor extends StatefulWidget {
  const WorkoutEditor({
    required this.session,
    required this.controller,
    this.enabled = true,
    this.fieldsEnabled = true,
    super.key,
  });

  final WorkoutSession session;
  final WorkoutController controller;
  final bool enabled;
  final bool fieldsEnabled;

  @override
  State<WorkoutEditor> createState() => WorkoutEditorState();
}

class WorkoutEditorState extends State<WorkoutEditor>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final Map<String, _SetDraft> _drafts = {};
  bool _flushing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncDrafts();
  }

  @override
  void didUpdateWidget(covariant WorkoutEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncDrafts();
  }

  void _syncDrafts() {
    final liveIds = <String>{};
    final unit = widget.controller.unit;
    for (final exercise in widget.session.exercises) {
      for (final set in exercise.sets) {
        liveIds.add(set.id);
        final draft = _drafts[set.id];
        if (draft == null) {
          final created = _SetDraft(exercise.id, set, unit);
          created.repsFocus.addListener(() => _onFocusChanged(created));
          created.weightFocus.addListener(() => _onFocusChanged(created));
          _drafts[set.id] = created;
        } else {
          draft.sync(set, unit);
        }
      }
    }
    final removed = _drafts.keys.where((id) => !liveIds.contains(id)).toList();
    for (final id in removed) {
      _drafts.remove(id)?.dispose();
    }
  }

  void _onFocusChanged(_SetDraft draft) {
    if (!draft.disposed && !draft.deleting && draft.hasFocus) {
      _focusExercise(draft.exerciseId);
    }
    if (draft.disposed ||
        draft.deleting ||
        draft.hasFocus ||
        !draft.dirty ||
        _flushing) {
      return;
    }
    // A keyboard move between the two fields should not save halfway through.
    scheduleMicrotask(() {
      if (!mounted ||
          draft.disposed ||
          draft.deleting ||
          draft.hasFocus ||
          _flushing) {
        return;
      }
      unawaited(_saveDraft(draft));
    });
  }

  void _focusExercise(String exerciseId) {
    if (widget.controller.activeWorkout?.id == widget.session.id) {
      widget.controller.focusExercise(exerciseId);
    }
  }

  void _queueSave(_SetDraft draft) {
    draft.saveTimer?.cancel();
    draft.saveTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted ||
          draft.disposed ||
          draft.deleting ||
          _flushing ||
          !draft.dirty) {
        return;
      }
      if (_validReps(int.tryParse(draft.reps.text)) &&
          _validWeight(_parseWeight(draft.weight.text))) {
        unawaited(_saveDraft(draft));
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.detached) {
      return;
    }
    for (final draft in _drafts.values) {
      if (draft.dirty &&
          _validReps(int.tryParse(draft.reps.text)) &&
          _validWeight(_parseWeight(draft.weight.text))) {
        unawaited(_saveDraft(draft));
      }
    }
  }

  /// Called before navigation or another mutation so typed values are persisted.
  Future<bool> saveChanges() async {
    if (_flushing) return false;
    _flushing = true;
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      if (!(_formKey.currentState?.validate() ?? true)) return false;
      for (final draft in _drafts.values.toList()) {
        if (draft.pending != null && !await draft.pending!) return false;
        if (draft.dirty && !await _saveDraft(draft)) return false;
      }
      return true;
    } finally {
      _flushing = false;
    }
  }

  Future<bool> _saveDraft(_SetDraft draft, {bool? completed}) {
    if (draft.disposed || draft.deleting) return Future.value(false);
    if (draft.pending != null) return draft.pending!;
    draft.saveTimer?.cancel();
    final reps = int.tryParse(draft.reps.text);
    final weight = draft.weightDirty
        ? _parseWeight(draft.weight.text)
        : displayWeight(draft.weightKg, widget.controller.unit);
    if (!_validReps(reps) || !_validWeight(weight)) {
      if (mounted) setState(() => draft.showErrors = true);
      return Future.value(false);
    }
    if (!draft.dirty && completed == null) return Future.value(true);
    final revision = draft.revision;
    final submittedKg = draft.weightDirty
        ? weightToKg(weight!, widget.controller.unit)
        : draft.weightKg;
    final submittedCompleted = completed ?? draft.completed;
    final operation = widget.controller.updateSet(
      widget.session.id,
      draft.exerciseId,
      draft.setId,
      reps: reps!,
      weight: weight!,
      completed: submittedCompleted,
    );
    final result = operation
        .then((saved) {
          if (saved && !draft.disposed) {
            // A completion save can follow this future before the next frame
            // syncs the published model. Advance the committed base now.
            draft.weightKg = submittedKg;
            draft.completed = submittedCompleted;
            if (draft.revision == revision) {
              draft.dirty = false;
              draft.weightDirty = false;
              draft.showErrors = false;
            }
          }
          return saved;
        })
        .whenComplete(() {
          draft.pending = null;
          if (!draft.disposed && draft.dirty && draft.revision != revision) {
            _queueSave(draft);
          }
          if (mounted) setState(() {});
        });
    draft.pending = result;
    return result;
  }

  Future<void> _toggleSet(_SetDraft draft) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!await saveChanges() || !mounted) return;
    await _saveDraft(draft, completed: !draft.completed);
  }

  Future<void> _removeSet(WorkoutExercise exercise, _SetDraft draft) async {
    final remove = await confirmWorkoutAction(
      context,
      title: 'Delete this set?',
      message: 'This removes the set from ${exercise.name}.',
      action: 'Delete set',
      destructive: true,
    );
    if (remove && mounted) {
      draft.deleting = true;
      draft.saveTimer?.cancel();
      final saved = await widget.controller.deleteSet(
        widget.session.id,
        exercise.id,
        draft.setId,
      );
      if (!saved && !draft.disposed) draft.deleting = false;
    }
  }

  Future<void> _removeExercise(WorkoutExercise exercise) async {
    final remove = await confirmWorkoutAction(
      context,
      title: 'Remove exercise?',
      message:
          '${exercise.name} and its sets will be removed from this workout.',
      action: 'Remove exercise',
      destructive: true,
    );
    if (remove && mounted) {
      final drafts = _drafts.values
          .where((draft) => draft.exerciseId == exercise.id)
          .toList();
      for (final draft in drafts) {
        draft.deleting = true;
        draft.saveTimer?.cancel();
      }
      final saved = await widget.controller.removeExercise(
        widget.session.id,
        exercise.id,
      );
      if (!saved) {
        for (final draft in drafts) {
          if (!draft.disposed) draft.deleting = false;
        }
      }
    }
  }

  Future<void> _addSet(WorkoutExercise exercise) async {
    if (await saveChanges() && mounted) {
      await widget.controller.addSet(widget.session.id, exercise.id);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final draft in _drafts.values) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final performance =
        widget.session.finishedAt == null &&
            widget.controller.activeWorkout?.id == widget.session.id
        ? ExercisePerformance(widget.controller.history)
        : null;
    return Form(
      key: _formKey,
      child: Column(
        children: [
          for (var i = 0; i < widget.session.exercises.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            _exerciseCard(
              widget.session.exercises[i],
              i,
              previous: performance?.previousFor(
                widget.session,
                widget.session.exercises[i],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _exerciseCard(
    WorkoutExercise exercise,
    int index, {
    ExerciseSessionPerformance? previous,
  }) {
    final completed = exercise.sets.where((set) => set.isCompleted).length;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.lime.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  '${index + 1}'.padLeft(2, '0'),
                  style: const TextStyle(
                    color: AppColors.lime,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$completed of ${exercise.sets.length} sets complete',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                enabled: widget.enabled,
                tooltip: 'Exercise options',
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_horiz, color: AppColors.muted),
                onSelected: (_) => _removeExercise(exercise),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Remove exercise'),
                  ),
                ],
              ),
            ],
          ),
          if (widget.controller.activeWorkout?.id == widget.session.id) ...[
            const SizedBox(height: 8),
            Obx(() {
              final isCurrent =
                  widget.controller.currentExercise?.id == exercise.id;
              return Semantics(
                selected: isCurrent,
                child: TextButton.icon(
                  key: ValueKey('current-exercise-${exercise.id}'),
                  onPressed: widget.enabled
                      ? () => _focusExercise(exercise.id)
                      : null,
                  icon: Icon(
                    isCurrent ? Icons.radio_button_checked : Icons.play_arrow,
                    size: 17,
                  ),
                  label: Text(isCurrent ? 'Current exercise' : 'Make current'),
                  style: TextButton.styleFrom(
                    foregroundColor: isCurrent
                        ? AppColors.lime
                        : AppColors.muted,
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 12),
          if (exercise.sets.isNotEmpty) ...[
            SetProgress(
              key: ValueKey('set-progress-${exercise.id}'),
              value: completed / exercise.sets.length,
            ),
            const SizedBox(height: 12),
          ],
          for (var i = 0; i < exercise.sets.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _setRow(
              exercise,
              exercise.sets[i],
              i,
              previousSet: previous != null && i < previous.sets.length
                  ? previous.sets[i]
                  : null,
            ),
          ],
          if (exercise.sets.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Add a set to start logging this exercise.',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: widget.enabled ? () => _addSet(exercise) : null,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add set'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.lime,
                backgroundColor: AppColors.elevated,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _setRow(
    WorkoutExercise exercise,
    WorkoutSet set,
    int index, {
    WorkoutSet? previousSet,
  }) {
    final draft = _drafts[set.id]!;
    final check = SetCompletionFeedback(
      key: ValueKey('set-feedback-${set.id}'),
      completed: set.isCompleted,
      child: IconButton.filledTonal(
        key: ValueKey('complete-${set.id}'),
        onPressed: widget.enabled ? () => _toggleSet(draft) : null,
        tooltip: set.isCompleted ? 'Mark set incomplete' : 'Complete set',
        style: IconButton.styleFrom(
          backgroundColor: set.isCompleted
              ? AppColors.lime
              : AppColors.elevated,
          foregroundColor: set.isCompleted
              ? AppColors.background
              : AppColors.muted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(
          set.isCompleted ? Icons.check_rounded : Icons.check,
          size: 21,
        ),
      ),
    );
    final menu = PopupMenuButton<String>(
      enabled: widget.enabled,
      tooltip: 'Set ${index + 1} options',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 140),
      icon: const Icon(Icons.more_vert, color: AppColors.muted, size: 18),
      onSelected: (_) => _removeSet(exercise, draft),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'delete', child: Text('Delete set')),
      ],
    );
    final weight = _numberField(draft, weight: true, previousSet: previousSet);
    final reps = _numberField(draft, weight: false, previousSet: previousSet);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 310 ||
            MediaQuery.textScalerOf(context).scale(14) > 18;
        if (stacked) {
          return Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 8, 12),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'SET ${index + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.muted,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    check,
                    menu,
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: weight),
                    const SizedBox(width: 12),
                    Expanded(child: reps),
                  ],
                ),
              ],
            ),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              height: 52,
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: weight),
            const SizedBox(width: 8),
            Expanded(child: reps),
            const SizedBox(width: 8),
            Padding(padding: const EdgeInsets.only(top: 4), child: check),
            SizedBox(width: 32, child: menu),
          ],
        );
      },
    );
  }

  Widget _numberField(
    _SetDraft draft, {
    required bool weight,
    WorkoutSet? previousSet,
  }) {
    final field = weight ? draft.weight : draft.reps;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: field,
      builder: (context, value, child) {
        final matchesPrevious =
            previousSet != null &&
            (weight
                ? _parseWeight(value.text) ==
                      _parseWeight(
                        formatWeight(
                          previousSet.weightKg,
                          widget.controller.unit,
                        ),
                      )
                : int.tryParse(value.text) == previousSet.reps);
        return TextFormField(
          key: ValueKey('${weight ? 'weight' : 'reps'}-${draft.setId}'),
          controller: weight ? draft.weight : draft.reps,
          focusNode: weight ? draft.weightFocus : draft.repsFocus,
          enabled: widget.fieldsEnabled,
          keyboardType: TextInputType.numberWithOptions(decimal: weight),
          textInputAction: weight ? TextInputAction.next : TextInputAction.done,
          inputFormatters: [
            if (weight)
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
            else
              FilteringTextInputFormatter.digitsOnly,
          ],
          autovalidateMode: draft.showErrors
              ? AutovalidateMode.always
              : AutovalidateMode.onUserInteraction,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            helperText: previousSet == null
                ? null
                : matchesPrevious
                ? 'Same as last'
                : 'Your entry',
            helperStyle: const TextStyle(fontSize: 10, color: AppColors.muted),
            helperMaxLines: 3,
            labelText: weight
                ? 'Weight (${widget.controller.unit.label})'
                : 'Reps',
            labelStyle: const TextStyle(fontSize: 12, color: AppColors.muted),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            filled: true,
            fillColor: AppColors.background.withValues(alpha: .65),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 14,
            ),
            errorMaxLines: 3,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: draft.completed
                    ? AppColors.lime.withValues(alpha: .2)
                    : Colors.transparent,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.lime),
            ),
          ),
          validator: (value) {
            if (weight) {
              return _validWeight(_parseWeight(value ?? ''))
                  ? null
                  : 'Use 0–10,000';
            }
            return _validReps(int.tryParse(value ?? '')) ? null : 'Use 1–999';
          },
          onChanged: (_) {
            _focusExercise(draft.exerciseId);
            draft.dirty = true;
            if (weight) draft.weightDirty = true;
            draft.revision++;
            _queueSave(draft);
          },
          onFieldSubmitted: (_) {
            if (weight) {
              draft.repsFocus.requestFocus();
            } else {
              draft.repsFocus.unfocus();
              unawaited(_saveDraft(draft));
            }
          },
        );
      },
    );
  }
}

class _SetDraft {
  _SetDraft(this.exerciseId, WorkoutSet set, this.unit)
    : setId = set.id,
      weightKg = set.weightKg,
      completed = set.isCompleted,
      reps = TextEditingController(text: '${set.reps}'),
      weight = TextEditingController(text: formatWeight(set.weightKg, unit));

  final String exerciseId;
  final String setId;
  final TextEditingController reps;
  final TextEditingController weight;
  final FocusNode repsFocus = FocusNode();
  final FocusNode weightFocus = FocusNode();
  WeightUnit unit;
  bool completed;
  double weightKg;
  bool dirty = false;
  bool weightDirty = false;
  bool deleting = false;
  bool showErrors = false;
  bool disposed = false;
  int revision = 0;
  Future<bool>? pending;
  Timer? saveTimer;

  bool get hasFocus => repsFocus.hasFocus || weightFocus.hasFocus;

  void sync(WorkoutSet set, WeightUnit currentUnit) {
    completed = set.isCompleted;
    weightKg = set.weightKg;
    if (unit != currentUnit) {
      if (weightDirty) {
        final entered = _parseWeight(weight.text);
        if (entered != null && entered.isFinite) {
          weight.text = displayWeight(
            weightToKg(entered, unit),
            currentUnit,
          ).toString();
        }
      } else {
        weight.text = formatWeight(set.weightKg, currentUnit);
      }
    } else if (!dirty && !hasFocus) {
      reps.text = '${set.reps}';
      weight.text = formatWeight(set.weightKg, currentUnit);
    }
    unit = currentUnit;
  }

  void dispose() {
    disposed = true;
    saveTimer?.cancel();
    repsFocus.dispose();
    weightFocus.dispose();
    reps.dispose();
    weight.dispose();
  }
}

double? _parseWeight(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.'));

bool _validWeight(double? value) =>
    value != null && value.isFinite && value >= 0 && value <= 10000;

bool _validReps(int? value) => value != null && value >= 1 && value <= 999;

Future<bool> confirmWorkoutAction(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  bool destructive = false,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFBCAD),
                      foregroundColor: AppColors.background,
                    )
                  : null,
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;
}

Future<String?> showWorkoutNameDialog(
  BuildContext context,
  String currentName,
) {
  return showDialog<String>(
    context: context,
    builder: (_) => _WorkoutNameDialog(currentName: currentName),
  );
}

class _WorkoutNameDialog extends StatefulWidget {
  const _WorkoutNameDialog({required this.currentName});
  final String currentName;

  @override
  State<_WorkoutNameDialog> createState() => _WorkoutNameDialogState();
}

class _WorkoutNameDialogState extends State<_WorkoutNameDialog> {
  late final TextEditingController _name;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, _name.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name your workout'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _name,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Workout name'),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Enter a name' : null,
          onFieldSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save name')),
      ],
    );
  }
}

class WorkoutStat extends StatelessWidget {
  const WorkoutStat({
    required this.label,
    required this.value,
    required this.icon,
    super.key,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.lime, size: 19),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -.8,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}
