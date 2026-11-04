import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/progress.dart';
import '../../services/progress_controller.dart';
import '../../services/studio_controller.dart';
import '../../widgets/components.dart';

class QuestsScreen extends StatelessWidget {
  const QuestsScreen({super.key, required this.progress, required this.studio});
  final ProgressController progress;
  final StudioController studio;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([progress, studio]),
    builder: (context, _) {
      final quest = progress.quest;
      final historyReady =
          !studio.historyLoading && studio.historyError == null;
      final canJoin =
          progress.editable &&
          historyReady &&
          studio.phase == SessionPhase.idle;
      final completed = quest != null && quest.progress(studio.sessions) >= 1;
      return Scaffold(
        appBar: AppBar(title: const Text('Quest Mode')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: StatusPill('LOCAL DEMO QUESTS'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'A small adventure,\none walk at a time.',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Join a quest, then record and save walks in the Sensor Studio. Only recordings begun after joining count. Existing and bundled walks are excluded.',
                ),
                const SizedBox(height: 24),
                if (progress.loading || studio.historyLoading)
                  const LinearProgressIndicator()
                else if (progress.loadError != null)
                  StatePanel(
                    icon: Icons.error_outline,
                    title: 'Quest unavailable',
                    message: progress.loadError!,
                    action: 'Retry preferences',
                    onAction: progress.load,
                  )
                else if (studio.historyError != null)
                  StatePanel(
                    icon: Icons.error_outline,
                    title: 'History unavailable',
                    message: studio.historyError!,
                    action: 'Retry history',
                    onAction: studio.loadHistory,
                  )
                else if (quest != null)
                  Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          completed
                              ? Icons.emoji_events_outlined
                              : Icons.explore_outlined,
                          size: 44,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          quest.kind.title,
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(quest.kind.description),
                        const SizedBox(height: 20),
                        Text(
                          completed ? 'Quest complete' : 'Quest in progress',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: quest.progress(studio.sessions),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${quest.displayValue(studio.sessions)} / ${quest.displayTarget} ${quest.kind.unit}',
                        ),
                        Text(
                          'Joined ${quest.joinedAt.toLocal().toString().substring(0, 16)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: () => context.go('/live'),
                          child: const Text('Open Sensor Studio'),
                        ),
                        TextButton(
                          onPressed: !progress.editable
                              ? null
                              : () async {
                                  final leave = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(
                                        completed
                                            ? 'Choose a new quest?'
                                            : 'Leave this quest?',
                                      ),
                                      content: const Text(
                                        'Your saved recordings stay in history. A new quest starts counting from when you join it.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Keep quest'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Leave quest'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (leave == true) {
                                    await progress.leaveQuest();
                                  }
                                },
                          child: Text(
                            completed ? 'Choose another quest' : 'Leave quest',
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...QuestKind.values.map(
                    (kind) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Surface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kind.title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(kind.description),
                            const SizedBox(height: 14),
                            FilledButton(
                              onPressed: canJoin
                                  ? () => progress.join(kind, studio.sessions)
                                  : null,
                              child: const Text('Join quest'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (studio.sessionActive && quest == null)
                  const Text(
                    'Finish the current recording before joining a quest.',
                  ),
                if (progress.saveError != null)
                  Text(
                    progress.saveError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 20),
                const Text(
                  'Progress is recalculated from retained recordings. Deleting or aging recordings out of the 100-session limit can reduce progress. Enrollment is saved locally; there are no medical claims or real-world rewards.',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
