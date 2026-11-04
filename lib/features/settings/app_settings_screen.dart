import 'package:flutter/material.dart';
import '../../core/app_controller.dart';
import '../../widgets/components.dart';
import '../../widgets/preferences_components.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key, required this.app});
  final AppController app;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([app, app.preferences, app.safety]),
    builder: (context, _) {
      final prefs = app.preferences, settings = app.preferences.data.settings;
      return Scaffold(
        appBar: AppBar(title: const Text('App settings')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: StatusPill('SMART FOOTWEAR · ACTIVE SYSTEM'),
            ),
            const SizedBox(height: 18),
            Surface(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Light appearance'),
                value: app.themeMode == ThemeMode.light,
                onChanged: app.setLightTheme,
              ),
            ),
            const SizedBox(height: 18),
            if (app.storageError != null)
              Text(
                app.storageError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            PreferencesGate(
              controller: prefs,
              child: Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Reduce motion'),
                      subtitle: const Text(
                        'Reduce insole and chat scrolling animations.',
                      ),
                      value: settings.reduceMotion,
                      onChanged: prefs.editable
                          ? (value) => prefs.setSettings(
                              settings.copyWith(reduceMotion: value),
                            )
                          : null,
                    ),
                    const Divider(),
                    const Text(
                      'Fall confirmation countdown',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    DropdownButton<int>(
                      isExpanded: true,
                      value: settings.countdownSeconds,
                      items: [5, 10, 20]
                          .map(
                            (seconds) => DropdownMenuItem(
                              value: seconds,
                              child: Text('$seconds seconds'),
                            ),
                          )
                          .toList(),
                      onChanged: prefs.editable && !app.safety.active
                          ? (value) {
                              if (value != null) {
                                prefs.setSettings(
                                  settings.copyWith(countdownSeconds: value),
                                );
                              }
                            }
                          : null,
                    ),
                    const Text(
                      'Affects the next manually simulated fall event. Active countdown settings are locked.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 18),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Test-alert mode'),
                      subtitle: const Text(
                        'Choose immediate test previews instead of a fall countdown.',
                      ),
                      value: settings.testAlertMode,
                      onChanged: prefs.editable && !app.safety.active
                          ? (value) => prefs.setSettings(
                              settings.copyWith(testAlertMode: value),
                            )
                          : null,
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton(
                      onPressed: prefs.editable && !app.safety.active
                          ? () async {
                              final reset = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text(
                                    'Reset safety and privacy preferences?',
                                  ),
                                  content: const Text(
                                    'Restore default preview permissions, countdown, notification choices, replay retention and motion settings. Contacts, profile, theme, goals and recordings remain saved.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Keep settings'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Reset preferences'),
                                    ),
                                  ],
                                ),
                              );
                              if (reset == true) {
                                await prefs.resetSettings();
                              }
                            }
                          : null,
                      child: const Text('Reset safety & privacy preferences'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Integration status',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Smart Footwear · System Status\n\n• Emergency Dispatch: GPS Location (Geolocator) + SMS & Automated Calling\n• Navigation: Left & Right Footwear Haptic Motor Guidance with Google Maps\n• Hardware Bridge: ESP32 BLE packet dispatcher ready\n• Firebase Sync: Configured via SmartFootwearFirebaseConfig',
                    style: TextStyle(height: 1.6, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
