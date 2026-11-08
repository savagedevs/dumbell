import '../../core/formatters.dart';
import '../../data/models.dart';

enum WorkoutShareFormat {
  story('Story 9:16', 1080, 1920),
  square('Square 1:1', 1080, 1080);

  const WorkoutShareFormat(this.label, this.width, this.height);
  final String label;
  final int width;
  final int height;
  double get aspectRatio => width / height;
}

/// A read-only projection of a saved workout. No profile or media is resolved
/// here, and incomplete sets never contribute to its exported figures.
class WorkoutShareSummary {
  WorkoutShareSummary._({
    required this.title,
    required this.date,
    required this.duration,
    required this.completedSets,
    required this.volume,
    required this.volumeUnit,
    required List<WorkoutShareHighlight> highlights,
  }) : highlights = List.unmodifiable(highlights);

  factory WorkoutShareSummary.fromSession(
    WorkoutSession session,
    WeightUnit unit,
  ) {
    final finished = session.finishedAt;
    if (finished == null) {
      throw ArgumentError('Save the workout before creating a share image.');
    }
    final groups = <String, _CompletedMovement>{};
    var completedSets = 0;
    var volumeKg = 0.0;
    for (final exercise in session.exercises) {
      for (final set in exercise.sets.where((set) => set.isCompleted)) {
        completedSets++;
        volumeKg += set.weightKg * set.reps;
        final movement = groups.putIfAbsent(
          exercise.exerciseId,
          () => _CompletedMovement(exercise.name),
        );
        movement.sets++;
        movement.reps += set.reps;
        if (set.weightKg > movement.topWeightKg) {
          movement.topWeightKg = set.weightKg;
        }
      }
    }
    return WorkoutShareSummary._(
      title: session.name,
      date: formatDate(session.startedAt),
      duration: formatDuration(finished.difference(session.startedAt)),
      completedSets: completedSets,
      volume: formatWeight(volumeKg, unit),
      volumeUnit: unit.label,
      highlights: groups.values
          .map(
            (movement) => WorkoutShareHighlight(
              name: movement.name,
              details:
                  '${movement.sets} ${movement.sets == 1 ? 'set' : 'sets'} · ${movement.reps} reps',
              load: movement.topWeightKg == 0
                  ? 'No added weight'
                  : '${formatWeight(movement.topWeightKg, unit)} ${unit.label} top set',
            ),
          )
          .toList(),
    );
  }

  final String title;
  final String date;
  final String duration;
  final int completedSets;
  final String volume;
  final String volumeUnit;
  final List<WorkoutShareHighlight> highlights;

  String get accessibilityLabel =>
      '$title. $date. Duration $duration. $completedSets completed sets. '
      'Volume $volume $volumeUnit. '
      '${highlights.isEmpty ? 'No completed sets recorded.' : highlights.map((item) => '${item.name}, ${item.details}, ${item.load}').join('. ')}';
}

class WorkoutShareHighlight {
  const WorkoutShareHighlight({
    required this.name,
    required this.details,
    required this.load,
  });
  final String name;
  final String details;
  final String load;
}

class _CompletedMovement {
  _CompletedMovement(this.name);
  final String name;
  var sets = 0;
  var reps = 0;
  var topWeightKg = 0.0;
}
