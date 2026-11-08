import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:workout_app/app/workout_controller.dart';
import 'package:workout_app/data/models.dart';
import 'package:workout_app/features/data_transfer/csv_backup_codec.dart';
import 'package:workout_app/features/data_transfer/data_transfer_controller.dart';
import 'package:workout_app/features/data_transfer/data_transfer_file_service.dart';

import '../support/memory_repository.dart';

void main() {
  setUp(() => Get.testMode = true);

  test('backup export waits for pending durable writes instead of using a stale snapshot', () async {
    final repository = MemoryRepository();
    final workouts = WorkoutController(repository, AppData());
    final files = FakeTransferFiles();
    final transfer = DataTransferController(workouts: workouts, files: files);
    final saving = workouts.setUnit(WeightUnit.lb);
    await transfer.exportBackup();
    await saving;
    expect(
      CsvBackupCodec().decode(utf8.decode(files.saved!)).unit,
      WeightUnit.lb,
    );
    expect(transfer.status.value, contains('saved'));
  });

  test('save picker cancellation is distinct from errors', () async {
    final files = FakeTransferFiles()..cancelSave = true;
    final transfer = DataTransferController(
      workouts: WorkoutController(MemoryRepository(), AppData()),
      files: files,
    );
    await transfer.downloadWorkoutCsv();
    expect(transfer.status.value, contains('canceled'));
    expect(transfer.busy.value, isFalse);
    files.failSave = true;
    await transfer.downloadWorkoutCsv();
    expect(transfer.status.value, contains('Could not save'));
    expect(transfer.busy.value, isFalse);
  });

  test(
    'malformed backup never reaches merge confirmation or persists anything',
    () async {
      final repository = MemoryRepository();
      final files = FakeTransferFiles()
        ..incoming = Uint8List.fromList(utf8.encode('not,a,backup'));
      final transfer = DataTransferController(
        workouts: WorkoutController(repository, AppData()),
        files: files,
      );
      var confirmed = false;
      await transfer.importBackup((_) async {
        confirmed = true;
        return true;
      });
      expect(confirmed, isFalse);
      expect(repository.writes, 0);
      expect(transfer.status.value, contains('Dumbbell'));
    },
  );

  test(
    'valid import requires explicit confirmation and keeps existing draft',
    () async {
      final start = DateTime.utc(2026, 11, 8);
      final existingDraft = WorkoutSession(
        id: 'draft-local',
        name: 'Current workout',
        startedAt: start,
        exercises: [],
      );
      final incoming = AppData(
        history: [
          WorkoutSession(
            id: 'incoming',
            name: 'Imported workout',
            startedAt: start,
            finishedAt: start,
            exercises: [],
          ),
        ],
        activeWorkout: WorkoutSession(
          id: 'draft-import',
          name: 'Imported draft',
          startedAt: start,
          exercises: [],
        ),
      );
      final repository = MemoryRepository();
      final workouts = WorkoutController(
        repository,
        AppData(activeWorkout: existingDraft),
      );
      final files = FakeTransferFiles()
        ..incoming = Uint8List.fromList(
          utf8.encode(CsvBackupCodec().encode(incoming)),
        );
      final transfer = DataTransferController(workouts: workouts, files: files);
      await transfer.importBackup((summary) async {
        expect(summary.workouts, 1);
        expect(summary.draftMessage, contains('kept'));
        return false;
      });
      expect(workouts.history, isEmpty);
      expect(repository.writes, 0);
      await transfer.importBackup((_) async => true);
      expect(workouts.history.single.id, 'incoming');
      expect(workouts.activeWorkout?.id, 'draft-local');
      expect(transfer.status.value, contains('imported'));
    },
  );
}

class FakeTransferFiles implements DataTransferFileService {
  Uint8List? incoming;
  Uint8List? saved;
  bool cancelSave = false;
  bool failSave = false;
  @override
  Future<Uint8List?> pickBackup() async => incoming;
  @override
  Future<Uri?> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (failSave) throw StateError('Disk full');
    if (cancelSave) return null;
    saved = bytes;
    return Uri.parse('content://documents/$fileName');
  }
}
