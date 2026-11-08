import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workout_app/app/workout_controller.dart';
import 'package:workout_app/core/theme.dart';
import 'package:workout_app/data/models.dart';
import 'package:workout_app/features/settings/settings_page.dart';

import '../support/memory_repository.dart';

void main() {
  setUp(() => Get.testMode = true);

  Future<MemoryRepository> mountSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = MemoryRepository()
      ..value = AppData(
        profile: UserProfile(
          name: 'Alex',
          goal: 'Build strength',
          experience: 'Beginner',
        ),
      );
    Get.put(WorkoutController(repository, repository.value));
    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.dark, home: const SettingsPage()),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  Future<void> disposeSettings(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await Get.delete<WorkoutController>(force: true);
    Get.reset();
  }

  Future<void> scrollTo(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(
      find.text(text),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'settings works without an update controller and keeps local controls',
    (tester) async {
      try {
        final repository = await mountSettings(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('YOUR PROFILE'), findsOneWidget);
        expect(find.text('Alex'), findsOneWidget);
        expect(find.text('Edit profile'), findsOneWidget);

        await scrollTo(tester, 'YOUR PREFERENCES');
        expect(find.text('YOUR PREFERENCES').hitTestable(), findsOneWidget);
        await scrollTo(tester, 'Pounds · lb');
        await tester.tap(find.text('Pounds · lb'));
        await tester.pumpAndSettle();
        expect(repository.value.unit, WeightUnit.lb);

        await scrollTo(tester, 'Download workout CSV');
        expect(find.text('Download workout CSV').hitTestable(), findsOneWidget);
        await scrollTo(tester, 'Backup CSV');
        expect(find.text('Backup CSV').hitTestable(), findsOneWidget);
        await scrollTo(tester, 'Import backup');
        expect(find.text('Import backup').hitTestable(), findsOneWidget);

        await scrollTo(tester, 'Your training stays local');
        expect(
          find.text('Your training stays local').hitTestable(),
          findsOneWidget,
        );
        expect(find.textContaining('Uninstalling the app'), findsOneWidget);
        expect(find.text('APP UPDATES'), findsNothing);
        expect(find.text('Check for updates'), findsNothing);
        expect(find.text('Download update'), findsNothing);
        expect(find.text('Restart & install'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await disposeSettings(tester);
      }
    },
  );

  testWidgets(
    'settings opens the bundled privacy policy without network access',
    (tester) async {
      try {
        await mountSettings(tester);
        await scrollTo(tester, 'Privacy policy');
        await tester.tap(find.text('Privacy policy'));
        await tester.pumpAndSettle();
        final policy = tester
            .widget<SelectableText>(find.byType(SelectableText))
            .textSpan!
            .toPlainText();
        expect(policy, contains('Dumbbell Privacy Policy'));
        expect(policy, contains('svgcarol@gmail.com'));
        expect(tester.takeException(), isNull);
      } finally {
        await disposeSettings(tester);
      }
    },
  );

  testWidgets(
    'settings keeps compact source credit and bundled license reachable',
    (tester) async {
      try {
        await mountSettings(tester);
        await scrollTo(tester, 'Sources & licenses');
        expect(find.text('Sources & licenses').hitTestable(), findsOneWidget);
        await scrollTo(tester, 'Exercise data by RepDB (repdb.co)');
        expect(
          find.text('Exercise data by RepDB (repdb.co)').hitTestable(),
          findsOneWidget,
        );
        expect(
          find.textContaining('The complete RepDB Free catalogue'),
          findsNothing,
        );
        await scrollTo(tester, 'Read license');
        await tester.tap(find.text('Read license'));
        await tester.pumpAndSettle();
        expect(find.text('RepDB Free license'), findsOneWidget);
        final license = tester.widget<SelectableText>(
          find.byType(SelectableText),
        );
        expect(license.data, contains('## Tier scope'));
        expect(license.data, contains('**Attribution required.**'));
        expect(license.data, contains('© 2026 Sergei Argutin (RepDB).'));
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(find.text('RepDB Free license'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await disposeSettings(tester);
      }
    },
  );
}
