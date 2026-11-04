import 'package:flutter/material.dart';
import '../../services/preferences_controller.dart';
import '../../services/safety_controller.dart';
import '../../widgets/components.dart';
import '../../widgets/preferences_components.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({
    super.key,
    required this.preferences,
    required this.safety,
  });
  final PreferencesController preferences;
  final SafetyController safety;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([preferences, safety]),
    builder: (context, _) {
      final settings = preferences.data.settings;
      return Scaffold(
        appBar: AppBar(title: const Text('Notification preferences')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: StatusPill('IN-APP PREVIEW ONLY'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Choose your practice notices.',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              'These saved preferences control local notice previews. There is no push registration, background reminder schedule, system sound or OS notification in this build.',
            ),
            const SizedBox(height: 20),
            PreferencesGate(
              controller: preferences,
              child: Surface(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Safety preview notices'),
                      value: settings.safetyNotices,
                      onChanged: preferences.editable
                          ? (value) => preferences.setSettings(
                              settings.copyWith(safetyNotices: value),
                            )
                          : null,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Session reminder previews'),
                      value: settings.reminderNotices,
                      onChanged: preferences.editable
                          ? (value) => preferences.setSettings(
                              settings.copyWith(reminderNotices: value),
                            )
                          : null,
                    ),
                    const SizedBox(height: 20),
                    PermissionPreviewPicker(
                      label: 'Notification permission preview',
                      value: settings.notificationPermission,
                      enabled: preferences.editable,
                      onChanged: (value) => preferences.setSettings(
                        settings.copyWith(notificationPermission: value),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: preferences.ready
                              ? () => safety.previewNotification()
                              : null,
                          child: const Text('Preview safety notice'),
                        ),
                        OutlinedButton(
                          onPressed: preferences.ready
                              ? () => safety.previewNotification(reminder: true)
                              : null,
                          child: const Text('Preview reminder'),
                        ),
                      ],
                    ),
                    if (safety.notificationPreview != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Text(
                          safety.notificationPreview!,
                          style: const TextStyle(height: 1.6),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const PermissionFacts(),
          ],
        ),
      );
    },
  );
}
