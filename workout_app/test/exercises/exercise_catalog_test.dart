import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/data/exercise_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'RepDB library has a unique illustrated record for every source exercise',
    () {
      expect(exerciseCatalog.length, 701);
      expect(exerciseCatalog.map((e) => e.id).toSet().length, 701);
      expect(exerciseCatalog.every((e) => e.id.startsWith('repdb_')), isTrue);
      expect(exerciseCatalog.every((e) => e.hasImage), isTrue);
      expect(exerciseCatalog.every((e) => e.instructions.isNotEmpty), isTrue);
    },
  );

  test(
    'common lifts use exact RepDB movements rather than related variants',
    () {
      const expected = {
        'repdb_squat': 'Barbell Back Squat',
        'repdb_bench-press': 'Barbell Bench Press',
        'repdb_deadlift': 'Barbell Deadlift',
        'repdb_barbell-row': 'Bent-Over Barbell Row',
        'repdb_tricep-pushdown': 'Cable Tricep Pushdown',
      };
      for (final entry in expected.entries) {
        expect(
          exerciseCatalog.where((e) => e.id == entry.key).map((e) => e.name),
          [entry.value],
        );
      }
      expect(exerciseCatalog.first.id, 'repdb_squat');
    },
  );

  test('paired and single poses retain their exact RepDB image paths', () {
    final squat = exerciseCatalog.firstWhere((e) => e.sourceId == 'squat');
    expect(squat.id, 'repdb_squat');
    expect(squat.illustrations.map((i) => i.label), ['Start', 'Peak']);
    expect(squat.illustrations.map((i) => i.asset), [
      'assets/exercises/repdb/flat/squat-start.webp',
      'assets/exercises/repdb/flat/squat-peak.webp',
    ]);
    final row = exerciseCatalog.firstWhere((e) => e.sourceId == 'barbell-row');
    expect(
      row.illustrations.first.asset,
      'assets/exercises/repdb/flat/barbell-row-start.webp',
    );
    final hold = exerciseCatalog.firstWhere((e) => e.sourceId == '90-90-hold');
    expect(hold.illustrations.single.label, 'Position');
    expect(
      hold.illustrations.single.asset,
      'assets/exercises/repdb/flat/90-90-hold-main.webp',
    );
  });

  test(
    'every bundled illustration is present and decodes as a static image',
    () async {
      final paths = exerciseCatalog
          .expand((e) => e.illustrations)
          .map((i) => i.asset)
          .toSet();
      expect(paths.length, 1217);
      final manifest = jsonDecode(
        File('assets/exercises/repdb/manifest.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(manifest['bundledImages'], paths.length);
      for (final path in paths) {
        final bytes = File(path).readAsBytesSync();
        final codec = await ui.instantiateImageCodec(bytes);
        expect(codec.frameCount, 1, reason: path);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 512, reason: path);
        expect(frame.image.height, 512, reason: path);
        frame.image.dispose();
        codec.dispose();
      }
    },
  );
}
