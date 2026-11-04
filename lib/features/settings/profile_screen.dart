import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_controller.dart';
import '../../domain/demo_repository.dart';
import '../../widgets/components.dart';
import '../../widgets/preferences_components.dart';
import '../../widgets/admin_pin_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.app});
  final AppController app;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _avatarTaps = 0;
  DateTime? _lastAvatarTap;

  void _onAvatarTapped() async {
    final now = DateTime.now();
    if (_lastAvatarTap == null || now.difference(_lastAvatarTap!) > const Duration(seconds: 4)) {
      _avatarTaps = 0;
    }
    _lastAvatarTap = now;
    _avatarTaps++;
    if (_avatarTaps >= 4) {
      _avatarTaps = 0;
      _lastAvatarTap = null;
      final unlocked = await showAdminPinDialog(context);
      if (unlocked && mounted) {
        widget.app.adminReadings.authenticateWithPin();
        context.push('/admin');
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.app, widget.app.preferences]),
    builder: (context, _) {
      final app = widget.app;
      return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: StatusPill('LOCAL PROFILE · NO ACCOUNT'),
              ),
              const SizedBox(height: 20),
              PreferencesGate(
                controller: widget.app.preferences,
                child: Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _onAvatarTapped,
                        child: const CircleAvatar(
                          radius: 28,
                          child: Icon(Icons.person_outline, size: 32),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.app.preferences.data.profile.displayName,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text('A little progress, every day.'),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: app.preferences.editable
                            ? () => showDialog<void>(
                                context: context,
                                builder: (_) => _ProfileEditor(app: app),
                              )
                            : null,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit display name'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Surface(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Light appearance'),
                      value: app.themeMode == ThemeMode.light,
                      onChanged: app.setLightTheme,
                    ),
                    for (final entry in const <String, String>{
                      'Device Hub': '/devices',
                      'Progress & history': '/history',
                      'Goals & achievements': '/goals',
                      'Quest Mode': '/quests',
                      'Emergency contacts': '/contacts',
                      'Privacy': '/privacy',
                      'Notification preferences': '/notifications',
                      'App settings': '/settings',
                    }.entries)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(entry.key),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(entry.value),
                      ),
                  ],
                ),
              ),
              if (app.storageError != null)
                Text(
                  app.storageError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 24),
              const SectionHeading('Dashboard state preview'),
              const Text('Choose a repeatable state, then open Home.'),
              Wrap(
                spacing: 8,
                children: PreviewState.values
                    .map(
                      (state) => ChoiceChip(
                        label: Text(state.name),
                        selected: app.state == state,
                        onSelected: (_) => app.preview(state),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  },
);
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({required this.app});
  final AppController app;
  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(
    text: widget.app.preferences.data.profile.displayName,
  );
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.app.preferences,
    builder: (context, _) => AlertDialog(
      title: const Text('Edit local profile'),
      scrollable: true,
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: name,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'Display name'),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Enter a display name.'
                  : null,
            ),
            const Text(
              'No health, identity or account information is required.',
              style: TextStyle(fontSize: 12),
            ),
            if (widget.app.preferences.saveError != null)
              Text(widget.app.preferences.saveError!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.app.preferences.saving
              ? null
              : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: widget.app.preferences.editable
              ? () async {
                  if (!form.currentState!.validate()) {
                    return;
                  }
                  final saved = await widget.app.preferences.setProfile(
                    name.text,
                  );
                  if (saved && context.mounted) {
                    Navigator.pop(context);
                  }
                }
              : null,
          child: const Text('Save profile'),
        ),
      ],
    ),
  );
}
