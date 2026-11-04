import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/studio_controller.dart';
import '../../services/replay_controller.dart';
import '../../domain/session_repository.dart';
import '../../domain/sensor.dart';
import '../../widgets/components.dart';
import '../live/insole_view.dart';
import 'replay_pressure_chart.dart';

class ReplayScreen extends StatelessWidget {
  const ReplayScreen({super.key, required this.studio, required this.id});
  final StudioController studio;
  final String id;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: studio,
    builder: (context, _) {
      final matches = studio.sessions.where((s) => s.id == id);
      return Scaffold(
        appBar: AppBar(title: const Text('Walk Replay')),
        body: studio.historyLoading
            ? const Center(child: CircularProgressIndicator())
            : studio.historyError != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: StatePanel(
                  icon: Icons.error_outline,
                  title: 'History unavailable',
                  message: studio.historyError!,
                  action: 'Retry history',
                  onAction: studio.loadHistory,
                ),
              )
            : matches.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: StatePanel(
                  icon: Icons.search_off,
                  title: 'Recording unavailable',
                  message: 'This recording is no longer saved on this device.',
                  action: 'View history',
                  onAction: () => context.go('/history'),
                ),
              )
            : matches.first.replay.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: StatePanel(
                  icon: Icons.history_toggle_off,
                  title: 'No replay checkpoints',
                  message:
                      'This older session contains a summary only. Its sensor timeline cannot be reconstructed. New recordings save bounded replay checkpoints.',
                  action: 'Open Sensor Studio',
                  onAction: () => context.go('/live'),
                ),
              )
            : _ReplayContent(key: ValueKey(id), session: matches.first),
      );
    },
  );
}

class _ReplayContent extends StatefulWidget {
  const _ReplayContent({super.key, required this.session});
  final RecordedSession session;
  @override
  State<_ReplayContent> createState() => _ReplayContentState();
}

class _ReplayContentState extends State<_ReplayContent>
    with WidgetsBindingObserver {
  late final replay = ReplayController(widget.session.replay);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      replay.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    replay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: replay,
    builder: (context, _) {
      final point = replay.observation!;
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: StatusPill('SAVED SIMULATED CHECKPOINTS'),
              ),
              const SizedBox(height: 14),
              const Text(
                'Revisit your rhythm.',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                '${widget.session.replay.length} captured observations · ${widget.session.steps} total contacts',
              ),
              const SizedBox(height: 20),
              Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Timeline ${replayTime(replay.position)}',
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Observed at ${replayTime(point.activeMilliseconds)} · ${point.steps} contacts so far',
                    ),
                    Slider(
                      key: const Key('replay-seek'),
                      label: replayTime(replay.position),
                      min: replay.min.toDouble(),
                      max: replay.max == replay.min
                          ? replay.min + 1.0
                          : replay.max.toDouble(),
                      value: replay.position.toDouble(),
                      onChanged: replay.min == replay.max
                          ? null
                          : (v) => replay.seek(v.round()),
                    ),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Previous checkpoint',
                          onPressed: replay.position > replay.min
                              ? () => replay.jump(-1)
                              : null,
                          icon: const Icon(Icons.skip_previous),
                        ),
                        FilledButton.icon(
                          onPressed: replay.min == replay.max
                              ? null
                              : replay.playing
                              ? replay.pause
                              : replay.play,
                          icon: Icon(
                            replay.playing ? Icons.pause : Icons.play_arrow,
                          ),
                          label: Text(
                            replay.playing ? 'Pause replay' : 'Play replay',
                          ),
                        ),
                        IconButton(
                          tooltip: 'Next checkpoint',
                          onPressed: replay.position < replay.max
                              ? () => replay.jump(1)
                              : null,
                          icon: const Icon(Icons.skip_next),
                        ),
                        TextButton(
                          onPressed: () => replay.seek(replay.min),
                          child: const Text('Restart'),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      children: [.5, 1.0, 2.0]
                          .map(
                            (s) => ChoiceChip(
                              label: Text('$s×'),
                              selected: replay.speed == s,
                              onSelected: (_) => replay.setSpeed(s),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    ReplayPressureChart(
                      points: widget.session.replay,
                      position: replay.position,
                    ),
                    const Text(
                      'Heel / forefoot / toe · 0–4095 ADC · active time →',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Surface(
                child: Column(
                  children: [
                    InsoleView(frame: point.frame),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 18,
                      runSpacing: 12,
                      children: [
                        for (var i = 3; i < 9; i++)
                          Text(
                            '${SensorFrame.labels[i]}\n${point.values[i].toStringAsFixed(3)} ${SensorFrame.units[i]}',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Replay uses saved observations rounded to 3 decimals, initially about 0.5 s apart and adaptively thinned to at most 180 points for long walks. The first and final observations are retained. The chart connects checkpoints as a visual guide; peaks between them may be missed.\n\nSeeking shows the nearest earlier observation without inventing intermediate sensor values. The timeline is active recording time only; pauses are omitted. No GPS route or physical location was recorded.',
                style: TextStyle(fontSize: 12, height: 1.6),
              ),
            ],
          ),
        ),
      );
    },
  );
}
