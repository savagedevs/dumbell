import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workout_app/app/workout_controller.dart';
import 'package:workout_app/core/theme.dart';
import 'package:workout_app/data/models.dart';
import 'package:workout_app/features/data_transfer/data_transfer_card.dart';

import '../support/memory_repository.dart';
import 'data_transfer_controller_test.dart' show FakeTransferFiles;

void main() {
  testWidgets(
    'readable download and separate backup controls fit a narrow screen with large text',
    (tester) async {
      Get.testMode = true;
      tester.view.physicalSize = const Size(320, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: DataTransferCard(
                    files: FakeTransferFiles(),
                    workouts: WorkoutController(MemoryRepository(), AppData()),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Download workout CSV'), findsOneWidget);
      expect(find.text('Backup CSV'), findsOneWidget);
      expect(find.text('Import backup'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
