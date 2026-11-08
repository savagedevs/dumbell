import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/core/theme.dart';
import 'package:workout_app/data/exercise_catalog.dart';
import 'package:workout_app/features/exercises/widgets/exercise_media_panel.dart';
import 'package:workout_app/features/exercises/widgets/exercise_thumbnail.dart';

void main() {
  for (final compact in [true, false]) {
    testWidgets(
      '${compact ? 'Thumbnail' : 'Detail'} fills a square without letterboxing the artwork',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 340,
                  child: compact
                      ? Align(
                          child: ExerciseThumbnail(
                            exercise: exerciseCatalog.first,
                          ),
                        )
                      : ExerciseMediaPanel(exercise: exerciseCatalog.first),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final image = find.byType(Image);
        final size = tester.getSize(image);
        expect(size.width, closeTo(size.height, .001));
        expect(tester.widget<Image>(image).fit, BoxFit.contain);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
