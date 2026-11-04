import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/app_controller.dart';
import '../../domain/demo_repository.dart';
import '../../domain/safety/device_preview.dart';
import '../../widgets/components.dart';
import '../../widgets/preferences_components.dart';

class DeviceHubScreen extends StatelessWidget {
  const DeviceHubScreen({super.key, required this.app});
  final AppController app;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([app.devices, app.preferences]),
    builder: (context, _) {
      final device = app.devices, prefs = app.preferences;
      return Scaffold(
        appBar: AppBar(title: const Text('Device Hub')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: StatusPill('VIRTUAL INSOLE · NO BLE'),
                ),
                const SizedBox(height: 18),
                Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.sensors, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        device.phase == DemoConnectionPhase.disconnected
                            ? 'No wearable connected'
                            : 'Smart Footwear Connected',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'State: ${device.phase.name}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      Text(device.message, style: const TextStyle(height: 1.5)),
                      if (device.phase == DemoConnectionPhase.connecting)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: LinearProgressIndicator(),
                        ),
                      const SizedBox(height: 18),
                      const Text(
                        'Static UI state previews (no connection attempted)',
                        style: TextStyle(fontSize: 12),
                      ),
                      Wrap(
                        spacing: 8,
                        children: DeviceState.values
                            .map(
                              (state) => ChoiceChip(
                                label: Text(
                                  state == DeviceState.connected
                                      ? 'Connected (simulated)'
                                      : state.name,
                                ),
                                selected:
                                    device.phase !=
                                        DemoConnectionPhase.connecting &&
                                    device.phase != DemoConnectionPhase.error &&
                                    device.legacyState == state,
                                onSelected: (_) => app.setDevice(state),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton(
                            onPressed:
                                device.phase ==
                                        DemoConnectionPhase.connecting ||
                                    !prefs.ready
                                ? null
                                : device.connect,
                            child: const Text('Run connection preview'),
                          ),
                          OutlinedButton(
                            onPressed:
                                device.phase == DemoConnectionPhase.disconnected
                                ? null
                                : device.disconnect,
                            child: Text(
                              device.phase == DemoConnectionPhase.connecting
                                  ? 'Cancel connection'
                                  : 'Disconnect',
                            ),
                          ),
                          TextButton(
                            onPressed: device.simulateError,
                            child: const Text('Simulate connection error'),
                          ),
                        ],
                      ),
                      const Text(
                        'A disconnect pauses any recording. Resume it manually in Live after reconnecting.',
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                PreferencesGate(
                  controller: prefs,
                  child: Surface(
                    child: PermissionPreviewPicker(
                      label: 'Nearby-device permission preview',
                      value: prefs.data.settings.nearbyPermission,
                      enabled:
                          prefs.editable &&
                          device.phase != DemoConnectionPhase.connecting,
                      onChanged: (value) => prefs.setSettings(
                        prefs.data.settings.copyWith(nearbyPermission: value),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeading('Haptic command preview'),
                      const SizedBox(height: 10),
                      const Text(
                        'Generate a local command description. No handset vibration, footwear motor or radio packet is activated.',
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        children: HapticPattern.values
                            .map(
                              (pattern) => ChoiceChip(
                                label: Text(pattern.label),
                                selected: pattern == device.pattern,
                                onSelected: device.hapticBusy
                                    ? null
                                    : (_) => device.setPattern(pattern),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: device.usable && !device.hapticBusy
                            ? device.previewHaptic
                            : null,
                        child: Text(
                          device.hapticBusy
                              ? 'Preparing…'
                              : 'Preview haptic command',
                        ),
                      ),
                      if (!device.usable)
                        const Text(
                          'Choose demo/connected state before previewing a command.',
                        ),
                      if (device.receipt != null) ...[
                        const SizedBox(height: 14),
                        SelectableText(
                          const JsonEncoder.withIndent(
                            '  ',
                          ).convert(device.receipt!.command),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                        const Text(
                          'Preview created locally. No vibration or hardware acknowledgement.',
                          style: TextStyle(fontSize: 11),
                        ),
                      ],
                      if (device.hapticError != null)
                        Text(
                          device.hapticError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const PermissionFacts(),
              ],
            ),
          ),
        ),
      );
    },
  );
}
