import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../data/exercise_catalog.dart';
import 'exercise_image.dart';

class ExerciseMediaPanel extends StatefulWidget {
  const ExerciseMediaPanel({super.key, required this.exercise});

  final ExerciseDefinition exercise;

  @override
  State<ExerciseMediaPanel> createState() => _ExerciseMediaPanelState();
}

class _ExerciseMediaPanelState extends State<ExerciseMediaPanel> {
  int _selectedPose = 0;

  @override
  void didUpdateWidget(ExerciseMediaPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise.id != widget.exercise.id) _selectedPose = 0;
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    if (!exercise.hasImage) return const SizedBox.shrink();
    final illustrations = exercise.illustrations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'ILLUSTRATION',
          style: TextStyle(
            color: AppColors.lime,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: 1,
            child: ExerciseImage(
              exerciseName: exercise.name,
              illustration: illustrations[_selectedPose],
            ),
          ),
        ),
        if (illustrations.length > 1) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(illustrations.length, (index) {
              final selected = index == _selectedPose;
              return ChoiceChip(
                label: Text(illustrations[index].label),
                selected: selected,
                showCheckmark: false,
                onSelected: (_) => setState(() => _selectedPose = index),
                selectedColor: AppColors.lime,
                backgroundColor: AppColors.elevated,
                side: BorderSide.none,
                labelStyle: TextStyle(
                  color: selected ? AppColors.background : AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              );
            }),
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            illustrations.length > 1
                ? 'Illustrations included offline'
                : 'Illustration included offline',
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }
}
