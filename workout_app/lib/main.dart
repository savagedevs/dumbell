import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/bootstrap_controller.dart';
import 'app/routes.dart';
import 'core/theme.dart';
import 'data/workout_repository.dart';
import 'features/live_workout/live_workout_platform.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LiftLogApp());
}

class LiftLogApp extends StatelessWidget {
  const LiftLogApp({super.key, this.repository, this.liveWorkoutPlatform});
  final WorkoutRepository? repository;
  final LiveWorkoutPlatform? liveWorkoutPlatform;

  @override
  Widget build(BuildContext context) => GetMaterialApp(
    title: 'Dumbbell',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark,
    initialBinding: BindingsBuilder(() {
      Get.put(
        BootstrapController(
          repository: repository,
          liveWorkoutPlatform: liveWorkoutPlatform,
        ),
        permanent: true,
      );
    }),
    initialRoute: AppRoutes.boot,
    getPages: AppRoutes.pages,
    defaultTransition: Transition.cupertino,
  );
}
