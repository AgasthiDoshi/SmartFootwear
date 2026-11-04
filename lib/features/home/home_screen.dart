import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_controller.dart';
import '../../core/theme.dart';
import '../../domain/demo_repository.dart';
import '../../widgets/components.dart';
import '../../widgets/smart_footwear_telemetry_card.dart';
import '../../widgets/smart_footwear_map_card.dart';
import 'weekly_chart.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});
  final AppController controller;

  String _currentDayFormatted() {
    final now = DateTime.now();
    const months = [
      'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
      'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'
    ];
    const days = [
      'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'
    ];
    final dayName = days[now.weekday - 1];
    final monthName = months[now.month - 1];
    return '$dayName · ${now.day} $monthName ${now.year}';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => _build(context),
  );
  Widget _build(BuildContext context) {
    final data = controller.dashboardData;
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _currentDayFormatted(),
                  style: const TextStyle(letterSpacing: 1.8, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Open profile',
                onPressed: () => context.go('/profile'),
                icon: const CircleAvatar(
                  radius: 19,
                  child: Icon(Icons.person_outline),
                ),
              ),
            ],
          ),
          const Text(
            'A little better,\nevery day.',
            style: TextStyle(
              fontSize: 36,
              height: 1.12,
              letterSpacing: -1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Make room for a moment of movement.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 18),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              const StatusPill('SMART FOOTWEAR ACTIVE'),
              TextButton.icon(
                onPressed: () => context.push('/devices'),
                icon: const Icon(Icons.sensors, size: 16),
                label: Text(
                  controller.device == DeviceState.disconnected
                      ? 'Disconnected'
                      : (controller.adminReadings.value.adjusted ? 'Hardware Live' : 'Connected'),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => context.push('/navigation'),
                icon: const Icon(Icons.navigation_outlined, size: 16),
                label: const Text('Navigation & Haptics'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (controller.state == PreviewState.loading)
            Surface(
              child: Column(
                children: [
                  const LinearProgressIndicator(),
                  const SizedBox(height: 20),
                  const Text('Preparing your movement story…'),
                  TextButton(
                    onPressed: controller.refresh,
                    child: const Text('Reload demo'),
                  ),
                ],
              ),
            ),
          if (controller.state == PreviewState.error)
            StatePanel(
              icon: Icons.cloud_off_rounded,
              title: 'A small pause',
              message:
                  'Your movement summary could not load. Try again to restore the local demo.',
              action: 'Try again',
              onAction: controller.refresh,
            ),
          if (controller.state == PreviewState.empty)
            StatePanel(
              icon: Icons.route,
              title: 'Your first step starts here',
              message:
                  'No recorded sessions yet. Start walking or explore walking activities to see your movement story.',
              action: 'Explore walks',
              onAction: controller.refresh,
            ),
          if (controller.state == PreviewState.ready && data != null) ...[
            Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DAILY MOVEMENT SUMMARY',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${data.steps}',
                              style: const TextStyle(
                                fontSize: 52,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -2,
                              ),
                            ),
                            Text(
                              'of ${data.goal} steps',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '${(data.goal - data.steps).clamp(0, data.goal)} steps to go',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 88,
                        height: 88,
                        child: Semantics(
                          label:
                              'Daily goal ${(data.progress * 100).round()}% complete',
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox.expand(
                                child: CircularProgressIndicator(
                                  value: data.progress,
                                  strokeWidth: 8,
                                  strokeCap: StrokeCap.round,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: .1),
                                ),
                              ),
                              const Icon(
                                Icons.directions_walk_rounded,
                                size: 38,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          '—',
                          'distance unavailable',
                          Icons.route,
                          StrideColors.blue,
                        ),
                      ),
                      Expanded(
                        child: _Metric(
                          '56',
                          'active min',
                          Icons.timer_outlined,
                          StrideColors.lavender,
                        ),
                      ),
                      Expanded(
                        child: _Metric(
                          '2',
                          'walks',
                          Icons.insights,
                          StrideColors.mint,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.push('/gait'),
                    child: const Text('Understand your gait →'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            SmartFootwearTelemetryCard(controller: controller),
            const SizedBox(height: 26),
            const SmartFootwearMapCard(),
            const SizedBox(height: 26),
            const SectionHeading('Weekly rhythm'),
            const SizedBox(height: 14),
            WeeklyChart(currentSteps: data.steps),
            const SizedBox(height: 26),
            Surface(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'YOUR COACH',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.3,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Understand your movement.',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ask about your saved recordings and the calculations behind them. The Coach will tell you when data is missing.',
                    style: TextStyle(
                      height: 1.5,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => context.go('/coach'),
                    child: const Text('Meet your AI coach →'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SectionHeading(
              'Recorded walks',
              action: 'View all',
              onTap: () => context.push('/history'),
            ),
            ...data.sessions.map(
              (s) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.directions_walk)),
                title: Text(s.title),
                subtitle: Text('${s.date} · ${s.minutes} min'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () => context.push('/session/${s.id}'),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.go('/live'),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start live tracking walk'),
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'Smart Footwear · Movement insights and gait intelligence.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, height: 1.6),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.value, this.label, this.icon, this.color);
  final String value, label;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        icon,
        color: Theme.of(context).brightness == Brightness.dark
            ? color
            : Theme.of(context).colorScheme.primary,
        size: 19,
      ),
      const SizedBox(height: 8),
      Text(
        value,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
      ),
      Text(label, style: const TextStyle(fontSize: 11)),
    ],
  );
}
