import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const supportEmail = String.fromEnvironment(
  'SUPPORT_EMAIL',
  defaultValue: 'svgcarol@gmail.com',
);

String get privacyContact => supportEmail.trim().isEmpty
    ? 'For support and privacy questions, use the developer contact provided with your Dumbbell download or on its official store page.'
    : 'For support and privacy questions about Dumbbell, contact $supportEmail.';

class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  late final Future<String> _policy = rootBundle
      .loadString('assets/legal/privacy-policy.md')
      .then((text) => text.replaceAll('{{CONTACT}}', privacyContact));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacy policy')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: FutureBuilder<String>(
            future: _policy,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Privacy information could not be opened. Please reopen this screen.',
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: SelectableText.rich(
                  TextSpan(
                    children: snapshot.data!.split('\n\n').map((paragraph) {
                      final title = paragraph.startsWith('# ');
                      final heading = paragraph.startsWith('## ');
                      return TextSpan(
                        text:
                            '${paragraph.replaceFirst(RegExp(r'^#{1,2} '), '')}\n\n',
                        style: title || heading
                            ? TextStyle(
                                fontSize: title ? 26 : 18,
                                fontWeight: FontWeight.w700,
                              )
                            : null,
                      );
                    }).toList(),
                  ),
                  style: const TextStyle(height: 1.6),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}
