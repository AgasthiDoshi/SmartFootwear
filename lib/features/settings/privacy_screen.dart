import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_controller.dart';
import '../../widgets/components.dart';
import '../../widgets/preferences_components.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key, required this.app});
  final AppController app;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([app.preferences, app.coach]),
    builder: (context, _) {
      final prefs = app.preferences, settings = app.preferences.data.settings;
      return Scaffold(
        appBar: AppBar(title: const Text('Privacy')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: StatusPill('LOCAL BY DESIGN'),
            ),
            const SizedBox(height: 18),
            const Text(
              'Your data, in your control.',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            PreferencesGate(
              controller: prefs,
              child: Surface(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Mask contact phone numbers'),
                      subtitle: const Text(
                        'Show only the last 3 digits outside the contact editor.',
                      ),
                      value: settings.maskPhones,
                      onChanged: prefs.editable
                          ? (value) => prefs.setSettings(
                              settings.copyWith(maskPhones: value),
                            )
                          : null,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Save replay checkpoints'),
                      subtitle: const Text(
                        'Applies to new recordings. Existing replays are unchanged; current recordings keep their starting choice.',
                      ),
                      value: settings.retainReplay,
                      onChanged: prefs.editable
                          ? (value) => prefs.setSettings(
                              settings.copyWith(retainReplay: value),
                            )
                          : null,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Cloud uploads and remote AI'),
                      subtitle: const Text(
                        'Unavailable. No key, server or upload path is configured.',
                      ),
                      trailing: const Icon(Icons.cloud_off_outlined),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Surface(
              child: Text(
                'Stored on this device\n\nProfile name, manually entered contacts, goals, quest enrollment, preferences, and up to 100 saved simulated recordings are kept in local app preferences. This is not an encrypted contact vault. New recordings retain at most 180 replay checkpoints when enabled. Turning retention off does not delete older recordings.\n\nLocal Coach chat and the latest 20 safety practice transitions stay in memory for this visit. Contact phone numbers are never passed into the emergency preview interface. No calls, SMS, location collection, OS notifications or real haptic commands are made.\n\nMovement CSV export is a separate user-controlled clipboard/share action; contacts are not included.',
                style: TextStyle(fontSize: 12, height: 1.6),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: app.coach.exchanges.isEmpty
                  ? null
                  : () async {
                      final clear = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Clear local Coach chat?'),
                          content: const Text(
                            'Saved recordings and preferences are unchanged.',
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
                        app.coach.clear();
                      }
                    },
              child: const Text('Clear local chat'),
            ),
            OutlinedButton(
              onPressed: prefs.editable && prefs.data.contacts.isNotEmpty
                  ? () async {
                      final clear = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete all stored contacts?'),
                          content: const Text(
                            'This removes contacts from this device only. A practice already started keeps its frozen recipient count; no real delivery is possible.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Keep contacts'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete contacts'),
                            ),
                          ],
                        ),
                      );
                      if (clear == true) {
                        await prefs.clearContacts();
                      }
                    }
                  : null,
              child: const Text('Delete stored contacts'),
            ),
            TextButton(
              onPressed: () => context.push('/history'),
              child: const Text('Manage or export saved recordings'),
            ),
            const SizedBox(height: 20),
            const PermissionFacts(),
          ],
        ),
      );
    },
  );
}
