import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../app/workout_controller.dart';
import '../../core/formatters.dart';
import '../../data/models.dart';

/// Owns the local profile form. The app controller owns durable writes.
class ProfileController extends GetxController {
  ProfileController(this._workouts, {required this.editing, this.onFinished}) {
    final profile = _workouts.profile;
    name = TextEditingController(text: profile?.name ?? '');
    goal.value = profile?.goal ?? 'Stay consistent';
    experience.value = profile?.experience ?? 'Beginner';
    unit.value = _workouts.unit;
  }

  static const goals = UserProfile.goals;
  static const experiences = UserProfile.experienceLevels;

  final WorkoutController _workouts;
  final bool editing;
  final VoidCallback? onFinished;
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  final startingWeight = TextEditingController();
  final goal = 'Stay consistent'.obs;
  final experience = 'Beginner'.obs;
  final unit = WeightUnit.kg.obs;
  final busy = false.obs;
  final error = ''.obs;

  String? validateName(String? value) {
    final name = (value ?? '').trim();
    if (name.isEmpty) return 'Enter your name.';
    return name.length > 50 ? 'Use 50 characters or fewer.' : null;
  }

  String? validateStartingWeight(String? value) {
    if (editing || (value ?? '').trim().isEmpty) return null;
    final displayed = _parseWeight(value!);
    if (displayed == null || !displayed.isFinite || displayed <= 0) {
      return 'Enter a weight greater than zero, or leave this blank.';
    }
    if (weightToKg(displayed, unit.value) > 1000) {
      return 'Enter a body weight up to ${unit.value == WeightUnit.kg ? '1,000 kg' : '2,204.6 lb'}.';
    }
    return null;
  }

  double? _parseWeight(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  Future<bool> save() async {
    if (busy.value) return false;
    final valid = formKey.currentState?.validate() ?? true;
    final validationError =
        validateName(name.text) ?? validateStartingWeight(startingWeight.text);
    if (!valid || validationError != null) {
      error.value = validationError ?? 'Check the highlighted fields.';
      return false;
    }
    busy.value = true;
    error.value = '';
    try {
      final saved = await _workouts.saveProfile(
        UserProfile(
          name: name.text.trim(),
          goal: goal.value,
          experience: experience.value,
        ),
        unit: unit.value,
        startingWeight: editing || startingWeight.text.trim().isEmpty
            ? null
            : _parseWeight(startingWeight.text),
      );
      if (!saved) {
        error.value = _workouts.error.value;
        return false;
      }
      _finish();
      return true;
    } finally {
      busy.value = false;
    }
  }

  void _finish() {
    if (onFinished != null) {
      onFinished!();
    } else if (editing) {
      Get.back<void>();
    } else {
      Get.offAllNamed<void>(AppRoutes.home);
    }
  }

  @override
  void onClose() {
    name.dispose();
    startingWeight.dispose();
    super.onClose();
  }
}
