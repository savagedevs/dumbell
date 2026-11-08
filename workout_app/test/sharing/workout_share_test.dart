import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:workout_app/core/theme.dart';
import 'package:workout_app/data/models.dart';
import 'package:workout_app/features/sharing/workout_share_preview.dart';
import 'package:workout_app/features/sharing/workout_share_renderer.dart';
import 'package:workout_app/features/sharing/workout_share_service.dart';
import 'package:workout_app/features/sharing/workout_share_summary.dart';
import 'package:workout_app/features/workout/media/workout_photo_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('summary uses only completed sets, combines exact exercise IDs and converts volume', () {
    final summary = WorkoutShareSummary.fromSession(
      shareSession(),
      WeightUnit.lb,
    );
    expect(summary.title, 'Evening strength');
    expect(summary.completedSets, 3);
    expect(summary.volume, '881.8');
    expect(summary.volumeUnit, 'lb');
    expect(summary.duration, '45:30');
    expect(summary.highlights, hasLength(2));
    expect(summary.highlights.first.name, 'Squat');
    expect(summary.highlights.first.details, '2 sets · 10 reps');
    expect(summary.highlights.first.load, '110.2 lb top set');
    expect(summary.highlights.last.details, '1 set · 12 reps');
    expect(summary.highlights.last.load, 'No added weight');
    expect(
      summary.highlights.any((item) => item.name == 'Not logged'),
      isFalse,
    );
  });

  test(
    'empty completed history is truthful and unfinished sessions are rejected',
    () {
      final session = shareSession().copyWith(exercises: []);
      final summary = WorkoutShareSummary.fromSession(session, WeightUnit.kg);
      expect(summary.completedSets, 0);
      expect(summary.volume, '0');
      expect(summary.highlights, isEmpty);
      expect(
        () => WorkoutShareSummary.fromSession(
          session.copyWith(clearFinishedAt: true),
          WeightUnit.kg,
        ),
        throwsArgumentError,
      );
    },
  );

  test('real renderer exports exact Story and Square PNG dimensions with long content', () async {
    final summary = WorkoutShareSummary.fromSession(
      shareSession().copyWith(
        name: List.filled(20, 'A very long strength workout').join(' '),
        exercises: List.generate(
          30,
          (index) => WorkoutExercise(
            id: 'entry-$index',
            exerciseId: 'move-$index',
            name: 'Long exercise name $index with additional details',
            sets: [
              WorkoutSet(
                id: 'set-$index',
                reps: 12,
                weightKg: 0,
                isCompleted: true,
              ),
            ],
          ),
        ),
      ),
      WeightUnit.kg,
    );
    for (final format in WorkoutShareFormat.values) {
      final png = await const WorkoutShareRenderer().render(
        summary: summary,
        format: format,
      );
      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      expect(image.width, 1080);
      expect(image.height, format == WorkoutShareFormat.story ? 1920 : 1080);
      expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      image.dispose();
      codec.dispose();
    }
  });

  test('native boundary receives one PNG, stable private-free filename and iPad origin', () async {
    final boundary = RecordingShareBoundary();
    final service = WorkoutShareService(boundary: boundary);
    final png = await const WorkoutShareRenderer().render(
      summary: WorkoutShareSummary.fromSession(shareSession(), WeightUnit.kg),
      format: WorkoutShareFormat.square,
    );
    final result = await service.shareImage(
      png,
      format: WorkoutShareFormat.square,
      date: DateTime(2026, 11, 8),
      origin: const Rect.fromLTWH(24, 100, 200, 56),
    );
    expect(result, WorkoutShareOutcome.dismissed);
    final params = boundary.params.single;
    expect(params.sharePositionOrigin, const Rect.fromLTWH(24, 100, 200, 56));
    expect(params.fileNameOverrides, ['Dumbbell_2026-11-08_square.png']);
    expect(params.files!.single.mimeType, 'image/png');
    expect(await params.files!.single.readAsBytes(), png);
    expect(params.text, isNull);
    expect(params.uri, isNull);
    expect(params.subject, isNull);
  });

  testWidgets(
    'preview reads a saved photo only after opt-in and shares the exact displayed image',
    (tester) async {
      final photo = await tester.runAsync(solidPhoto);
      final store = ReadOnlyPhotoStore(photo!);
      final boundary = RecordingShareBoundary();
      final session = shareSession();
      final original = session.toJson();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: WorkoutSharePreviewPage(
            session: session,
            unit: WeightUnit.kg,
            photoService: WorkoutPhotoService(store: store),
            shareService: WorkoutShareService(boundary: boundary),
          ),
        ),
      );
      await finishRendering(tester);
      expect(store.reads, 0);
      expect(boundary.params, isEmpty);
      final plain = displayedPng(tester);
      await tester.tap(find.text('Share image'));
      await tester.pumpAndSettle();
      expect(await boundary.params.single.files!.single.readAsBytes(), plain);
      expect(find.text('Sharing canceled.'), findsOneWidget);
      expect(find.text('Shared!'), findsNothing);

      await tester.scrollUntilVisible(find.text('Include workout photo'), 250);
      await tester.tap(find.text('Include workout photo'));
      await finishRendering(tester);
      expect(store.reads, 1);
      final withPhoto = displayedPng(tester);
      expect(withPhoto, isNot(orderedEquals(plain)));
      await tester.tap(find.text('Share image'));
      await tester.pumpAndSettle();
      expect(await boundary.params.last.files!.single.readAsBytes(), withPhoto);
      expect(session.toJson(), original);
      expect(store.mutations, 0);
    },
  );

  testWidgets(
    'deleted photo and native failure stay visible without changing records',
    (tester) async {
      final store = ReadOnlyPhotoStore(Uint8List(0))..failRead = true;
      final boundary = RecordingShareBoundary()
        ..failure = PlatformException(code: 'unavailable');
      final session = shareSession();
      final original = session.toJson();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: WorkoutSharePreviewPage(
            session: session,
            unit: WeightUnit.kg,
            photoService: WorkoutPhotoService(store: store),
            shareService: WorkoutShareService(boundary: boundary),
          ),
        ),
      );
      await finishRendering(tester);
      await tester.tap(find.text('Share image'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not open sharing'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Include workout photo'), 250);
      await tester.tap(find.text('Include workout photo'));
      await finishRendering(tester);
      expect(
        find.textContaining('This workout photo is unavailable'),
        findsOneWidget,
      );
      final shareButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Share image'),
      );
      expect(shareButton.onPressed, isNull);
      expect(session.toJson(), original);
      expect(store.mutations, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'preview adapts to 320px and large text with both format choices reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: WorkoutSharePreviewPage(
            session: shareSession(),
            unit: WeightUnit.kg,
          ),
        ),
      );
      await finishRendering(tester);
      await tester.ensureVisible(find.text('Square 1:1'));
      await tester.pump();
      await tester.tap(find.text('Square 1:1'));
      await finishRendering(tester);
      final size = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(displayedPng(tester));
        final image = (await codec.getNextFrame()).image;
        final size = Size(image.width.toDouble(), image.height.toDouble());
        image.dispose();
        codec.dispose();
        return size;
      });
      expect(size, const Size(1080, 1080));
      expect(find.text('Share image'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

WorkoutSession shareSession() => WorkoutSession(
  id: 'saved-private-id',
  name: 'Evening strength',
  startedAt: DateTime(2026, 11, 8, 18),
  finishedAt: DateTime(2026, 11, 8, 18, 45, 30),
  photoPath: 'workout_photos/private.png',
  exercises: [
    WorkoutExercise(
      id: 'a',
      exerciseId: 'squat',
      name: 'Squat',
      sets: [
        WorkoutSet(id: 'a1', reps: 5, weightKg: 50, isCompleted: true),
        WorkoutSet(id: 'a2', reps: 100, weightKg: 999),
      ],
    ),
    WorkoutExercise(
      id: 'b',
      exerciseId: 'pushup',
      name: 'Push-up',
      sets: [WorkoutSet(id: 'b1', reps: 12, weightKg: 0, isCompleted: true)],
    ),
    WorkoutExercise(
      id: 'c',
      exerciseId: 'squat',
      name: 'Squat',
      sets: [WorkoutSet(id: 'c1', reps: 5, weightKg: 30, isCompleted: true)],
    ),
    WorkoutExercise(
      id: 'd',
      exerciseId: 'not-logged',
      name: 'Not logged',
      sets: [WorkoutSet(id: 'd1', reps: 10, weightKg: 100)],
    ),
  ],
);

Future<Uint8List> solidPhoto() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(const Color(0xFFFF5522), BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(32, 32);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

Uint8List displayedPng(WidgetTester tester) =>
    (tester
                .widget<Image>(
                  find.byKey(const ValueKey('workout-share-image')),
                )
                .image
            as MemoryImage)
        .bytes;

Future<void> finishRendering(WidgetTester tester) async {
  // Canvas image encoding runs on the engine rather than the fake test clock.
  var ready = false;
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Share image'),
    );
    ready =
        button.onPressed != null ||
        find
            .textContaining('This workout photo is unavailable')
            .evaluate()
            .isNotEmpty;
    if (ready) break;
  }
  expect(
    ready,
    isTrue,
    reason: 'Image rendering should complete or show a recoverable error.',
  );
  await tester.pump(const Duration(milliseconds: 300));
}

class RecordingShareBoundary implements WorkoutShareBoundary {
  final params = <ShareParams>[];
  Object? failure;
  @override
  Future<ShareResult> share(ShareParams value) async {
    params.add(value);
    if (failure != null) throw failure!;
    return const ShareResult('', ShareResultStatus.dismissed);
  }
}

class ReadOnlyPhotoStore implements WorkoutPhotoStore {
  ReadOnlyPhotoStore(this.bytes);
  final Uint8List bytes;
  var reads = 0;
  var mutations = 0;
  var failRead = false;
  @override
  Future<Uint8List> readPhoto(String relativePath) async {
    reads++;
    if (failRead) throw StateError('Photo deleted');
    return bytes;
  }

  @override
  Future<PendingWorkoutPhoto?> readPending() async => null;
  @override
  Future<void> writePending(PendingWorkoutPhoto? pending) async => mutations++;
  @override
  Future<void> writePhoto(String relativePath, Uint8List bytes) async =>
      mutations++;
  @override
  Future<void> deletePhoto(String relativePath) async => mutations++;
}
