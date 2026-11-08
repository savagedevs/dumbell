import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/core/feedback_motion.dart';

void main() {
  Widget host(Widget child, {bool reduced = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Center(child: child),
    ),
  );

  testWidgets('entry feedback waits until the incoming screen is visible', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('Previous screen')),
      ),
    );
    navigator.currentState!.push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (context, animation, secondaryAnimation) => const Scaffold(
          body: Column(
            children: [
              WelcomeFade(animate: true, child: Text('Welcome back')),
              CompletionSparkle(
                enabled: true,
                child: SizedBox(width: 34, height: 34),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final route = ModalRoute.of(tester.element(find.byType(WelcomeFade)))!;
    expect(route.animation!.status, AnimationStatus.forward);
    await tester.pump(const Duration(milliseconds: 300));
    final greeting = find.descendant(
      of: find.byType(WelcomeFade),
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(greeting).opacity, 0);
    expect(find.byKey(const ValueKey('completion-sparkles')), findsNothing);
    for (
      var i = 0;
      i < 12 && route.animation!.status != AnimationStatus.completed;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(route.animation!.status, AnimationStatus.completed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.widget<Opacity>(greeting).opacity, inExclusiveRange(0, 1));
    expect(find.byKey(const ValueKey('completion-sparkles')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(greeting).opacity, 1);
    expect(find.byKey(const ValueKey('completion-sparkles')), findsNothing);
  });

  testWidgets('set feedback pops only on a newly completed set', (
    tester,
  ) async {
    Widget feedback(bool complete) => host(
      SetCompletionFeedback(
        completed: complete,
        child: const SizedBox(width: 48, height: 48),
      ),
    );
    await tester.pumpWidget(feedback(true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.widget<Transform>(find.byType(Transform)).transform.storage[0],
      1,
    );
    await tester.pumpWidget(feedback(false));
    await tester.pumpWidget(feedback(true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.widget<Transform>(find.byType(Transform)).transform.storage[0],
      greaterThan(1),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Transform>(find.byType(Transform)).transform.storage[0],
      1,
    );
  });

  testWidgets('sparkles finish once and do not restart on rebuild', (
    tester,
  ) async {
    Widget sparkle() => host(
      const CompletionSparkle(
        enabled: true,
        child: SizedBox(width: 34, height: 34),
      ),
    );
    await tester.pumpWidget(sparkle());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('completion-sparkles')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('completion-sparkles')), findsNothing);
    await tester.pumpWidget(sparkle());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('completion-sparkles')), findsNothing);
  });

  testWidgets('reduced motion suppresses and stops feedback', (tester) async {
    Widget feedback(bool reduced, bool complete) => host(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const WelcomeFade(animate: true, child: Text('Welcome back')),
          SetCompletionFeedback(
            completed: complete,
            child: const Text('Check'),
          ),
          const CompletionSparkle(enabled: true, child: Text('Saved')),
          SetProgress(value: complete ? 1 : 0),
        ],
      ),
      reduced: reduced,
    );
    await tester.pumpWidget(feedback(false, false));
    await tester.pumpWidget(feedback(false, true));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(feedback(true, true));
    expect(find.byKey(const ValueKey('completion-sparkles')), findsNothing);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    expect(
      tester.widget<Transform>(find.byType(Transform)).transform.storage[0],
      1,
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      1,
    );
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('scrolling the summary away and back does not replay sparkles', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        ListView(
          children: const [
            Align(
              alignment: Alignment.centerLeft,
              child: CompletionSparkle(
                enabled: true,
                child: SizedBox(width: 34, height: 34),
              ),
            ),
            SizedBox(height: 2000),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 1000));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('completion-sparkles')), findsNothing);
  });
}
