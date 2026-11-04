import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/safety/safety_models.dart';
import '../../services/safety_controller.dart';
import '../../services/preferences_controller.dart';
import '../../widgets/components.dart';
import '../../widgets/preferences_components.dart';

import 'package:url_launcher/url_launcher.dart';

class SafetyScreen extends StatelessWidget {
  const SafetyScreen({
    super.key,
    required this.safety,
    required this.preferences,
  });
  final SafetyController safety;
  final PreferencesController preferences;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([safety, preferences]),
    builder: (context, _) {
      final settings = preferences.data.settings;
      return Scaffold(
        appBar: AppBar(title: const Text('Safety Center')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: StatusPill('ACTIVE SAFETY DISPATCH'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Smart Footwear Safety Center',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              'Automated fall response and emergency dispatch. When a fall is confirmed, your live GPS location is retrieved via Geolocator, dispatched via SMS to all emergency contacts, and an automated phone call is placed to Contact #1.',
              style: TextStyle(height: 1.6),
            ),
            const SizedBox(height: 20),
            PreferencesGate(
              controller: preferences,
              child: Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeading('Choose a practice'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Test alert'),
                          selected: settings.testAlertMode,
                          onSelected: preferences.editable && !safety.active
                              ? (_) => preferences.setSettings(
                                  settings.copyWith(testAlertMode: true),
                                )
                              : null,
                        ),
                        ChoiceChip(
                          label: const Text('Fall event'),
                          selected: !settings.testAlertMode,
                          onSelected: preferences.editable && !safety.active
                              ? (_) => preferences.setSettings(
                                  settings.copyWith(testAlertMode: false),
                                )
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      settings.testAlertMode
                          ? 'Test mode creates an immediate local receipt, without a countdown or delivery.'
                          : 'Fall mode starts a confirmation countdown. Cancelling stops this practice event.',
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${preferences.data.contacts.where((c) => c.included).length} contact(s) included · ${settings.countdownSeconds} s fall countdown',
                    ),
                    const Text(
                      'The recipient count is frozen at the start. Contact changes apply to the next practice.',
                      style: TextStyle(fontSize: 11),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: safety.canStart
                          ? settings.testAlertMode
                                ? safety.startTest
                                : safety.startFall
                          : null,
                      icon: const Icon(Icons.shield_outlined),
                      label: Text(
                        settings.testAlertMode
                            ? 'Start test alert'
                            : 'Simulate fall event',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Practice · ${safety.phase.name}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (safety.phase == SafetyPhase.countdown) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        '${safety.remainingSeconds} seconds',
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    LinearProgressIndicator(
                      value: safety.initialSeconds == 0
                          ? 0
                          : safety.remainingSeconds / safety.initialSeconds,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Are you okay? This is a simulated confirmation check.',
                    ),
                  ],
                  if (safety.phase == SafetyPhase.previewing)
                    const LinearProgressIndicator(),
                  Text(safety.message, style: const TextStyle(height: 1.6)),
                  if (safety.lastDispatch != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withAlpha(80)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.location_on, color: Colors.redAccent, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Emergency GPS Dispatched',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (safety.lastDispatch!.latitude != null)
                            Text(
                              'Coordinates: ${safety.lastDispatch!.latitude!.toStringAsFixed(6)}, ${safety.lastDispatch!.longitude!.toStringAsFixed(6)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          if (safety.lastDispatch!.callRecipient != null)
                            Text(
                              'Phone Call Placed To: ${safety.lastDispatch!.callRecipient}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: () => launchUrl(
                              Uri.parse(safety.lastDispatch!.googleMapsUrl),
                              mode: LaunchMode.externalApplication,
                            ),
                            icon: const Icon(Icons.map, size: 16),
                            label: const Text('Open GPS Location in Google Maps'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (safety.active)
                    FilledButton.tonalIcon(
                      onPressed: () {
                        safety.cancel();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Alert cancelled. I’m okay.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel alert · I’m okay'),
                    )
                  else if (safety.phase != SafetyPhase.idle)
                    TextButton(
                      onPressed: safety.reset,
                      child: const Text('Reset safety status'),
                    ),
                  if (safety.notificationPreview != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        safety.notificationPreview!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.push('/contacts'),
                  icon: const Icon(Icons.people_outline),
                  label: const Text('Emergency contacts'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push('/notifications'),
                  icon: const Icon(Icons.notifications_none),
                  label: const Text('Notification preferences'),
                ),
                TextButton(
                  onPressed: () => context.push('/settings'),
                  child: const Text('App settings'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const PermissionFacts(),
            const SizedBox(height: 24),
            const SectionHeading('This visit’s practice log'),
            if (safety.events.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('No safety practice events yet.'),
              ),
            ...safety.events
                .take(5)
                .map(
                  (e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history),
                    title: Text(
                      '${e.kind == SafetyEventKind.testAlert ? 'Test alert' : 'Fall simulation'} · ${e.phase.name}',
                    ),
                    subtitle: Text(
                      '${e.at.toLocal().toString().substring(0, 19)} · Smart Footwear',
                    ),
                  ),
                ),
            const Text(
              'Practice log stays in memory for this visit (latest 20 transitions). No real incident or dispatch is recorded.',
              style: TextStyle(fontSize: 11, height: 1.5),
            ),
          ],
        ),
      );
    },
  );
}

class SafetyActivityBanner extends StatelessWidget {
  const SafetyActivityBanner({
    super.key,
    required this.safety,
    required this.child,
    required this.onOpen,
  });
  final SafetyController safety;
  final Widget child;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: safety,
    builder: (context, _) => Column(
      children: [
        if (safety.active)
          Material(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        safety.phase == SafetyPhase.countdown
                            ? 'Fall check-in · ${safety.remainingSeconds} s'
                            : 'Emergency dispatch in progress',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onTertiaryContainer,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(onPressed: onOpen, child: const Text('View')),
                    TextButton(
                      onPressed: safety.cancel,
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: child),
      ],
    ),
  );
}
