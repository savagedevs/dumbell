import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/exercise_catalog.dart';

typedef SourceUrlLauncher = Future<bool> Function(Uri url);

const _repDbUrl = 'https://repdb.co';
const _repDbLicenseAsset = 'assets/exercises/licenses/REPDB-FREE-LICENSE.md';

class RepDbCredit extends StatelessWidget {
  const RepDbCredit({super.key, this.onOpenUrl});

  final SourceUrlLauncher? onOpenUrl;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => _openSource(context, Uri.parse(_repDbUrl), onOpenUrl),
    style: TextButton.styleFrom(
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 48),
    ),
    child: const Text('Exercise data by RepDB (repdb.co)'),
  );
}

class ExerciseAttributionView extends StatelessWidget {
  const ExerciseAttributionView({
    super.key,
    required this.exercise,
    this.onOpenUrl,
  });

  final ExerciseDefinition exercise;
  final SourceUrlLauncher? onOpenUrl;

  @override
  Widget build(BuildContext context) {
    final sourceUrl = Uri.parse(
      'https://exercise-dataset.com/exercise/${exercise.sourceId}/',
    );
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Sources & license', style: TextStyle(fontSize: 13)),
      subtitle: const Text('RepDB Free', style: TextStyle(fontSize: 11)),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RepDbCredit(onOpenUrl: onOpenUrl),
              const Text(
                'Exercise text and flat illustrations are from RepDB Free. '
                'The artwork is AI-generated and commissioned by RepDB.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              SelectableText(
                sourceUrl.toString(),
                style: const TextStyle(fontSize: 11),
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => _openSource(context, sourceUrl, onOpenUrl),
                    child: const Text('View source exercise'),
                  ),
                  TextButton(
                    onPressed: () => showRepDbLicense(context),
                    child: const Text('Read license'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> showRepDbLicense(BuildContext context) async {
  String text;
  try {
    text = await rootBundle.loadString(_repDbLicenseAsset);
    if (text.trim().isEmpty) throw const FormatException('Empty license');
  } catch (_) {
    text =
        'The bundled RepDB Free license could not be loaded. '
        'Visit $_repDbUrl for the source and license information.';
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('RepDB Free license'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: SelectableText(text, style: const TextStyle(fontSize: 12)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<void> _openSource(
  BuildContext context,
  Uri url,
  SourceUrlLauncher? onOpenUrl,
) async {
  var opened = false;
  try {
    opened = await (onOpenUrl != null
        ? onOpenUrl(url)
        : launchUrl(url, mode: LaunchMode.externalApplication));
  } catch (_) {
    // A missing browser or unavailable platform handler should leave the app usable.
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text('Could not open $url')));
  }
}
