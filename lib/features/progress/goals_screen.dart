import 'package:flutter/material.dart';
import '../../domain/progress.dart';
import '../../services/progress_controller.dart';
import '../../services/studio_controller.dart';
import '../../widgets/components.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key, required this.progress, required this.studio});
  final ProgressController progress;
  final StudioController studio;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([progress, studio]),
    builder: (context, _) {
      final today = TrendWindow(
        studio.sessions,
        TrendPeriod.daily,
        progress.clock(),
      ).buckets.last.totals;
      return Scaffold(
        appBar: AppBar(title: const Text('Goals & achievements')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: StatusPill('SIMULATED RECORDINGS ONLY'),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Make progress personal.',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Choose your own recording targets. Defaults are examples, not health recommendations. Targets apply to the current local calendar day.',
                ),
                const SizedBox(height: 20),
                if (progress.loading)
                  const LinearProgressIndicator()
                else if (progress.loadError != null)
                  StatePanel(
                    icon: Icons.error_outline,
                    title: 'Preferences unavailable',
                    message: progress.loadError!,
                    action: 'Retry preferences',
                    onAction: progress.load,
                  )
                else ...[
                  _GoalEditor(
                    key: ValueKey(
                      '${progress.goals.dailySteps}-${progress.goals.dailyMinutes}',
                    ),
                    progress: progress,
                  ),
                  const SizedBox(height: 24),
                  if (studio.historyLoading)
                    const LinearProgressIndicator()
                  else if (studio.historyError != null)
                    Text(studio.historyError!)
                  else
                    Surface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeading('Today’s saved progress'),
                          const SizedBox(height: 16),
                          Text(
                            '${today.steps} / ${progress.goals.dailySteps} recorded contacts',
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: (today.steps / progress.goals.dailySteps)
                                .clamp(0, 1)
                                .toDouble(),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            '${today.minutes.toStringAsFixed(1)} / ${progress.goals.dailyMinutes} active minutes',
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: (today.minutes / progress.goals.dailyMinutes)
                                .clamp(0, 1)
                                .toDouble(),
                          ),
                          const SizedBox(height: 12),
                          if (today.sessions == 0)
                            const Text(
                              'No recordings saved today. Your real-world activity is unknown.',
                            ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 26),
                const SectionHeading('Achievements'),
                const SizedBox(height: 8),
                const Text(
                  'Earned from retained recordings. Deleting recordings or the 100-session retention limit can change achievement status.',
                ),
                if (!studio.historyLoading && studio.historyError == null)
                  ...Achievement.evaluate(studio.sessions).map(
                    (a) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        a.unlocked
                            ? Icons.verified_rounded
                            : Icons.lock_outline,
                        color: a.unlocked
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text(a.title),
                      subtitle: Text(a.description),
                      trailing: Text(a.unlocked ? 'Earned' : 'Locked'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _GoalEditor extends StatefulWidget {
  const _GoalEditor({super.key, required this.progress});
  final ProgressController progress;
  @override
  State<_GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<_GoalEditor> {
  final form = GlobalKey<FormState>();
  late final steps = TextEditingController(
    text: '${widget.progress.goals.dailySteps}',
  );
  late final minutes = TextEditingController(
    text: '${widget.progress.goals.dailyMinutes}',
  );
  @override
  void dispose() {
    steps.dispose();
    minutes.dispose();
    super.dispose();
  }

  String? validate(String? value, int max) {
    final number = int.tryParse(value?.trim() ?? '');
    return number == null || number < 1 || number > max
        ? 'Enter a whole number from 1 to $max.'
        : null;
  }

  @override
  Widget build(BuildContext context) => Surface(
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: steps,
            decoration: const InputDecoration(
              labelText: 'Daily recorded contacts',
            ),
            keyboardType: TextInputType.number,
            validator: (v) => validate(v, 100000),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: minutes,
            decoration: const InputDecoration(
              labelText: 'Daily active minutes',
            ),
            keyboardType: TextInputType.number,
            validator: (v) => validate(v, 1440),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: !widget.progress.editable
                ? null
                : () async {
                    if (!form.currentState!.validate()) {
                      return;
                    }
                    final saved = await widget.progress.setGoals(
                      PersonalGoals(
                        dailySteps: int.parse(steps.text.trim()),
                        dailyMinutes: int.parse(minutes.text.trim()),
                      ),
                    );
                    if (!context.mounted) {
                      return;
                    }
                    if (saved) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Personal goals saved on this device.'),
                        ),
                      );
                    }
                  },
            child: Text(widget.progress.saving ? 'Saving…' : 'Save goals'),
          ),
          if (widget.progress.saveError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                widget.progress.saveError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
  );
}
