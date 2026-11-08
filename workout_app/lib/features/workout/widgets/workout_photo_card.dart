import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/workout_controller.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../../../data/models.dart';
import '../media/workout_photo_service.dart';

class WorkoutPhotoCard extends StatefulWidget {
  const WorkoutPhotoCard({
    super.key,
    required this.session,
    this.service,
    this.workouts,
  });
  final WorkoutSession session;
  final WorkoutPhotoService? service;
  final WorkoutController? workouts;
  @override
  State<WorkoutPhotoCard> createState() => _WorkoutPhotoCardState();
}

class _WorkoutPhotoCardState extends State<WorkoutPhotoCard> {
  late final WorkoutPhotoService _service;
  Future<Uint8List>? _photo;
  String? _retryPath;
  String _status = '';
  bool _busy = false;
  WorkoutController get _workouts =>
      widget.workouts ?? Get.find<WorkoutController>();

  @override
  void initState() {
    super.initState();
    _service =
        widget.service ??
        (Get.isRegistered<WorkoutPhotoService>()
            ? Get.find<WorkoutPhotoService>()
            : WorkoutPhotoService());
    _load();
  }

  @override
  void didUpdateWidget(covariant WorkoutPhotoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.photoPath != widget.session.photoPath) _load();
  }

  void _load() {
    final path = widget.session.photoPath;
    _photo = path == null
        ? null
        : Future<Uint8List>.sync(() => _service.readPhoto(path));
  }

  Future<void> _choose() async {
    final source = await showModalBottomSheet<WorkoutPhotoSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, WorkoutPhotoSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, WorkoutPhotoSource.camera),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() {
      _busy = true;
      _status = '';
    });
    try {
      final path = await _service.pickPhoto(widget.session.id, source);
      if (path == null) {
        if (mounted) setState(() => _status = 'Photo selection canceled.');
        return;
      }
      _retryPath = path;
      await _attach(path);
    } on FormatException catch (error) {
      if (mounted) setState(() => _status = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _status = 'Could not add this photo. Check photo or camera access and try again. Your previous photo is safe.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attach(String path) async {
    final oldPath = widget.session.photoPath;
    if (!await _workouts.setWorkoutPhoto(widget.session.id, path)) {
      if (mounted) {
        setState(
          () => _status = 'Photo copied, but attachment could not be saved. Retry saving; your previous photo is safe.',
        );
      }
      return;
    }
    _retryPath = null;
    try {
      await _service.completeRecovery(
        expectedPath: path,
        workoutId: widget.session.id,
      );
    } catch (_) {
      /* Safe to retry on the next launch. */
    }
    if (oldPath != null && oldPath != path) {
      try {
        await _service.deletePhoto(oldPath);
      } catch (_) {
        /* Attachment has already committed. */
      }
    }
    if (mounted) {
      setState(() => _status = 'Photo saved privately on this device.');
    }
  }

  Future<void> _retry() async {
    if (_retryPath == null) return;
    setState(() => _busy = true);
    try {
      await _attach(_retryPath!);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final oldPath = widget.session.photoPath;
    final retryPath = _retryPath;
    final workoutId = widget.session.id;
    setState(() => _busy = true);
    try {
      // If clearing recovery fails, keep the current attachment. Otherwise a
      // later launch could resurrect a photo the user explicitly removed.
      await _service.completeRecovery(workoutId: workoutId);
      if (!await _workouts.setWorkoutPhoto(workoutId, null)) {
        if (mounted) {
          setState(
            () => _status =
                'Could not remove the attachment. Your photo is safe.',
          );
        }
        return;
      }
      for (final path in [oldPath, retryPath].whereType<String>()) {
        try {
          await _service.deletePhoto(path);
        } catch (_) {
          /* The record no longer references it. */
        }
      }
      _retryPath = null;
      if (mounted) setState(() => _status = 'Photo removed.');
    } catch (_) {
      if (mounted) {
        setState(
          () => _status =
              'Could not remove the attachment. Your photo is safe. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(title: 'WORKOUT PHOTO'),
        const SizedBox(height: 12),
        if (_photo != null)
          FutureBuilder<Uint8List>(
            future: _photo,
            builder: (context, snapshot) {
              if (snapshot.hasError) return const _PhotoFailure();
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    semanticLabel: 'Photo attached to ${widget.session.name}',
                    errorBuilder: (_, _, _) => const _PhotoFailure(),
                  ),
                ),
              );
            },
          )
        else
          const Text(
            'Keep a photo with this session. Gallery or camera, saved privately on this device.',
            style: TextStyle(color: AppColors.muted),
          ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : _choose,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(
                widget.session.photoPath == null
                    ? 'Add photo'
                    : 'Replace photo',
              ),
            ),
            if (widget.session.photoPath != null)
              TextButton.icon(
                onPressed: _busy ? null : _remove,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove photo'),
              ),
            if (_retryPath != null)
              FilledButton(
                onPressed: _busy ? null : _retry,
                child: const Text('Retry saving photo'),
              ),
          ],
        ),
        if (_busy) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        if (_status.isNotEmpty) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              _status,
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
        ],
        const SizedBox(height: 8),
        const Text(
          'Photos stay on this device and are not included in CSV backups.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    ),
  );
}

class _PhotoFailure extends StatelessWidget {
  const _PhotoFailure();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 16),
    child: Text(
      'This photo could not be loaded. You can replace it or remove the attachment.',
      style: TextStyle(color: AppColors.muted),
    ),
  );
}
