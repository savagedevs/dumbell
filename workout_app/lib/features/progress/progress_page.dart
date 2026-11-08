import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/workout_controller.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../exercise_progress/widgets/exercise_progress_section.dart';
import 'widgets/workout_consistency_card.dart';

class ProgressPage extends GetView<WorkoutController> {
  const ProgressPage({super.key});

  void _addWeight(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => _AddBodyWeightDialog(controller: controller),
    );
  }

  Future<void> _deleteWeight(
    BuildContext context,
    BodyWeightEntry entry,
  ) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete weight entry?'),
        content: Text(
          '${formatWeight(entry.weightKg, controller.unit)} ${controller.unit.label} recorded on ${formatDate(entry.measuredAt)} will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (remove == true) await controller.deleteBodyWeight(entry.id);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Obx(() {
        final data = controller.data.value;
        final unit = data.unit;
        final sessions = data.history;
        final weights = [...data.bodyWeights]
          ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
        final totalVolume = sessions.fold<double>(
          0,
          (sum, session) => sum + session.volumeKg,
        );
        final totalSets = sessions.fold<int>(
          0,
          (sum, session) => sum + session.completedSets,
        );
        final recentWeights = weights.length > 30
            ? weights.sublist(weights.length - 30)
            : weights;

        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          children: [
            const Text(
              'BUILT BY CONSISTENCY',
              style: TextStyle(
                color: AppColors.lime,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.7,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Proof of your work.',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.4,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 11),
            const Text(
              'See what you have put in. Keep moving forward.',
              style: TextStyle(color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 26),
            const ExerciseProgressSection(),
            const SizedBox(height: 28),
            WorkoutConsistencyCard(workouts: controller),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ProgressStat(
                    value: '$totalSets',
                    label: 'SETS COMPLETED',
                    unit: 'all time',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ProgressStat(
                    value: formatWeight(totalVolume, unit),
                    label: 'VOLUME LIFTED',
                    unit: '${unit.label} · all time',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            if (MediaQuery.textScalerOf(context).scale(14) > 20)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeading(title: 'Body weight'),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: controller.isSaving.value
                          ? null
                          : () => _addWeight(context),
                      icon: const Icon(Icons.add_rounded, size: 17),
                      label: const Text('Log weight'),
                    ),
                  ),
                ],
              )
            else
              SectionHeading(
                title: 'Body weight',
                trailing: TextButton.icon(
                  onPressed: controller.isSaving.value
                      ? null
                      : () => _addWeight(context),
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('Log weight'),
                ),
              ),
            const SizedBox(height: 13),
            if (weights.isEmpty)
              EmptyState(
                icon: Icons.monitor_weight_outlined,
                title: 'A little more perspective',
                message: 'Log your body weight whenever you want to track its changes over time.',
                action: OutlinedButton.icon(
                  onPressed: controller.isSaving.value
                      ? null
                      : () => _addWeight(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Log first entry'),
                ),
              )
            else ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LATEST ENTRY',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: 7,
                      children: [
                        Text(
                          formatWeight(weights.last.weightKg, unit),
                          style: const TextStyle(
                            fontSize: 40,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.5,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text(
                            unit.label,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      formatDate(weights.last.measuredAt),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    if (weights.length > 1) ...[
                      const SizedBox(height: 8),
                      Text(
                        _weightChange(weights, unit),
                        style: const TextStyle(
                          color: AppColors.lime,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 25),
                    _BodyWeightChart(entries: recentWeights, unit: unit),
                    const SizedBox(height: 15),
                    Text(
                      weights.length == 1
                          ? 'Add another entry to see your trend.'
                          : recentWeights.length < weights.length
                          ? 'Your latest 30 entries · ${unit.label}'
                          : 'Your recorded entries · ${unit.label}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SectionHeading(
                title: 'Weight history',
                trailing: Text(
                  '${weights.length} ${weights.length == 1 ? 'entry' : 'entries'}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ),
              const SizedBox(height: 14),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 4,
                ),
                child: Column(
                  children: List.generate(weights.length, (index) {
                    final entry = weights[weights.length - index - 1];
                    return Column(
                      children: [
                        if (index > 0) const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${formatWeight(entry.weightKg, unit)} ${unit.label}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _entryDate(entry.measuredAt),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip:
                                    'Delete weight recorded ${_entryDate(entry.measuredAt)}',
                                onPressed: controller.isSaving.value
                                    ? null
                                    : () => _deleteWeight(context, entry),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppColors.muted,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ],
        );
      }),
    );
  }
}

String _entryDate(DateTime measuredAt) {
  final date = measuredAt.toLocal();
  return '${formatDate(date)} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String _weightChange(List<BodyWeightEntry> entries, WeightUnit unit) {
  final change = entries.last.weightKg - entries.first.weightKg;
  if (change.abs() < 0.001) return 'No change since first entry';
  return '${change > 0 ? '+' : ''}${formatWeight(change, unit)} ${unit.label} since first entry';
}

class _ProgressStat extends StatelessWidget {
  const _ProgressStat({
    required this.value,
    required this.label,
    required this.unit,
  });

  final String value;
  final String label;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            unit,
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyWeightChart extends StatelessWidget {
  const _BodyWeightChart({required this.entries, required this.unit});

  final List<BodyWeightEntry> entries;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final lowest = entries.map((entry) => entry.weightKg).reduce(math.min);
    final highest = entries.map((entry) => entry.weightKg).reduce(math.max);
    final padding = highest == lowest
        ? math.max(0.5, highest * 0.01)
        : (highest - lowest) * 0.2;
    final min = math.max(0.0, lowest - padding);
    final max = highest + padding;
    final axisWidth = math.max(
      44.0,
      math.max(
            _textWidth(
              context,
              formatWeight(max, unit),
              const TextStyle(fontSize: 10),
            ),
            _textWidth(
              context,
              formatWeight(min, unit),
              const TextStyle(fontSize: 10),
            ),
          ) +
          12,
    );
    return Semantics(
      label:
          'Body weight chart, ${entries.length} ${entries.length == 1 ? 'entry' : 'entries'}, from ${formatWeight(entries.first.weightKg, unit)} to ${formatWeight(entries.last.weightKg, unit)} ${unit.label}',
      child: Column(
        children: [
          SizedBox(
            height: 118,
            child: Row(
              children: [
                SizedBox(
                  width: axisWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatWeight(max, unit),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        formatWeight(min, unit),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CustomPaint(
                    size: const Size(double.infinity, 118),
                    painter: _WeightLinePainter(
                      entries: entries,
                      min: min,
                      max: max,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.only(left: axisWidth),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  _chartDate(entries.first.measuredAt),
                  style: const TextStyle(color: AppColors.muted, fontSize: 10),
                ),
                if (entries.length > 1)
                  Text(
                    _chartDate(entries.last.measuredAt),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _chartDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day}/${local.month}/${local.year.toString().substring(2)}';
}

class _WeightLinePainter extends CustomPainter {
  _WeightLinePainter({
    required this.entries,
    required this.min,
    required this.max,
  });

  final List<BodyWeightEntry> entries;
  final double min;
  final double max;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 5.0;
    final width = size.width - inset * 2;
    final height = size.height - inset * 2;
    final guide = Paint()
      ..color = AppColors.elevated
      ..strokeWidth = 1;
    for (var index = 0; index < 3; index++) {
      final y = inset + height * index / 2;
      canvas.drawLine(Offset(inset, y), Offset(size.width - inset, y), guide);
    }
    final firstTime = entries.first.measuredAt.millisecondsSinceEpoch;
    final span = entries.last.measuredAt.millisecondsSinceEpoch - firstTime;
    final points = entries.map((entry) {
      final x = entries.length == 1
          ? width / 2
          : span == 0
          ? width / 2
          : width *
                (entry.measuredAt.millisecondsSinceEpoch - firstTime) /
                span;
      return Offset(
        inset + x,
        inset + height * (1 - (entry.weightKg - min) / (max - min)),
      );
    }).toList();
    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.lime
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
    for (final point in points) {
      canvas.drawCircle(point, 3, Paint()..color = AppColors.lime);
    }
    canvas.drawCircle(points.last, 5, Paint()..color = AppColors.lime);
    canvas.drawCircle(points.last, 2, Paint()..color = AppColors.surface);
  }

  @override
  bool shouldRepaint(covariant _WeightLinePainter oldDelegate) =>
      oldDelegate.entries != entries ||
      oldDelegate.min != min ||
      oldDelegate.max != max;
}

class _AddBodyWeightDialog extends StatefulWidget {
  const _AddBodyWeightDialog({required this.controller});

  final WorkoutController controller;

  @override
  State<_AddBodyWeightDialog> createState() => _AddBodyWeightDialogState();
}

class _AddBodyWeightDialogState extends State<_AddBodyWeightDialog> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (widget.controller.isSaving.value ||
        !_formKey.currentState!.validate()) {
      return;
    }
    final weight = double.parse(
      _weightController.text.trim().replaceAll(',', '.'),
    );
    if (await widget.controller.addBodyWeight(weight) && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.controller.unit;
    return AlertDialog(
      title: const Text('Log body weight'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Record a measurement for today.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _weightController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: 'Body weight',
                suffixText: unit.label,
                hintText: unit == WeightUnit.kg ? 'e.g. 75.5' : 'e.g. 166.5',
              ),
              validator: (value) {
                final parsed = double.tryParse(
                  (value ?? '').trim().replaceAll(',', '.'),
                );
                if (parsed == null || !parsed.isFinite || parsed <= 0) {
                  return 'Enter a weight greater than zero.';
                }
                if (weightToKg(parsed, unit) > 1000) {
                  return 'Enter a weight up to ${formatWeight(1000, unit)} ${unit.label}.';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        Obx(
          () => TextButton(
            onPressed: widget.controller.isSaving.value
                ? null
                : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ),
        Obx(
          () => FilledButton(
            onPressed: widget.controller.isSaving.value ? null : _save,
            child: Text(
              widget.controller.isSaving.value ? 'Saving…' : 'Save weight',
            ),
          ),
        ),
      ],
    );
  }
}

// Measure scaled chart labels so accessibility text never competes with the plot.
double _textWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    textScaler: MediaQuery.textScalerOf(context),
    textDirection: Directionality.of(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}
