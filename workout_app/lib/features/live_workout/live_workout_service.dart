import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../app/workout_controller.dart';
import 'live_workout_platform.dart';
import 'live_workout_snapshot.dart';

/// Synchronizes durable state to Android; native failures never block saving.
class LiveWorkoutService extends GetxService with WidgetsBindingObserver {
  LiveWorkoutService(
    this._workouts, {
    LiveWorkoutPlatform? platform,
    this.onOpenWorkout,
  }) : _platform = platform ?? AndroidLiveWorkoutPlatform();

  final WorkoutController _workouts;
  final LiveWorkoutPlatform _platform;
  final VoidCallback? onOpenWorkout;
  final notificationsAllowed = false.obs;
  final busy = false.obs;
  final message = ''.obs;
  final _workers = <Worker>[];
  Future<void> _pending = Future<void>.value();
  Future<void>? _initialization;
  LiveWorkoutSnapshot? _queued;
  bool _draining = false;
  bool _closed = false;
  bool _navigationReady = false;
  bool _openPending = false;
  bool _openingScheduled = false;
  bool _live = true;
  bool _permissionAsked = false;
  String? _previousWorkoutId;
  String? _published;

  bool get supported => _platform.supported;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (!supported) return;
    WidgetsBinding.instance.addObserver(this);
    _platform.setOpenWorkoutHandler(_handleOpen);
    _previousWorkoutId = _workouts.activeWorkout?.id;
    _workers.add(
      ever(_workouts.data, (_) {
        final id = _workouts.activeWorkout?.id;
        final started = id != null && id != _previousWorkoutId;
        _previousWorkoutId = id;
        _sync();
        _tryOpen();
        if (started &&
            !_permissionAsked &&
            !notificationsAllowed.value &&
            !_workouts.requiresProfile) {
          _permissionAsked = true;
          unawaited(enableNotifications());
        }
      }),
    );
    _workers.add(ever(_workouts.currentExerciseId, (_) => _sync()));
    try {
      notificationsAllowed.value = await _platform.notificationsEnabled();
      if (await _platform.getLaunchAction()) _handleOpen();
    } catch (_) {
      message.value = 'Live workout displays are unavailable right now. Your workout is still saved.';
    }
    _sync();
    await flush();
  }

  LiveWorkoutSnapshot get _snapshot => LiveWorkoutSnapshot.fromWorkout(
    _workouts.activeWorkout,
    exercise: _workouts.currentExercise,
    live: _live,
  );

  void _sync({bool force = false}) {
    if (!supported || _closed) return;
    final snapshot = _snapshot;
    if (!force &&
        !_draining &&
        jsonEncode(snapshot.toMap()) == _published &&
        _queued == null) {
      return;
    }
    _queued = snapshot;
    if (_draining) return;
    _draining = true;
    _pending = _drain();
  }

  Future<void> _drain() async {
    try {
      while (_queued != null && !_closed) {
        final next = _queued!;
        _queued = null;
        try {
          await _platform.updateWorkout(next);
          _published = jsonEncode(next.toMap());
        } catch (_) {
          message.value = 'Could not refresh the workout display. Your workout is still saved.';
        }
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> flush() async {
    while (_draining) {
      await _pending;
    }
  }

  void markNavigationReady() {
    _navigationReady = true;
    _tryOpen();
  }

  void _handleOpen() {
    _openPending = true;
    _tryOpen();
  }

  void _tryOpen() {
    if (!_navigationReady ||
        !_openPending ||
        _workouts.requiresProfile ||
        _openingScheduled ||
        _closed) {
      return;
    }
    _openingScheduled = true;
    // Route callbacks are delivered after the current save/profile navigation.
    Timer.run(() {
      _openingScheduled = false;
      if (_closed || !_openPending || _workouts.requiresProfile) return;
      _openPending = false;
      if (onOpenWorkout != null) {
        onOpenWorkout!();
      } else if (_workouts.activeWorkout != null) {
        if (Get.currentRoute != AppRoutes.workout) {
          Get.offAllNamed(AppRoutes.workout);
        }
      } else {
        Get.offAllNamed(AppRoutes.home);
      }
    });
  }

  Future<void> enableNotifications() async {
    if (!supported || busy.value || _closed) return;
    busy.value = true;
    try {
      notificationsAllowed.value = await _platform.requestNotifications();
      message.value = notificationsAllowed.value
          ? 'Workout notifications enabled.'
          : 'Notifications are off. You can enable them in Android notification settings; workout logging still works.';
      _sync(force: true);
      await flush();
    } catch (_) {
      message.value =
          'Could not enable notifications. Workout logging still works.';
    } finally {
      busy.value = false;
    }
  }

  Future<void> addHomeWidget() async {
    if (!supported || busy.value || _closed) return;
    busy.value = true;
    try {
      final requested = await _platform.requestPinWidget();
      message.value = requested
          ? 'Confirm Add on your home screen to place the workout widget.'
          : 'Long press your home screen, open Widgets, then choose Dumbbell.';
    } catch (_) {
      message.value =
          'Open Widgets from your Android home screen, then choose Dumbbell.';
    } finally {
      busy.value = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _live = true;
      _sync(force: true);
      unawaited(_refreshPermission());
    } else if (state == AppLifecycleState.detached) {
      _live = false;
      _sync(force: true);
    }
  }

  Future<void> _refreshPermission() async {
    if (!supported || _closed) return;
    try {
      notificationsAllowed.value = await _platform.notificationsEnabled();
    } catch (_) {}
  }

  @override
  void onClose() {
    _closed = true;
    for (final worker in _workers) {
      worker.dispose();
    }
    if (supported) {
      WidgetsBinding.instance.removeObserver(this);
      _platform.setOpenWorkoutHandler(null);
    }
    super.onClose();
  }
}
