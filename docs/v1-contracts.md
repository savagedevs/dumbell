# Parallel implementation contracts

Paths below are relative to workout_app/lib. Do not modify files owned by another worker. Do not spawn further agents. No git repository exists; do not commit.

## Data agent owns data/**

data/models.dart exports:
- enum WeightUnit { kg, lb } with String get label
- WorkoutSet({required String id, required int reps, required double weightKg, bool isCompleted = false}); final fields, copyWith and JSON.
- WorkoutExercise({required String id, required String exerciseId, required String name, required List<WorkoutSet> sets}); copyWith and JSON.
- WorkoutSession({required String id, required String name, required DateTime startedAt, DateTime? finishedAt, required List<WorkoutExercise> exercises}); copyWith and JSON; Duration get duration (finishedAt ?? now minus startedAt); int get completedSets; double get volumeKg.
- BodyWeightEntry({required String id, required DateTime measuredAt, required double weightKg}); JSON.
- AppData({List<WorkoutSession> history = const [], WorkoutSession? activeWorkout, WeightUnit unit = WeightUnit.kg, List<BodyWeightEntry> bodyWeights = const []}); copyWith(..., bool clearActiveWorkout = false); JSON including schemaVersion 1.

data/exercise_catalog.dart exports ExerciseDefinition (id, name, muscleGroup, equipment, List<String> instructions) and const List<ExerciseDefinition> exerciseCatalog with 12+ strength exercises. Demonstrations are later scope.

data/workout_repository.dart exports abstract class WorkoutRepository { Future<AppData> load(); Future<void> save(AppData data); Future<void> close(); } and LocalWorkoutRepository implementing it with static Future<LocalWorkoutRepository> open(). Use Sembast native with path_provider/path; conditional web factory if feasible (sembast_web available). Atomic snapshot save, schema version validation, no destructive migrations. Root adds dependencies.

## Root owns core/**, app/**, main.dart and features/settings/**

core/theme.dart: AppColors.background, surface, elevated, lime, text, muted; AppTheme.dark.
core/widgets.dart: AppCard({required Widget child, EdgeInsetsGeometry? padding}); SectionHeading({required String title, Widget? trailing}); EmptyState({required IconData icon, required String title, required String message, Widget? action}); page padding can be supplied normally.
core/formatters.dart: formatDuration(Duration), formatDate(DateTime), formatWeight(double kg, WeightUnit unit) -> String (without unit), displayWeight(double kg, WeightUnit unit) -> double, weightToKg(double value, WeightUnit unit) -> double.
app/routes.dart: AppRoutes.home='/', workout='/workout', exercises='/exercises', history='/history', progress='/progress', settings='/settings', detail='/workout-detail'. Get.toNamed(detail, arguments: session.id); exercises arguments can be true for selection.
app/workout_controller.dart exports WorkoutController extends GetxController with:
- Rx<AppData> data; RxBool isSaving; RxString error; Rx<DateTime> now (ticks each second); WorkoutSession? get activeWorkout; List<WorkoutSession> get history; WeightUnit get unit; List<BodyWeightEntry> get bodyWeights.
- Future<bool> startWorkout(); Future<bool> discardWorkout(); Future<bool> finishWorkout(); Future<bool> renameWorkout(String id, String name); Future<bool> deleteWorkout(String id).
- Future<bool> addExercise(String exerciseId); Future<bool> removeExercise(String workoutId, String exerciseEntryId); Future<bool> addSet(String workoutId, String exerciseEntryId); Future<bool> updateSet(String workoutId, String exerciseEntryId, String setId, {required int reps, required double weight, required bool completed}); Future<bool> deleteSet(String workoutId, String exerciseEntryId, String setId).
- WorkoutSession? sessionById(String id); Future<bool> setUnit(WeightUnit unit); Future<bool> addBodyWeight(double displayedWeight); Future<bool> deleteBodyWeight(String id).
- All edits accept saved or active session IDs, validate values, and persist before publishing. updateSet receives weight in current display unit. Root handles failure snackbars; UI awaits bool before navigating.

## Workout agent owns features/workout/**

WorkoutPage and WorkoutDetailPage are const StatelessWidget/GetView widgets exported from workout_page.dart and workout_detail_page.dart. Use Get.find<WorkoutController>() or GetView. Page detail resolves id from Get.arguments string. GetX Obx reads data.value; now.value for elapsed. Use core theme/widgets. Dialog/text controllers must be disposed. Buttons disable during isSaving. Details permit editing sets and deleting saved sessions. Finish navigates to detail only when persistence succeeds. Do not write controller, repository, routes, theme or dependencies.

## Screens agent owns features/home/**, features/history/**, features/exercises/**, features/progress/**

HomePage, HistoryPage, ExercisesPage, ProgressPage const widgets, each in matching snake_case file. Root supplies Shell widget around the four root pages: implement pages as scrollable SafeArea content, no bottom navigation. ExercisesPage can be root or pushed selection route: if Get.arguments == true, choosing Add invokes controller.addExercise and Get.back on success. Support search, muscle filters and detail instructions via modal. Progress can include body weight entry/history with add/delete and simple custom charts reflecting real saved data. History opens detail via id. Home starts/resumes via workout route, settings via settings route and history via history route. Home visual should emphasize bold lime/white headline, weekly day indicators and real recent activity. No fake metrics, network photos or placeholder actions.
