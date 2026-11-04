import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/coach_controller.dart';
import '../../domain/coach/coach_models.dart';
import '../../widgets/components.dart';
import 'coach_summary_cards.dart';
import 'coach_chat_exchange.dart';

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key, required this.controller});
  final CoachController controller;
  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void toLatest() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || !scroll.hasClients) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      scroll.jumpTo(scroll.position.maxScrollExtent);
    } else {
      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  });
  Future<void> ask(String question, {CoachIntent? intent}) async {
    if (question.trim().isEmpty || widget.controller.busy) {
      return;
    }
    final pending = widget.controller.ask(question, intent: intent);
    input.clear();
    FocusScope.of(context).unfocus();
    toLatest();
    await pending;
    if (mounted) {
      toLatest();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final coach = widget.controller, snapshot = widget.controller.snapshot();
      return Scaffold(
        appBar: AppBar(
          title: const Text('Your movement companion'),
          actions: [
            IconButton(
              tooltip: 'Refresh coach insights',
              onPressed: coach.refresh,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Clear local chat',
              onPressed: coach.exchanges.isEmpty
                  ? null
                  : () async {
                      final clear = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Clear this chat?'),
                          content: const Text(
                            'Only this visit’s messages are removed. Saved recordings and goals stay on this device.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Keep chat'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Clear chat'),
                            ),
                          ],
                        ),
                      );
                      if (clear == true) {
                        coach.clear();
                      }
                    },
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                key: const Key('coach-scroll'),
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: StatusPill('LOCAL · SIMULATED DATA'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Move with\nunderstanding.',
                      style: TextStyle(
                        fontSize: 34,
                        height: 1.12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Focused answers from your saved recordings. No account, key or network service. Movement awareness, not medical advice.',
                      style: TextStyle(height: 1.6, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    if (snapshot.historyState == CoachDataState.loading)
                      const Surface(
                        child: Column(
                          children: [
                            LinearProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Loading saved movement history…'),
                          ],
                        ),
                      )
                    else if (snapshot.historyState == CoachDataState.error)
                      StatePanel(
                        icon: Icons.error_outline,
                        title: 'History unavailable',
                        message:
                            'Unreadable history is not an empty history. Insights are unavailable until it can be loaded.',
                        action: 'Retry history',
                        onAction: coach.studio.loadHistory,
                      ),
                    if (snapshot.historyState == CoachDataState.ready &&
                        snapshot.sessions.isEmpty)
                      Surface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.chat_bubble_outline, size: 30),
                            const SizedBox(height: 12),
                            const Text(
                              'A conversation starts with a saved walk.',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'There are no saved recordings to analyze. Bundled examples and unsaved live readings are never used as your movement history.',
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () => context.go('/live'),
                              child: const Text('Open Sensor Studio'),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    CoachSummaryCards(
                      controller: coach,
                      onAsk: (suggestion) =>
                          ask(suggestion.question, intent: suggestion.intent),
                    ),
                    if (coach.studio.sessionActive)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'Your current session is not included until you stop and save it.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 24),
                    const SectionHeading('Ask about your movement'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: CoachSuggestion.all
                          .map(
                            (suggestion) => ActionChip(
                              avatar: const Icon(Icons.north_east, size: 15),
                              label: Text(suggestion.label),
                              onPressed: coach.busy
                                  ? null
                                  : () => ask(
                                      suggestion.question,
                                      intent: suggestion.intent,
                                    ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Local rules support the topics above. Chat stays in memory for this visit (latest 20 exchanges). New saved data makes older answers require regeneration.',
                      style: TextStyle(fontSize: 11, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    ...coach.exchanges.map(
                      (exchange) => CoachChatExchange(
                        key: ValueKey(exchange.id),
                        exchange: exchange,
                        controller: coach,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: input,
                        minLines: 1,
                        maxLines: 3,
                        maxLength: CoachController.maxQuestionLength,
                        textInputAction: TextInputAction.send,
                        decoration: const InputDecoration(
                          hintText: 'Ask about saved movement…',
                          border: InputBorder.none,
                          counterStyle: TextStyle(fontSize: 10),
                        ),
                        onSubmitted: (question) => ask(question),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder(
                      valueListenable: input,
                      builder: (context, value, _) => IconButton.filled(
                        tooltip: 'Send question',
                        onPressed: coach.busy || value.text.trim().isEmpty
                            ? null
                            : () => ask(value.text),
                        icon: const Icon(Icons.arrow_upward),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
