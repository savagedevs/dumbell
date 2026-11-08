import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/features/settings/privacy_policy_page.dart';

void main() {
  testWidgets(
    'privacy information is readable offline and contains no unresolved template',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyPage()));
      await tester.pumpAndSettle();
      final policy = tester
          .widget<SelectableText>(find.byType(SelectableText))
          .textSpan!
          .toPlainText();
      expect(policy, contains('Dumbbell Privacy Policy'));
      expect(
        policy,
        contains('Backup CSV files exclude profile details and photos'),
      );
      expect(policy, contains('does not send your training records'));
      expect(policy, contains('clear Dumbbell\'s storage'));
      expect(policy, isNot(contains('{{CONTACT}}')));
      expect(policy, contains('svgcarol@gmail.com'));
      expect(tester.takeException(), isNull);
    },
  );
}
