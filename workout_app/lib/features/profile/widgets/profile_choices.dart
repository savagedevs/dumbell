import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Wrapping choices keep long labels usable at large accessibility text sizes.
class ProfileChoices extends StatelessWidget {
  const ProfileChoices({
    super.key,
    required this.label,
    required this.values,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
  });

  final String label;
  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      ...values.map((value) {
        final isSelected = selected == value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Semantics(
            selected: isSelected,
            child: Material(
              color: isSelected ? AppColors.elevated : AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected ? AppColors.lime : Colors.transparent,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: enabled ? () => onSelected(value) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          value,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        color: isSelected ? AppColors.lime : AppColors.muted,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    ],
  );
}
