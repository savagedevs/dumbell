import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../features/exercises/exercises_page.dart';
import '../features/data_transfer/data_transfer_card.dart';
import '../features/history/history_page.dart';
import '../features/home/home_page.dart';
import '../features/progress/progress_page.dart';
import '../features/exercise_progress/exercise_progress_controller.dart';
import '../features/exercise_progress/exercise_progress_page.dart';
import '../features/profile/profile_page.dart';
import '../features/profile/profile_controller.dart';
import '../features/settings/settings_page.dart';
import '../features/workout/workout_detail_page.dart';
import '../features/workout/workout_page.dart';
import 'bootstrap_controller.dart';
import 'shell.dart';
import 'workout_controller.dart';

abstract final class AppRoutes {
  static const boot = '/boot';
  static const home = '/';
  static const workout = '/workout';
  static const exercises = '/exercises';
  static const history = '/history';
  static const progress = '/progress';
  static const settings = '/settings';
  static const profile = '/profile';
  static const downloads = '/downloads';
  static const detail = '/workout-detail';
  static const exerciseProgress = '/exercise-progress';

  static ExerciseProgressArguments get _progressRequest =>
      Get.arguments is ExerciseProgressArguments
      ? Get.arguments as ExerciseProgressArguments
      : const ExerciseProgressArguments(exerciseId: '', name: 'Exercise');

  static List<GetPage<dynamic>> get pages => [
    GetPage(name: boot, page: () => const BootstrapPage()),
    GetPage(
      name: exerciseProgress,
      page: () => ExerciseProgressPage(
        controller: Get.find<ExerciseProgressController>(
          tag: _progressRequest.exerciseId,
        ),
      ),
      middlewares: [_ReadyGuard()],
      binding: BindingsBuilder(() {
        final request = _progressRequest;
        Get.lazyPut(
          () => ExerciseProgressController(
            Get.find<WorkoutController>(),
            request,
          ),
          tag: request.exerciseId,
        );
      }),
    ),
    GetPage(
      name: downloads,
      page: () => Scaffold(
        appBar: AppBar(title: const Text('Downloads & backups')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(22),
                children: const [DataTransferCard()],
              ),
            ),
          ),
        ),
      ),
      middlewares: [_ReadyGuard()],
    ),
    GetPage(
      name: profile,
      page: () => const ProfilePage(),
      middlewares: [_ReadyGuard()],
      binding: BindingsBuilder(
        () => Get.lazyPut(
          () => ProfileController(
            Get.find<WorkoutController>(),
            editing: Get.arguments == true,
          ),
        ),
      ),
    ),
    GetPage(
      name: home,
      page: () => const AppShell(index: 0, child: HomePage()),
      middlewares: [_ReadyGuard()],
    ),
    GetPage(
      name: history,
      page: () => const AppShell(index: 1, child: HistoryPage()),
      middlewares: [_ReadyGuard()],
    ),
    GetPage(
      name: progress,
      page: () => const AppShell(index: 2, child: ProgressPage()),
      middlewares: [_ReadyGuard()],
    ),
    GetPage(
      name: exercises,
      page: () => Get.arguments == true
          ? const Scaffold(body: ExercisesPage())
          : const AppShell(index: 3, child: ExercisesPage()),
      middlewares: [_ReadyGuard()],
    ),
    GetPage(
      name: workout,
      page: () => const WorkoutPage(),
      middlewares: [_ReadyGuard()],
    ),
    GetPage(
      name: detail,
      page: () => const WorkoutDetailPage(),
      middlewares: [_ReadyGuard()],
    ),
    GetPage(
      name: settings,
      page: () => const SettingsPage(),
      middlewares: [_ReadyGuard()],
    ),
  ];
}

class _ReadyGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (!Get.isRegistered<WorkoutController>()) {
      return const RouteSettings(name: AppRoutes.boot);
    }
    if (route != AppRoutes.profile &&
        Get.find<WorkoutController>().requiresProfile) {
      return const RouteSettings(name: AppRoutes.profile);
    }
    return null;
  }
}
