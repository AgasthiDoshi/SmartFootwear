import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../domain/coach/coach_models.dart';
import '../../services/coach_controller.dart';

class CoachChatExchange extends StatelessWidget {
  const CoachChatExchange({
    super.key,
    required this.exchange,
    required this.controller,
  });
  final CoachExchange exchange;
  final CoachController controller;
  @override
  Widget build(BuildContext context) {
    final response = exchange.response;
    final stale = controller.stale(exchange);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(left: 28, bottom: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  exchange.question,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.provider.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (response != null && !stale)
                      IconButton(
                        tooltip: 'Copy coach response',
                        icon: const Icon(Icons.copy_outlined, size: 18),
                        onPressed: () async {
                          String message;
                          try {
                            await Clipboard.setData(
                              ClipboardData(text: response.text),
                            );
                            message = 'Response copied.';
                          } catch (_) {
                            message = 'Could not copy this response.';
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(message)));
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (exchange.pending)
                  Semantics(
                    liveRegion: true,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text('Preparing an answer from saved data…'),
                        ),
                      ],
                    ),
                  )
                else if (stale) ...[
                  const Text(
                    'Saved app data or the local date changed. This earlier answer is hidden so it is not mistaken for a current observation.',
                  ),
                  TextButton(
                    onPressed: controller.busy
                        ? null
                        : () => controller.regenerate(exchange.id),
                    child: const Text('Regenerate from current data'),
                  ),
                ] else if (exchange.error != null) ...[
                  Text(
                    exchange.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(
                    onPressed: controller.busy
                        ? null
                        : () => controller.regenerate(exchange.id),
                    child: const Text('Retry answer'),
                  ),
                ] else if (response != null) ...[
                  Text(switch (response.kind) {
                    CoachResponseKind.answer => 'SAVED SIMULATED DATA',
                    CoachResponseKind.insufficient => 'NEEDS MORE DATA',
                    CoachResponseKind.unavailable => 'DATA UNAVAILABLE',
                    CoachResponseKind.unsupported => 'OUTSIDE AVAILABLE DATA',
                    CoachResponseKind.boundary => 'NON-MEDICAL SCOPE',
                  }, style: const TextStyle(fontSize: 10, letterSpacing: 1.4)),
                  const SizedBox(height: 10),
                  SelectableText(
                    response.text,
                    style: const TextStyle(height: 1.6, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Snapshot: ${exchange.asOf.toLocal().toString().substring(0, 19)} · local time',
                    style: const TextStyle(fontSize: 10),
                  ),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text(
                      'Why this answer?',
                      style: TextStyle(fontSize: 13),
                    ),
                    children: [
                      for (final evidence in response.evidence)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                evidence.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                evidence.explanation,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.6,
                                ),
                              ),
                              if (evidence.sessionIds.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '${evidence.sessionIds.length} saved source recording(s). Showing up to 5 links.',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                Wrap(
                                  spacing: 8,
                                  children: evidence.sessionIds
                                      .take(5)
                                      .toList()
                                      .asMap()
                                      .entries
                                      .map(
                                        (entry) => ActionChip(
                                          label: Text(
                                            'Recording ${entry.key + 1}',
                                          ),
                                          onPressed: () => context.push(
                                            '/session/${Uri.encodeComponent(entry.value)}',
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
