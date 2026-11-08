import 'package:flutter/material.dart';

import '../../../core/theme.dart';

class ProfileHero extends StatelessWidget {
  const ProfileHero({super.key, required this.editing});

  final bool editing;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.lime,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(
          Icons.fitness_center_rounded,
          color: AppColors.background,
          size: 30,
        ),
      ),
      const SizedBox(height: 24),
      const Text(
        'YOUR PACE. YOUR PLAN.',
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 10,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final fontSize = scale > 1.4 && constraints.maxWidth < 360
              ? 32.0
              : 44.0;
          return Text.rich(
            TextSpan(
              children: [
                TextSpan(text: editing ? 'KEEP IT\n' : 'MAKE IT\n'),
                const TextSpan(
                  text: 'YOUR OWN.',
                  style: TextStyle(color: AppColors.lime),
                ),
              ],
            ),
            style: TextStyle(
              fontSize: fontSize,
              height: 1.04,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.8,
            ),
          );
        },
      ),
      const SizedBox(height: 16),
      Text(
        editing ? 'A little about you, for the way you train.' : 'Start with your name to make Dumbbell feel like yours. You can add the other details now or later.',
        style: const TextStyle(color: AppColors.muted, height: 1.5),
      ),
      const SizedBox(height: 14),
      const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, color: AppColors.lime, size: 17),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Saved on this device. No account needed.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
        ],
      ),
    ],
  );
}
