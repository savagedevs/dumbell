import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/data/exercise_catalog.dart';
import 'package:workout_app/features/exercises/widgets/exercise_attribution.dart';

const _licenseAsset = 'assets/exercises/licenses/REPDB-FREE-LICENSE.md';

void main() {
  testWidgets('visible RepDB credit opens the credited provider', (
    tester,
  ) async {
    Uri? openedUrl;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepDbCredit(
            onOpenUrl: (url) async {
              openedUrl = url;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Exercise data by RepDB (repdb.co)'));
    await tester.pump();

    expect(openedUrl, Uri.parse('https://repdb.co'));
  });

  testWidgets(
    'exercise source follows its upstream ID and credits AI artwork',
    (tester) async {
      Uri? openedUrl;
      const exercise = ExerciseDefinition(
        id: 'repdb_barbell-squat',
        sourceId: 'barbell-squat',
        name: 'Barbell Squat',
        muscleGroup: 'Quadriceps',
        equipment: 'Barbell',
        description: 'A barbell squat.',
        instructions: ['Squat with control.'],
        tips: [],
        illustrations: [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExerciseAttributionView(
                exercise: exercise,
                onOpenUrl: (url) async {
                  openedUrl = url;
                  return true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Sources & license'));
      await tester.pumpAndSettle();
      expect(find.text('Exercise data by RepDB (repdb.co)'), findsOneWidget);
      expect(find.textContaining('AI-generated'), findsOneWidget);
      await tester.tap(find.text('View source exercise'));
      await tester.pump();

      expect(
        openedUrl,
        Uri.parse('https://exercise-dataset.com/exercise/barbell-squat/'),
      );
    },
  );

  testWidgets('Read license displays the complete bundled RepDB Free license', (
    tester,
  ) async {
    final license = File(_licenseAsset).readAsStringSync();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showRepDbLicense(context),
              child: const Text('Read license'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Read license'));
    await tester.pumpAndSettle();

    expect(find.text('RepDB Free license'), findsOneWidget);
    expect(find.widgetWithText(SelectableText, license), findsOneWidget);
    expect(find.textContaining('CC0'), findsNothing);
    expect(find.textContaining('CC-BY-SA'), findsNothing);
  });

  testWidgets(
    'an unavailable license reports the source without substituting',
    (tester) async {
      rootBundle.evict(_licenseAsset);
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMessageHandler(
        'flutter/assets',
        (message) async => null,
      );
      addTearDown(() {
        messenger.setMockMessageHandler('flutter/assets', null);
        rootBundle.evict(_licenseAsset);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showRepDbLicense(context),
                child: const Text('Read license'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Read license'));
      await tester.pumpAndSettle();

      expect(find.textContaining('could not be loaded'), findsOneWidget);
      expect(find.textContaining('https://repdb.co'), findsOneWidget);
      expect(find.textContaining('CC0'), findsNothing);
      expect(find.textContaining('CC-BY-SA'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
