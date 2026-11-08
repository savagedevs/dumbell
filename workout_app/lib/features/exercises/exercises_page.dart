import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../app/workout_controller.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/exercise_catalog.dart';
import '../exercise_progress/exercise_progress_controller.dart';
import 'widgets/exercise_details.dart';
import 'widgets/exercise_thumbnail.dart';

class ExercisesPage extends StatefulWidget {
  const ExercisesPage({super.key});

  @override
  State<ExercisesPage> createState() => _ExercisesPageState();
}

class _ExercisesPageState extends State<ExercisesPage> {
  final _searchController = TextEditingController();
  final _controller = Get.find<WorkoutController>();
  String _query = '';
  String? _muscle;
  late final bool _isSelecting;

  @override
  void initState() {
    super.initState();
    _isSelecting = Get.arguments == true;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addExercise(
    ExerciseDefinition exercise, {
    BuildContext? sheetContext,
  }) async {
    if (_controller.isSaving.value) return;
    if (_controller.activeWorkout == null) {
      Get.offAllNamed(AppRoutes.home);
      return;
    }
    if (!await _controller.addExercise(exercise.id)) return;
    if (!mounted) return;
    if (sheetContext != null) {
      if (!sheetContext.mounted) return;
      Navigator.of(sheetContext).pop();
    }
    if (_isSelecting) {
      Navigator.of(context).pop();
    } else {
      Get.toNamed(AppRoutes.workout);
    }
  }

  void _showDetails(ExerciseDefinition exercise) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => ExerciseDetails(
        exercise: exercise,
        controller: _controller,
        onAdd: () => _addExercise(exercise, sheetContext: sheetContext),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final muscles =
        exerciseCatalog.map((exercise) => exercise.muscleGroup).toSet().toList()
          ..sort();
    final query = _query.trim().toLowerCase();
    final exercises = exerciseCatalog.where((exercise) {
      final matchesSearch =
          query.isEmpty ||
          '${exercise.name} ${exercise.muscleGroup} ${exercise.equipment}'
              .toLowerCase()
              .contains(query);
      return matchesSearch &&
          (_muscle == null || exercise.muscleGroup == _muscle);
    }).toList();

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(24, _isSelecting ? 12 : 28, 24, 0),
            sliver: SliverList.list(
              children: [
                if (_isSelecting) ...[
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Back to workout',
                        onPressed: () => Get.back(),
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const Expanded(
                        child: Text(
                          'ADD TO YOUR WORKOUT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.lime,
                            letterSpacing: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ] else ...[
                  const Text(
                    'MOVE WITH INTENTION',
                    style: TextStyle(
                      color: AppColors.lime,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.7,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  _isSelecting ? 'Find your next move.' : 'Movement library.',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.4,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 11),
                Text(
                  '${exerciseCatalog.length} movements. Illustrations and form cues, all available offline.',
                  style: TextStyle(color: AppColors.muted, height: 1.5),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search exercises or equipment',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded, size: 19),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _MuscleChip(
                    label: 'All muscles',
                    selected: _muscle == null,
                    onSelected: () => setState(() => _muscle = null),
                  ),
                  ...muscles.map(
                    (muscle) => _MuscleChip(
                      label: muscle,
                      selected: _muscle == muscle,
                      onSelected: () => setState(() => _muscle = muscle),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 25, 24, 14),
            sliver: SliverToBoxAdapter(
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 8,
                children: [
                  const Text(
                    'EXERCISES',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  Text(
                    '${exercises.length} movements',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (exercises.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              sliver: SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No matching movements',
                  message: 'Try another name, equipment type or muscle group.',
                  action: TextButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _query = '';
                        _muscle = null;
                      });
                    },
                    child: const Text('Clear filters'),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              sliver: SliverList.separated(
                itemCount: exercises.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final exercise = exercises[index];
                  return InkWell(
                    onTap: () => _showDetails(exercise),
                    borderRadius: BorderRadius.circular(22),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 17,
                        vertical: 18,
                      ),
                      child: Row(
                        children: [
                          ExerciseThumbnail(
                            key: ValueKey(exercise.id),
                            exercise: exercise,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  exercise.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${exercise.muscleGroup} · ${exercise.equipment}',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 11,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (_isSelecting)
                            Obx(
                              () => IconButton(
                                tooltip: 'Add ${exercise.name}',
                                onPressed: _controller.isSaving.value
                                    ? null
                                    : () => _addExercise(exercise),
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.elevated,
                                  foregroundColor: AppColors.lime,
                                ),
                                icon: const Icon(Icons.add_rounded, size: 22),
                              ),
                            )
                          else
                            IconButton(
                              tooltip: 'View graph for ${exercise.name}',
                              onPressed: () => Get.toNamed(
                                AppRoutes.exerciseProgress,
                                arguments: ExerciseProgressArguments(
                                  exerciseId: exercise.id,
                                  name: exercise.name,
                                ),
                              ),
                              icon: const Icon(Icons.show_chart_rounded),
                              color: AppColors.lime,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _MuscleChip extends StatelessWidget {
  const _MuscleChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onSelected(),
        labelStyle: TextStyle(
          color: selected ? AppColors.background : AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        selectedColor: AppColors.lime,
        backgroundColor: AppColors.surface,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
      ),
    );
  }
}
