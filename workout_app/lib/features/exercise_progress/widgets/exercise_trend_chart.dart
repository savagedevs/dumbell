import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/theme.dart';
import '../../../data/exercise_performance.dart';

class ExerciseTrendChart extends StatelessWidget {
  const ExerciseTrendChart({
    super.key,
    required this.points,
    required this.selectedId,
    required this.valueOf,
    required this.formatValue,
    required this.metricLabel,
    required this.axisLabel,
    required this.onSelected,
  });
  final List<ExerciseSessionPerformance> points;
  final String? selectedId;
  final double Function(ExerciseSessionPerformance) valueOf;
  final String Function(double) formatValue;
  final String metricLabel;
  final String axisLabel;
  final ValueChanged<ExerciseSessionPerformance> onSelected;

  @override
  Widget build(BuildContext context) {
    final values = points.map(valueOf).toList(growable: false);
    final lowest = values.reduce(math.min);
    final highest = values.reduce(math.max);
    final padding = highest == lowest
        ? math.max(1.0, highest * .1)
        : (highest - lowest) * .15;
    final min = math.max(0.0, lowest - padding);
    final max = highest + padding;
    final labels = [
      formatValue(max),
      formatValue((min + max) / 2),
      formatValue(min),
    ];
    var axisWidth = 36.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: const TextStyle(fontSize: 11)),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      axisWidth = math.max(axisWidth, painter.width + 12);
      painter.dispose();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$metricLabel · $axisLabel',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 180,
          child: Row(
            children: [
              SizedBox(
                width: axisWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final label in labels)
                      Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Semantics(
                    label:
                        '$metricLabel chart with ${points.length} recorded workouts. Values are in $axisLabel.',
                    child: GestureDetector(
                      key: const ValueKey('exercise-trend-chart'),
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        final fraction =
                            ((details.localPosition.dx - 6) /
                                    math.max(1.0, constraints.maxWidth - 12))
                                .clamp(0.0, 1.0);
                        final first =
                            points.first.startedAt.millisecondsSinceEpoch;
                        final span =
                            points.last.startedAt.millisecondsSinceEpoch -
                            first;
                        var selected = points.first;
                        var distance = double.infinity;
                        for (final point in points) {
                          final x = span == 0
                              ? .5
                              : (point.startedAt.millisecondsSinceEpoch -
                                        first) /
                                    span;
                          final next = (x - fraction).abs();
                          if (next <= distance) {
                            selected = point;
                            distance = next;
                          }
                        }
                        onSelected(selected);
                      },
                      child: CustomPaint(
                        size: Size(constraints.maxWidth, 180),
                        painter: _TrendPainter(
                          points: points,
                          values: values,
                          min: min,
                          max: max,
                          selectedId: selectedId,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.only(left: axisWidth),
          child: SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 16,
              runSpacing: 6,
              children: [
                Text(
                  formatDate(points.first.startedAt),
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
                if (points.length > 1)
                  Text(
                    formatDate(points.last.startedAt),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          points.length == 1
              ? 'One workout recorded. Complete another to build your trend.'
              : 'Tap a point to inspect that workout.',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.values,
    required this.min,
    required this.max,
    required this.selectedId,
  });
  final List<ExerciseSessionPerformance> points;
  final List<double> values;
  final double min, max;
  final String? selectedId;
  @override
  void paint(Canvas canvas, Size size) {
    const inset = 6.0;
    final width = math.max(1.0, size.width - inset * 2);
    final height = size.height - inset * 2;
    final guide = Paint()
      ..color = AppColors.elevated
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = inset + height * i / 2;
      canvas.drawLine(Offset(inset, y), Offset(size.width - inset, y), guide);
    }
    final first = points.first.startedAt.millisecondsSinceEpoch;
    final span = points.last.startedAt.millisecondsSinceEpoch - first;
    final offsets = List.generate(
      points.length,
      (i) => Offset(
        inset +
            (span == 0
                ? width / 2
                : width *
                      (points[i].startedAt.millisecondsSinceEpoch - first) /
                      span),
        inset + height * (1 - (values[i] - min) / (max - min)),
      ),
    );
    if (offsets.length > 1) {
      final line = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (final offset in offsets.skip(1)) {
        line.lineTo(offset.dx, offset.dy);
      }
      final fill = Path.from(line)
        ..lineTo(offsets.last.dx, size.height - inset)
        ..lineTo(offsets.first.dx, size.height - inset)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.lime.withValues(alpha: .16),
              AppColors.lime.withValues(alpha: 0),
            ],
          ).createShader(Offset.zero & size),
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = AppColors.lime
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    for (var i = 0; i < offsets.length; i++) {
      final selected = points[i].workoutId == selectedId;
      if (selected) {
        canvas.drawLine(
          Offset(offsets[i].dx, inset),
          Offset(offsets[i].dx, size.height - inset),
          Paint()
            ..color = AppColors.lime.withValues(alpha: .2)
            ..strokeWidth = 1,
        );
        canvas.drawCircle(
          offsets[i],
          10,
          Paint()..color = AppColors.lime.withValues(alpha: .12),
        );
      }
      canvas.drawCircle(
        offsets[i],
        selected ? 5 : 3,
        Paint()..color = AppColors.lime,
      );
      if (selected) {
        canvas.drawCircle(offsets[i], 2, Paint()..color = AppColors.surface);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) => true;
}
