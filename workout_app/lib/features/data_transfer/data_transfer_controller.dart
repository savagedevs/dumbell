import 'dart:convert';
import 'dart:typed_data';

import 'package:get/get.dart';

import '../../app/workout_controller.dart';
import '../../data/models.dart';
import 'csv_backup_codec.dart';
import 'data_transfer_file_service.dart';
import 'workout_csv_exporter.dart';

class BackupImportSummary {
  BackupImportSummary(AppData incoming, AppData current)
    : workouts = incoming.history.length,
      exercises = [
        ...incoming.history,
        if (incoming.activeWorkout != null) incoming.activeWorkout!,
      ].fold(0, (sum, w) => sum + w.exercises.length),
      sets =
          [
            ...incoming.history,
            if (incoming.activeWorkout != null) incoming.activeWorkout!,
          ].fold(
            0,
            (sum, w) =>
                sum + w.exercises.fold<int>(0, (n, e) => n + e.sets.length),
          ),
      bodyWeights = incoming.bodyWeights.length,
      existingWorkouts = incoming.history
          .where(
            (w) =>
                current.history.any((existing) => existing.id == w.id) ||
                current.activeWorkout?.id == w.id,
          )
          .length,
      draftMessage = incoming.activeWorkout == null
          ? 'Your current active workout stays unchanged.'
          : current.activeWorkout != null
          ? 'Your current active workout is kept. The backup draft is skipped.'
          : current.history.any((w) => w.id == incoming.activeWorkout!.id)
          ? 'The backup draft already exists in history and will be skipped.'
          : 'The backup’s active workout will be restored.';
  final int workouts;
  final int exercises;
  final int sets;
  final int bodyWeights;
  final int existingWorkouts;
  final String draftMessage;
}

class DataTransferController extends GetxController {
  DataTransferController({
    required this.workouts,
    DataTransferFileService? files,
  }) : _files = files ?? NativeDataTransferFileService();
  final WorkoutController workouts;
  final DataTransferFileService _files;
  final busy = false.obs;
  final status = ''.obs;
  final hasError = false.obs;
  final _codec = CsvBackupCodec();

  Future<void> downloadWorkoutCsv() => _save(backup: false);
  Future<void> exportBackup() => _save(backup: true);

  Future<void> _save({required bool backup}) async {
    if (busy.value) return;
    busy.value = true;
    hasError.value = false;
    status.value = 'Preparing your CSV…';
    try {
      await workouts.waitForPendingWrites();
      final data = workouts.data.value;
      final csv = backup
          ? _codec.encode(data)
          : WorkoutCsvExporter().encode(data);
      final date = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      final uri = await _files.save(
        fileName: 'dumbbell-${backup ? 'backup' : 'workouts'}-$date.csv',
        bytes: Uint8List.fromList(utf8.encode(csv)),
        mimeType: 'text/csv',
      );
      status.value = uri == null
          ? 'Save canceled. Your records are unchanged.'
          : '${backup ? 'Backup CSV' : 'Workout CSV'} saved to your chosen location.';
    } on FormatException catch (error) {
      _error(error.message);
    } catch (_) {
      _error(
        'Could not save your CSV. Check the location and available space, then try again.',
      );
    } finally {
      busy.value = false;
    }
  }

  Future<void> importBackup(
    Future<bool> Function(BackupImportSummary summary) confirm,
  ) async {
    if (busy.value) return;
    busy.value = true;
    hasError.value = false;
    status.value = 'Choose your backup CSV…';
    try {
      final bytes = await _files.pickBackup();
      if (bytes == null) {
        status.value = 'Import canceled. Your records are unchanged.';
        return;
      }
      if (bytes.length > CsvBackupCodec.maxBytes) {
        throw const FormatException(
          'Choose a Dumbbell backup smaller than 8 MiB.',
        );
      }
      final imported = _codec.decode(utf8.decode(bytes));
      // Validate the complete file before asking for any merge approval.
      await workouts.waitForPendingWrites();
      final summary = BackupImportSummary(imported, workouts.data.value);
      status.value = 'Backup checked. Review the import summary.';
      if (!await confirm(summary)) {
        status.value = 'Import canceled. Your records are unchanged.';
        return;
      }
      final saved = await workouts.importData(imported);
      if (!saved) {
        _error(
          'Could not import this backup. Your previous records are safe. ${workouts.error.value}',
        );
        return;
      }
      status.value = 'Backup imported. Existing records, preferences and profile were kept.';
    } on FormatException catch (error) {
      _error(error.message);
    } catch (_) {
      _error(
        'Could not read this backup. Choose a Dumbbell Backup CSV and try again.',
      );
    } finally {
      busy.value = false;
    }
  }

  void _error(String message) {
    hasError.value = true;
    status.value = message;
  }
}
