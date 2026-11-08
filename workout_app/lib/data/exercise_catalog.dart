part 'exercise_catalog.g.dart';

/// A labelled still from the same upstream record as its exercise.
class ExerciseIllustration {
  const ExerciseIllustration({required this.label, required this.asset});

  final String label;
  final String asset;
}

class ExerciseDefinition {
  const ExerciseDefinition({
    required this.id,
    required this.sourceId,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    required this.description,
    required this.instructions,
    required this.illustrations,
    this.tips = const [],
  });

  final String id;
  final String sourceId;
  final String name;
  final String muscleGroup;
  final String equipment;
  final String description;
  final List<String> instructions;
  final List<String> tips;
  final List<ExerciseIllustration> illustrations;

  bool get hasImage => illustrations.isNotEmpty;
}
