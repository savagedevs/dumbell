import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/widgets.dart';
import '../data/workout_repository.dart';
import '../features/workout/media/workout_photo_service.dart';
import '../features/live_workout/live_workout_service.dart';
import '../features/live_workout/live_workout_platform.dart';
import 'routes.dart';
import 'workout_controller.dart';

class BootstrapController extends GetxController {
  BootstrapController({this.repository, this.liveWorkoutPlatform});
  final WorkoutRepository? repository;
  final LiveWorkoutPlatform? liveWorkoutPlatform;
  WorkoutRepository? _openedRepository;
  final isLoading = false.obs;
  final message = ''.obs;

  @override
  void onReady() {
    super.onReady();
    initialize();
  }

  Future<void> initialize() async {
    if (isLoading.value) return;
    isLoading.value = true;
    message.value = '';
    try {
      final storage =
          repository ??
          (_openedRepository ??= await LocalWorkoutRepository.open());
      final initial = await storage.load();
      final workouts = Get.put(
        WorkoutController(storage, initial),
        permanent: true,
      );
      if (!Get.testMode) {
        final photos = Get.put(WorkoutPhotoService(), permanent: true);
        // Finish recovery before a new picker can change its persisted target.
        await _recoverPhoto(workouts, photos);
      }
      final live = Get.put(
        LiveWorkoutService(workouts, platform: liveWorkoutPlatform),
        permanent: true,
      );
      await live.initialize();
      Get.offAllNamed(
        workouts.requiresProfile ? AppRoutes.profile : AppRoutes.home,
      );
      live.markNavigationReady();
    } catch (_) {
      message.value = 'Your records could not be opened. They have not been replaced. Retry, or check that this app version supports your saved data.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _recoverPhoto(
    WorkoutController workouts,
    WorkoutPhotoService photos,
  ) async {
    try {
      final recovered = await photos.recoverLostPhoto();
      if (recovered == null) return;
      final session = workouts.sessionById(recovered.workoutId);
      if (session == null) {
        await photos.deletePhoto(recovered.relativePath);
        await photos.completeRecovery(
          expectedPath: recovered.relativePath,
          workoutId: recovered.workoutId,
        );
        return;
      }
      final previous = session.photoPath;
      if (previous == recovered.relativePath ||
          await workouts.setWorkoutPhoto(session.id, recovered.relativePath)) {
        await photos.completeRecovery(
          expectedPath: recovered.relativePath,
          workoutId: recovered.workoutId,
        );
        if (previous != null && previous != recovered.relativePath) {
          await photos.deletePhoto(previous);
        }
      }
    } catch (_) {
      // Recovery is optional. Keep the pending target for the next launch;
      // an unavailable picker or file must not block access to the workout log.
    }
  }
}

class BootstrapPage extends GetView<BootstrapController> {
  const BootstrapPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Obx(
              () => controller.message.value.isEmpty
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, size: 48),
                        SizedBox(height: 20),
                        CircularProgressIndicator(),
                        SizedBox(height: 20),
                        Text('Opening your training log…'),
                      ],
                    )
                  : EmptyState(
                      icon: Icons.storage_outlined,
                      title: 'Your log needs attention',
                      message: controller.message.value,
                      action: FilledButton(
                        onPressed: controller.isLoading.value
                            ? null
                            : controller.initialize,
                        child: const Text('Retry'),
                      ),
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}
