import 'user_profile.dart';
export 'user_profile.dart';

enum WeightUnit {
  kg,
  lb;

  String get label => name;
}

/// Unknown schemas are rejected rather than replacing records we cannot read.
class UnsupportedSchemaVersionException extends FormatException {
  UnsupportedSchemaVersionException(Object? version)
    : super('Unsupported workout data schema version: $version.');
}

class WorkoutSet {
  WorkoutSet({
    required this.id,
    required this.reps,
    required this.weightKg,
    this.isCompleted = false,
  }) {
    _requireText(id, 'id');
    if (reps < 0) throw ArgumentError.value(reps, 'reps', 'Cannot be negative');
    _requireWeight(weightKg, 'weightKg');
  }

  final String id;
  final int reps;
  final double weightKg;
  final bool isCompleted;

  WorkoutSet copyWith({
    String? id,
    int? reps,
    double? weightKg,
    bool? isCompleted,
  }) => WorkoutSet(
    id: id ?? this.id,
    reps: reps ?? this.reps,
    weightKg: weightKg ?? this.weightKg,
    isCompleted: isCompleted ?? this.isCompleted,
  );

  factory WorkoutSet.fromJson(Map<String, dynamic> json) => WorkoutSet(
    id: _text(json['id'], 'id'),
    reps: _nonNegativeInt(json['reps'], 'reps'),
    weightKg: _weight(json['weightKg'], 'weightKg'),
    isCompleted: _boolean(json['isCompleted'], 'isCompleted'),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'reps': reps,
    'weightKg': weightKg,
    'isCompleted': isCompleted,
  };
}

class WorkoutExercise {
  WorkoutExercise({
    required this.id,
    required this.exerciseId,
    required this.name,
    required List<WorkoutSet> sets,
  }) : sets = List.unmodifiable(sets) {
    _requireText(id, 'id');
    _requireText(exerciseId, 'exerciseId');
    _requireText(name, 'name');
  }

  final String id;
  final String exerciseId;
  final String name;
  final List<WorkoutSet> sets;

  WorkoutExercise copyWith({
    String? id,
    String? exerciseId,
    String? name,
    List<WorkoutSet>? sets,
  }) => WorkoutExercise(
    id: id ?? this.id,
    exerciseId: exerciseId ?? this.exerciseId,
    name: name ?? this.name,
    sets: sets ?? this.sets,
  );

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) =>
      WorkoutExercise(
        id: _text(json['id'], 'id'),
        exerciseId: _text(json['exerciseId'], 'exerciseId'),
        name: _text(json['name'], 'name'),
        sets: _objects(json['sets'], 'sets').map(WorkoutSet.fromJson).toList(),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'name': name,
    'sets': sets.map((set) => set.toJson()).toList(),
  };
}

class WorkoutSession {
  WorkoutSession({
    required this.id,
    required this.name,
    required this.startedAt,
    this.finishedAt,
    this.photoPath,
    required List<WorkoutExercise> exercises,
  }) : exercises = List.unmodifiable(exercises) {
    _requireText(id, 'id');
    _requireText(name, 'name');
    _photoPath(photoPath);
    if (finishedAt != null && finishedAt!.isBefore(startedAt)) {
      throw ArgumentError('finishedAt cannot be before startedAt');
    }
  }

  final String id;
  final String name;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final String? photoPath;
  final List<WorkoutExercise> exercises;

  Duration get duration => (finishedAt ?? DateTime.now()).difference(startedAt);

  int get completedSets => exercises.fold(
    0,
    (total, exercise) =>
        total + exercise.sets.where((set) => set.isCompleted).length,
  );

  double get volumeKg => exercises.fold(
    0,
    (total, exercise) =>
        total +
        exercise.sets
            .where((set) => set.isCompleted)
            .fold(0.0, (volume, set) => volume + set.weightKg * set.reps),
  );

  WorkoutSession copyWith({
    String? id,
    String? name,
    DateTime? startedAt,
    DateTime? finishedAt,
    List<WorkoutExercise>? exercises,
    bool clearFinishedAt = false,
    String? photoPath,
    bool clearPhoto = false,
  }) => WorkoutSession(
    id: id ?? this.id,
    name: name ?? this.name,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: clearFinishedAt ? null : finishedAt ?? this.finishedAt,
    photoPath: clearPhoto ? null : photoPath ?? this.photoPath,
    exercises: exercises ?? this.exercises,
  );

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    final startedAt = _date(json['startedAt'], 'startedAt');
    final finishedAt = json['finishedAt'] == null
        ? null
        : _date(json['finishedAt'], 'finishedAt');
    if (finishedAt != null && finishedAt.isBefore(startedAt)) {
      throw const FormatException('finishedAt cannot be before startedAt');
    }
    return WorkoutSession(
      id: _text(json['id'], 'id'),
      name: _text(json['name'], 'name'),
      startedAt: startedAt,
      finishedAt: finishedAt,
      photoPath: _photoPath(json['photoPath']),
      exercises: _objects(
        json['exercises'],
        'exercises',
      ).map(WorkoutExercise.fromJson).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'finishedAt': finishedAt?.toUtc().toIso8601String(),
    'photoPath': photoPath,
    'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
  };
}

class BodyWeightEntry {
  BodyWeightEntry({
    required this.id,
    required this.measuredAt,
    required this.weightKg,
  }) {
    _requireText(id, 'id');
    _requireWeight(weightKg, 'weightKg', positive: true);
  }

  final String id;
  final DateTime measuredAt;
  final double weightKg;

  factory BodyWeightEntry.fromJson(Map<String, dynamic> json) =>
      BodyWeightEntry(
        id: _text(json['id'], 'id'),
        measuredAt: _date(json['measuredAt'], 'measuredAt'),
        weightKg: _weight(json['weightKg'], 'weightKg', positive: true),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'measuredAt': measuredAt.toUtc().toIso8601String(),
    'weightKg': weightKg,
  };
}

class AppData {
  AppData({
    List<WorkoutSession> history = const [],
    this.activeWorkout,
    this.unit = WeightUnit.kg,
    List<BodyWeightEntry> bodyWeights = const [],
    this.profile,
    this.onboardingCompleted = false,
  }) : history = List.unmodifiable(history),
       bodyWeights = List.unmodifiable(bodyWeights);

  static const schemaVersion = 2;

  final List<WorkoutSession> history;
  final WorkoutSession? activeWorkout;
  final WeightUnit unit;
  final List<BodyWeightEntry> bodyWeights;
  final UserProfile? profile;
  final bool onboardingCompleted;

  AppData copyWith({
    List<WorkoutSession>? history,
    WorkoutSession? activeWorkout,
    WeightUnit? unit,
    List<BodyWeightEntry>? bodyWeights,
    bool clearActiveWorkout = false,
    UserProfile? profile,
    bool? onboardingCompleted,
  }) => AppData(
    history: history ?? this.history,
    activeWorkout: clearActiveWorkout
        ? null
        : activeWorkout ?? this.activeWorkout,
    unit: unit ?? this.unit,
    bodyWeights: bodyWeights ?? this.bodyWeights,
    profile: profile ?? this.profile,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
  );

  factory AppData.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] is! int ||
        (json['schemaVersion'] != 1 &&
            json['schemaVersion'] != schemaVersion)) {
      throw UnsupportedSchemaVersionException(json['schemaVersion']);
    }
    final unitName = json['unit'];
    final unit = switch (unitName) {
      'kg' => WeightUnit.kg,
      'lb' => WeightUnit.lb,
      _ => throw FormatException('Invalid weight unit: $unitName'),
    };
    return AppData(
      history: _objects(
        json['history'],
        'history',
      ).map(WorkoutSession.fromJson).toList(),
      activeWorkout: json['activeWorkout'] == null
          ? null
          : WorkoutSession.fromJson(
              _object(json['activeWorkout'], 'activeWorkout'),
            ),
      unit: unit,
      profile: json['profile'] == null
          ? null
          : UserProfile.fromJson(_object(json['profile'], 'profile')),
      onboardingCompleted: json['schemaVersion'] == 1
          ? false
          : _boolean(json['onboardingCompleted'], 'onboardingCompleted'),
      bodyWeights: _objects(
        json['bodyWeights'],
        'bodyWeights',
      ).map(BodyWeightEntry.fromJson).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'history': history.map((session) => session.toJson()).toList(),
    'activeWorkout': activeWorkout?.toJson(),
    'unit': unit.name,
    'bodyWeights': bodyWeights.map((entry) => entry.toJson()).toList(),
    'profile': profile?.toJson(),
    'onboardingCompleted': onboardingCompleted,
  };
}

void _requireText(String value, String field) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, field, 'Cannot be empty');
  }
}

String? _photoPath(Object? value) {
  if (value == null) return null;
  if (value is! String ||
      value.isEmpty ||
      value.length > 240 ||
      value.startsWith('/') ||
      value.contains('\\') ||
      value.contains(':') ||
      value.split('/').any((part) => part == '..' || part.isEmpty)) {
    throw const FormatException('Invalid local photo reference.');
  }
  return value;
}

void _requireWeight(double value, String field, {bool positive = false}) {
  if (!value.isFinite || value < 0 || (positive && value == 0)) {
    throw ArgumentError.value(value, field, 'Invalid weight');
  }
}

String _text(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be a non-empty string');
  }
  return value;
}

bool _boolean(Object? value, String field) {
  if (value is! bool) throw FormatException('$field must be a boolean');
  return value;
}

int _nonNegativeInt(Object? value, String field) {
  if (value is! num || !value.isFinite || value < 0 || value != value.round()) {
    throw FormatException('$field must be a non-negative integer');
  }
  return value.toInt();
}

double _weight(Object? value, String field, {bool positive = false}) {
  if (value is! num ||
      !value.isFinite ||
      value < 0 ||
      (positive && value == 0)) {
    throw FormatException(
      '$field must be a finite ${positive ? 'positive' : 'non-negative'} number',
    );
  }
  return value.toDouble();
}

Map<String, dynamic> _object(Object? value, String field) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException('$field must be an object');
  }
  return Map<String, dynamic>.from(value);
}

List<Map<String, dynamic>> _objects(Object? value, String field) {
  if (value is! List) throw FormatException('$field must be a list');
  return value.map((entry) => _object(entry, field)).toList();
}

final _isoDate = RegExp(
  r'^([+-]?\d{4,6})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(?:Z|([+-])(\d{2}):(\d{2}))?$',
);

DateTime _date(Object? value, String field) {
  if (value is! String) throw FormatException('$field must be an ISO date');
  final match = _isoDate.firstMatch(value);
  if (match == null) throw FormatException('$field must be an ISO date');
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final normalized = DateTime.utc(year, month, day);
  final parsed = DateTime.tryParse(value);
  if (normalized.year != year ||
      normalized.month != month ||
      normalized.day != day ||
      int.parse(match[4]!) > 23 ||
      int.parse(match[5]!) > 59 ||
      int.parse(match[6]!) > 59 ||
      (match[8] != null && int.parse(match[8]!) > 23) ||
      (match[9] != null && int.parse(match[9]!) > 59) ||
      parsed == null) {
    throw FormatException('$field contains an invalid date');
  }
  return parsed;
}
