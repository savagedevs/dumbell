import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../workout/media/workout_photo_service.dart';
import 'workout_share_renderer.dart';
import 'workout_share_service.dart';
import 'workout_share_summary.dart';

/// Call with the saved snapshot after pending workout editor changes flush.
Future<void> showWorkoutSharePreview(
  BuildContext context, {
  required WorkoutSession session,
  required WeightUnit unit,
}) async {
  if (session.finishedAt == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Save this workout before sharing.')),
    );
    return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => WorkoutSharePreviewPage(session: session, unit: unit),
    ),
  );
}

class WorkoutSharePreviewPage extends StatefulWidget {
  const WorkoutSharePreviewPage({
    super.key,
    required this.session,
    required this.unit,
    this.photoService,
    this.shareService = const WorkoutShareService(),
    this.renderer = const WorkoutShareRenderer(),
  });

  final WorkoutSession session;
  final WeightUnit unit;
  final WorkoutPhotoService? photoService;
  final WorkoutShareService shareService;
  final WorkoutShareImageRenderer renderer;

  @override
  State<WorkoutSharePreviewPage> createState() =>
      _WorkoutSharePreviewPageState();
}

class _WorkoutSharePreviewPageState extends State<WorkoutSharePreviewPage> {
  final _shareButton = GlobalKey();
  late final WorkoutShareSummary _summary;
  WorkoutPhotoService? _photoService;
  WorkoutShareFormat _format = WorkoutShareFormat.story;
  bool _includePhoto = false;
  bool _rendering = false;
  bool _sharing = false;
  int _renderRevision = 0;
  Uint8List? _png;
  String? _renderError;
  String? _shareStatus;
  bool _shareFailed = false;

  @override
  void initState() {
    super.initState();
    _summary = WorkoutShareSummary.fromSession(widget.session, widget.unit);
    _render();
  }

  @override
  void dispose() {
    _renderRevision++;
    super.dispose();
  }

  Future<void> _render() async {
    final revision = ++_renderRevision;
    final includePhoto = _includePhoto;
    final format = _format;
    setState(() {
      _rendering = true;
      _png = null;
      _renderError = null;
      _shareStatus = null;
    });
    var loadingPhoto = includePhoto;
    try {
      Uint8List? photo;
      if (includePhoto) {
        // The stored photo is not even read until the user explicitly opts in.
        final path = widget.session.photoPath;
        if (path == null) throw StateError('There is no saved workout photo.');
        _photoService ??=
            widget.photoService ??
            (Get.isRegistered<WorkoutPhotoService>()
                ? Get.find<WorkoutPhotoService>()
                : WorkoutPhotoService());
        photo = await _photoService!.readPhoto(path);
      }
      final png = await widget.renderer.render(
        summary: _summary,
        format: format,
        photoBytes: photo,
      );
      loadingPhoto = false;
      if (mounted && revision == _renderRevision) {
        setState(() => _png = png);
      }
    } catch (_) {
      if (mounted && revision == _renderRevision) {
        setState(
          () => _renderError = loadingPhoto
              ? 'This workout photo is unavailable. Turn off Include workout photo or try again.'
              : 'Could not create the image. Try again.',
        );
      }
    } finally {
      if (mounted && revision == _renderRevision) {
        setState(() => _rendering = false);
      }
    }
  }

  Rect _shareOrigin() {
    final box = _shareButton.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize && !box.size.isEmpty) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    final size = MediaQuery.sizeOf(context);
    return Rect.fromLTWH(size.width / 2, size.height / 2, 1, 1);
  }

  Future<void> _share() async {
    final png = _png;
    if (png == null || _sharing || _rendering) return;
    final origin = _shareOrigin();
    setState(() {
      _sharing = true;
      _shareStatus = null;
      _shareFailed = false;
    });
    try {
      final result = await widget.shareService.shareImage(
        png,
        format: _format,
        date: widget.session.startedAt,
        origin: origin,
      );
      if (mounted) {
        setState(
          () => _shareStatus = switch (result) {
            WorkoutShareOutcome.dismissed => 'Sharing canceled.',
            WorkoutShareOutcome.selected => 'Share option selected.',
            WorkoutShareOutcome.unavailable =>
              'Sharing returned without a status.',
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _shareFailed = true;
          _shareStatus = 'Could not open sharing. Try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _sharing;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close preview',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Share workout',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                const Text(
                  'Make it yours.',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.8,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose a format, then share the image.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    for (final format in WorkoutShareFormat.values)
                      ChoiceChip(
                        label: Text(format.label),
                        selected: _format == format,
                        onSelected: disabled
                            ? null
                            : (selected) {
                                if (!selected || _format == format) return;
                                setState(() => _format = format);
                                _render();
                              },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${_format.width} × ${_format.height} PNG',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.elevated),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: AspectRatio(
                      aspectRatio: _format.aspectRatio,
                      child: _png != null
                          ? Image.memory(
                              _png!,
                              key: const ValueKey('workout-share-image'),
                              fit: BoxFit.contain,
                              semanticLabel: _summary.accessibilityLabel,
                            )
                          : ColoredBox(
                              color: AppColors.surface,
                              child: Center(
                                child: _rendering
                                    ? const CircularProgressIndicator()
                                    : const Icon(
                                        Icons.image_not_supported_outlined,
                                        color: AppColors.muted,
                                        size: 48,
                                      ),
                              ),
                            ),
                    ),
                  ),
                ),
                if (widget.session.photoPath != null) ...[
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include workout photo'),
                    subtitle: const Text(
                      'Adds your saved photo to this image.',
                    ),
                    value: _includePhoto,
                    onChanged: disabled
                        ? null
                        : (value) {
                            setState(() => _includePhoto = value);
                            _render();
                          },
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Your profile and name are left out. Only completed sets count toward the stats.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_renderError case final error?) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: disabled || _rendering ? null : _render,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ),
                  ],
                  if (_shareStatus case final status?) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        status,
                        style: TextStyle(
                          color: _shareFailed
                              ? Theme.of(context).colorScheme.error
                              : AppColors.muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton.icon(
                    key: _shareButton,
                    onPressed: _png == null || _rendering || _sharing
                        ? null
                        : _share,
                    icon: _sharing
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.ios_share_rounded),
                    label: Text(_sharing ? 'Opening…' : 'Share image'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
