import 'dart:async';

import 'package:get/get.dart';

import '../core/formatters.dart';
import '../data/exercise_catalog.dart';
import '../data/exercise_performance.dart';
import '../data/models.dart';
import '../data/workout_repository.dart';

/// Coordinates domain mutations. Writes are serialized and published only after
/// the repository confirms persistence, so failures cannot lose the old state.
class WorkoutController extends GetxController {
  WorkoutController(
    this._repository,
    AppData initialData, {
    DateTime Function()? clock,
  }) : data = initialData.obs,
       _clock = clock ?? DateTime.now,
       now = (clock ?? DateTime.now)().obs;

  final WorkoutRepository _repository;
  final DateTime Function() _clock;
  final Rx<AppData> data;
  final RxnString currentExerciseId = RxnString();
  final isSaving = false.obs;
  final error = ''.obs;
  final Rx<DateTime> now;
  Timer? _timer;
  Future<void> _pending = Future<void>.value();
  int _pendingCount = 0;
  int _idCounter = 0;
  bool _welcomeShown = false;

  /// Kept in memory so returning to Home does not replay the greeting.
  bool claimWelcomeAnimation() {
    if (_welcomeShown) return false;
    _welcomeShown = true;
    return true;
  }

  WorkoutSession? get activeWorkout => data.value.activeWorkout;
  WorkoutExercise? get currentExercise {
    final focusedId = currentExerciseId.value;
    final exercises = activeWorkout?.exercises;
    if (exercises == null || exercises.isEmpty) return null;
    for (final exercise in exercises) {
      if (exercise.id == focusedId) return exercise;
    }
    for (final exercise in exercises) {
      if (exercise.sets.any((set) => !set.isCompleted)) return exercise;
    }
    return exercises.last;
  }

  /// The live display follows active entries only; focus is never persisted.
  void focusExercise(String exerciseEntryId) {
    if (activeWorkout?.exercises.any(
          (exercise) => exercise.id == exerciseEntryId,
        ) ??
        false) {
      currentExerciseId.value = exerciseEntryId;
    }
  }

  List<WorkoutSession> get history => data.value.history;
  WeightUnit get unit => data.value.unit;
  List<BodyWeightEntry> get bodyWeights => data.value.bodyWeights;
  UserProfile? get profile => data.value.profile;
  bool get requiresProfile =>
      !data.value.onboardingCompleted || (profile?.name.trim().isEmpty ?? true);

  /// Waits for all writes already queued, including writes added while waiting.
  Future<void> waitForPendingWrites() async {
    while (_pendingCount > 0) {
      await _pending;
    }
  }

  Future<bool> saveProfile(
    UserProfile profile, {
    required WeightUnit unit,
    double? startingWeight,
  }) => _commit((current) {
    if (profile.name.trim().isEmpty) {
      throw const FormatException('Enter your name.');
    }
    final kg = startingWeight == null ? null : weightToKg(startingWeight, unit);
    if (kg != null && (!kg.isFinite || kg <= 0 || kg > 1000)) {
      throw const FormatException('Enter a valid starting body weight.');
    }
    return current.copyWith(
      profile: profile,
      unit: unit,
      onboardingCompleted: true,
      bodyWeights: !current.onboardingCompleted && kg != null
          ? [
              BodyWeightEntry(id: _id(), measuredAt: _clock(), weightKg: kg),
              ...current.bodyWeights,
            ]
          : current.bodyWeights,
    );
  });

  Future<bool> setWorkoutPhoto(String workoutId, String? relativePath) =>
      _commit(
        (current) => _editSession(
          current,
          workoutId,
          (session) => session.copyWith(
            photoPath: relativePath,
            clearPhoto: relativePath == null,
          ),
        ),
      );

  Future<bool> importData(AppData imported) => _commit((current) {
    final historyIds = current.history.map((session) => session.id).toSet();
    final importedHistory = imported.history.where(
      (session) =>
          session.id != current.activeWorkout?.id && historyIds.add(session.id),
    );
    final history = [...current.history, ...importedHistory]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final weightIds = current.bodyWeights.map((entry) => entry.id).toSet();
    final weights = [
      ...current.bodyWeights,
      ...imported.bodyWeights.where((entry) => weightIds.add(entry.id)),
    ]..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    final candidate = imported.activeWorkout;
    final active =
        current.activeWorkout ??
        (candidate != null && !historyIds.contains(candidate.id)
            ? candidate
            : null);
    final merged = current.copyWith(
      history: history,
      bodyWeights: weights,
      activeWorkout: active,
    );
    // Backups have one global ID namespace, including exercises and sets.
    // Two valid files can conflict when combined. Reject the whole import
    // rather than persisting a log that can no longer be backed up.
    final ids = <String>{};
    void addId(String id) {
      if (!ids.add(id)) {
        throw const FormatException(
          'This backup has record IDs that conflict with your current log. Nothing was imported; your existing records are unchanged.',
        );
      }
    }

    for (final workout in [
      ...merged.history,
      if (merged.activeWorkout != null) merged.activeWorkout!,
    ]) {
      addId(workout.id);
      for (final exercise in workout.exercises) {
        addId(exercise.id);
        for (final set in exercise.sets) {
          addId(set.id);
        }
      }
    }
    for (final entry in merged.bodyWeights) {
      addId(entry.id);
    }
    return merged;
  });

  @override
  void onInit() {
    super.onInit();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => now.value = _clock(),
    );
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }

  String _id() => '${_clock().microsecondsSinceEpoch}-${_idCounter++}';

  Future<bool> _commit(
    AppData Function(AppData current) mutation, {
    void Function()? onSaved,
  }) {
    final result = Completer<bool>();
    _pendingCount++;
    isSaving.value = true;
    _pending = _pending.then((_) async {
      try {
        final next = mutation(data.value);
        await _repository.save(next);
        data.value = next;
        onSaved?.call();
        error.value = '';
        result.complete(true);
      } on FormatException catch (failure) {
        _report(failure.message);
        result.complete(false);
      } catch (_) {
        _report(
          'Could not save your changes. Your previous records are safe. Please try again.',
        );
        result.complete(false);
      } finally {
        _pendingCount--;
        isSaving.value = _pendingCount > 0;
      }
    });
    return result.future;
  }

  void _report(String message) {
    error.value = message;
    if (!Get.testMode && Get.context != null) {
      Get.snackbar(
        'Changes not saved',
        message,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  WorkoutSession? sessionById(String id) {
    if (activeWorkout?.id == id) return activeWorkout;
    for (final workout in history) {
      if (workout.id == id) return workout;
    }
    return null;
  }

  AppData _editSession(
    AppData current,
    String id,
    WorkoutSession Function(WorkoutSession) edit,
  ) {
    if (current.activeWorkout?.id == id) {
      return current.copyWith(activeWorkout: edit(current.activeWorkout!));
    }
    final index = current.history.indexWhere((session) => session.id == id);
    if (index < 0) {
      throw const FormatException('This workout could not be found.');
    }
    final updated = [...current.history];
    updated[index] = edit(updated[index]);
    return current.copyWith(history: updated);
  }

  Future<bool> startWorkout() => _commit((current) {
    if (current.activeWorkout != null) return current;
    final started = _clock();
    return current.copyWith(
      activeWorkout: WorkoutSession(
        id: _id(),
        name: 'Workout',
        startedAt: started,
        exercises: const [],
      ),
    );
  });

  Future<bool> discardWorkout() =>
      _commit((current) => current.copyWith(clearActiveWorkout: true));

  Future<bool> finishWorkout() => _commit((current) {
    final active = current.activeWorkout;
    if (active == null) {
      throw const FormatException('There is no active workout to finish.');
    }
    if (active.completedSets == 0) {
      throw const FormatException(
        'Complete at least one set before finishing your workout.',
      );
    }
    final finished = _clock();
    final completed = active.copyWith(
      finishedAt: finished.isBefore(active.startedAt)
          ? active.startedAt
          : finished,
    );
    return current.copyWith(
      history: [completed, ...current.history],
      clearActiveWorkout: true,
    );
  });

  /// Archives even unfinished sets and creates the next draft in one write.
  Future<bool> saveAndStartWorkout() => _commit((current) {
    final active = current.activeWorkout;
    if (active == null) {
      throw const FormatException('There is no active workout to save.');
    }
    final started = _clock();
    final archived = active.copyWith(
      finishedAt: started.isBefore(active.startedAt)
          ? active.startedAt
          : started,
    );
    final existingIds = {
      for (final workout in [active, ...current.history]) ...[
        workout.id,
        for (final exercise in workout.exercises) ...[
          exercise.id,
          ...exercise.sets.map((set) => set.id),
        ],
      ],
      ...current.bodyWeights.map((entry) => entry.id),
    };
    var nextId = _id();
    while (existingIds.contains(nextId)) {
      nextId = _id();
    }
    return current.copyWith(
      history: [archived, ...current.history],
      activeWorkout: WorkoutSession(
        id: nextId,
        name: 'Workout',
        startedAt: started,
        exercises: const [],
      ),
    );
  }, onSaved: () => currentExerciseId.value = null);

  Future<bool> renameWorkout(String id, String name) => _commit((current) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 80) {
      throw const FormatException(
        'Use a workout name between 1 and 80 characters.',
      );
    }
    return _editSession(
      current,
      id,
      (session) => session.copyWith(name: trimmed),
    );
  });

  Future<bool> deleteWorkout(String id) => _commit(
    (current) => current.copyWith(
      history: current.history.where((session) => session.id != id).toList(),
    ),
  );

  Future<bool> addExercise(String exerciseId) {
    String? addedEntryId;
    return _commit((current) {
      final workout = current.activeWorkout;
      if (workout == null) {
        throw const FormatException(
          'Start a workout before adding an exercise.',
        );
      }
      final definitions = exerciseCatalog.where(
        (item) => item.id == exerciseId,
      );
      if (definitions.isEmpty) {
        throw const FormatException('Choose an exercise from the library.');
      }
      final exercise = definitions.first;
      final previous = ExercisePerformance(current.history)
          .sessionsFor(
            exercise.id,
            name: exercise.name,
            before: workout.startedAt,
            excludingWorkoutId: workout.id,
          )
          .lastOrNull;
      final entryId = _id();
      addedEntryId = entryId;
      return current.copyWith(
        activeWorkout: workout.copyWith(
          exercises: [
            ...workout.exercises,
            WorkoutExercise(
              id: entryId,
              exerciseId: exercise.id,
              name: exercise.name,
              // Defaults belong to the new draft; completing a set is a
              // separate user action. Never reuse a prior set's identity.
              sets: previous == null
                  ? [WorkoutSet(id: _id(), reps: 8, weightKg: 0)]
                  : [
                      for (final set in previous.sets)
                        WorkoutSet(
                          id: _id(),
                          reps: set.reps,
                          weightKg: set.weightKg,
                        ),
                    ],
            ),
          ],
        ),
      );
    }, onSaved: () => focusExercise(addedEntryId!));
  }

  Future<bool> _editExercise(
    String workoutId,
    String exerciseId,
    WorkoutExercise Function(WorkoutExercise) edit, {
    bool makeCurrent = false,
  }) => _commit(
    (current) => _editSession(current, workoutId, (session) {
      if (!session.exercises.any((item) => item.id == exerciseId)) {
        throw const FormatException('This exercise could not be found.');
      }
      return session.copyWith(
        exercises: session.exercises
            .map((item) => item.id == exerciseId ? edit(item) : item)
            .toList(),
      );
    }),
    onSaved: makeCurrent
        ? () {
            if (activeWorkout?.id == workoutId) focusExercise(exerciseId);
          }
        : null,
  );

  Future<bool> removeExercise(String workoutId, String exerciseEntryId) =>
      _commit(
        (current) => _editSession(
          current,
          workoutId,
          (session) => session.copyWith(
            exercises: session.exercises
                .where((item) => item.id != exerciseEntryId)
                .toList(),
          ),
        ),
      );

  Future<bool> addSet(String workoutId, String exerciseEntryId) =>
      _editExercise(workoutId, exerciseEntryId, (exercise) {
        final previous = exercise.sets.isEmpty ? null : exercise.sets.last;
        return exercise.copyWith(
          sets: [
            ...exercise.sets,
            WorkoutSet(
              id: _id(),
              reps: previous?.reps ?? 8,
              weightKg: previous?.weightKg ?? 0,
            ),
          ],
        );
      }, makeCurrent: true);

  Future<bool> updateSet(
    String workoutId,
    String exerciseEntryId,
    String setId, {
    required int reps,
    required double weight,
    required bool completed,
  }) {
    // Capture the unit at submission, even when queued behind a settings write.
    final kg = weightToKg(weight, unit);
    return _editExercise(workoutId, exerciseEntryId, (exercise) {
      if (reps < 1 ||
          reps > 999 ||
          !weight.isFinite ||
          weight < 0 ||
          weight > 10000 ||
          kg > 10000) {
        throw const FormatException(
          'Enter 1–999 reps and a valid nonnegative weight up to 10,000.',
        );
      }
      if (!exercise.sets.any((set) => set.id == setId)) {
        throw const FormatException('This set could not be found.');
      }
      return exercise.copyWith(
        sets: exercise.sets
            .map(
              (set) => set.id == setId
                  ? set.copyWith(
                      reps: reps,
                      weightKg: kg,
                      isCompleted: completed,
                    )
                  : set,
            )
            .toList(),
      );
    }, makeCurrent: true);
  }

  Future<bool> deleteSet(
    String workoutId,
    String exerciseEntryId,
    String setId,
  ) => _editExercise(
    workoutId,
    exerciseEntryId,
    (exercise) => exercise.copyWith(
      sets: exercise.sets.where((set) => set.id != setId).toList(),
    ),
  );

  Future<bool> setUnit(WeightUnit unit) =>
      _commit((current) => current.copyWith(unit: unit));

  Future<bool> addBodyWeight(double displayedWeight) {
    final kg = weightToKg(displayedWeight, unit);
    return _commit((current) {
      if (!kg.isFinite || kg <= 0 || kg > 1000) {
        throw const FormatException(
          'Enter a body weight greater than zero and at most 1,000 kg.',
        );
      }
      return current.copyWith(
        bodyWeights: [
          BodyWeightEntry(id: _id(), measuredAt: _clock(), weightKg: kg),
          ...current.bodyWeights,
        ],
      );
    });
  }

  Future<bool> deleteBodyWeight(String id) => _commit(
    (current) => current.copyWith(
      bodyWeights: current.bodyWeights
          .where((entry) => entry.id != id)
          .toList(),
    ),
  );
}
