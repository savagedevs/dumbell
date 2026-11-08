import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/workout_controller.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'data_transfer_controller.dart';
import 'data_transfer_file_service.dart';

class DataTransferCard extends StatefulWidget {
  const DataTransferCard({super.key, this.files, this.workouts});
  final DataTransferFileService? files;
  final WorkoutController? workouts;

  @override
  State<DataTransferCard> createState() => _DataTransferCardState();
}

class _DataTransferCardState extends State<DataTransferCard> {
  late final DataTransferController _controller;
  @override
  void initState() {
    super.initState();
    _controller = DataTransferController(
      workouts: widget.workouts ?? Get.find<WorkoutController>(),
      files: widget.files,
    );
  }

  @override
  void dispose() {
    _controller.onClose();
    super.dispose();
  }

  Future<bool> _confirm(BackupImportSummary summary) async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Import this backup?'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${summary.workouts} saved workouts\n${summary.exercises} exercises · ${summary.sets} sets\n${summary.bodyWeights} body-weight entries',
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${summary.existingWorkouts} workout IDs already exist. Existing IDs are kept; new records are merged.',
                  ),
                  const SizedBox(height: 14),
                  Text(summary.draftMessage),
                  const SizedBox(height: 14),
                  const Text(
                    'Your units, profile and preferences stay unchanged. Photos are not included.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Merge backup'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) => AppCard(
    child: Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.download_rounded, color: AppColors.lime),
          const SizedBox(height: 12),
          Text(
            'Your training, to keep',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'A readable log grouped by workout and date, with exercises, sets, weights and reps. Uses your chosen weight units and local start times.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _controller.busy.value
                ? null
                : _controller.downloadWorkoutCsv,
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('Download workout CSV'),
          ),
          const SizedBox(height: 22),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            'Backup & restore',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Use a Backup CSV to restore Dumbbell records, including empty workouts and an active draft. Import checks the file and asks before merging. Photos and profile are not included.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _controller.busy.value
                    ? null
                    : _controller.exportBackup,
                icon: const Icon(Icons.save_alt_rounded),
                label: const Text('Backup CSV'),
              ),
              OutlinedButton.icon(
                onPressed: _controller.busy.value
                    ? null
                    : () => _controller.importBackup(_confirm),
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Import backup'),
              ),
            ],
          ),
          if (_controller.busy.value) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (_controller.status.value.isNotEmpty) ...[
            const SizedBox(height: 14),
            Semantics(
              liveRegion: true,
              child: Text(
                _controller.status.value,
                style: TextStyle(
                  color: _controller.hasError.value
                      ? Theme.of(context).colorScheme.error
                      : AppColors.muted,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
