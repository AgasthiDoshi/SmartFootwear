import 'package:flutter/material.dart';
import '../../domain/app_preferences.dart';
import '../../services/preferences_controller.dart';
import '../../widgets/components.dart';
import '../../widgets/preferences_components.dart';

import '../../services/emergency_dispatch_service.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key, required this.preferences});
  final PreferencesController preferences;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: preferences,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Emergency contacts')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: StatusPill('EMERGENCY CONTACTS · AUTO DISPATCH'),
              ),
              const SizedBox(height: 18),
              const Text(
                'Your trusted contacts.',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                'Add 2 or 3 emergency contacts. When Smart Footwear detects a fall, your live GPS location will be forwarded via SMS to these contacts, and an automated phone call will be placed to Contact #1 (Primary Contact).',
                style: TextStyle(height: 1.6),
              ),
              const SizedBox(height: 20),
              PreferencesGate(
                controller: preferences,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (preferences.data.contacts.isEmpty)
                      const Surface(
                        child: Column(
                          children: [
                            Icon(Icons.people_outline, size: 40),
                            SizedBox(height: 12),
                            Text(
                              'No emergency contacts configured yet',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Add 2 or 3 trusted contacts below so Smart Footwear can alert them in an emergency.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ...preferences.data.contacts.asMap().entries.map((entry) {
                      final index = entry.key;
                      final contact = entry.value;
                      final isPrimary = index == 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Surface(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          contact.name,
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        StatusPill(
                                          isPrimary
                                              ? 'CONTACT #1 · PRIMARY (CALL + SMS)'
                                              : 'CONTACT #${index + 1} · SMS ALERT',
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Call ${contact.name}',
                                    onPressed: () => EmergencyDispatchService.makeCall(
                                      phone: contact.phone,
                                    ),
                                    icon: const Icon(Icons.phone, color: Colors.greenAccent),
                                  ),
                                  IconButton(
                                    tooltip: 'Edit ${contact.name}',
                                    onPressed: preferences.editable
                                        ? () => showContactEditor(
                                            context,
                                            preferences,
                                            contact: contact,
                                          )
                                        : null,
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Remove ${contact.name}',
                                    onPressed: preferences.editable
                                        ? () async {
                                            final remove = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text(
                                                  'Remove this contact?',
                                                ),
                                                content: const Text(
                                                  'This deletes the local contact. No person will be notified.',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          context,
                                                          false,
                                                        ),
                                                    child: const Text(
                                                      'Keep contact',
                                                    ),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          context,
                                                          true,
                                                        ),
                                                    child: const Text(
                                                      'Remove contact',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (remove == true) {
                                              await preferences.deleteContact(
                                                contact.id,
                                              );
                                            }
                                          }
                                        : null,
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                              Text(
                                preferences.data.settings.maskPhones
                                    ? contact.maskedPhone
                                    : contact.phone,
                              ),
                              if (contact.relationship.isNotEmpty)
                                Text(
                                  contact.relationship,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Include in local preview'),
                                value: contact.included,
                                onChanged: preferences.editable
                                    ? (value) => preferences.saveContact(
                                        id: contact.id,
                                        name: contact.name,
                                        phone: contact.phone,
                                        relationship: contact.relationship,
                                        included: value,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed:
                          preferences.editable &&
                              preferences.data.contacts.length < 5
                          ? () => showContactEditor(context, preferences)
                          : null,
                      icon: const Icon(Icons.person_add_alt),
                      label: const Text('Add contact'),
                    ),
                    if (preferences.data.contacts.length >= 5)
                      const Text(
                        'Contact limit reached. Remove one to add another.',
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> showContactEditor(
  BuildContext context,
  PreferencesController preferences, {
  EmergencyContact? contact,
}) => showDialog<void>(
  context: context,
  builder: (context) =>
      _ContactEditor(preferences: preferences, contact: contact),
);

class _ContactEditor extends StatefulWidget {
  const _ContactEditor({required this.preferences, this.contact});
  final PreferencesController preferences;
  final EmergencyContact? contact;
  @override
  State<_ContactEditor> createState() => _ContactEditorState();
}

class _ContactEditorState extends State<_ContactEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.contact?.name ?? '');
  late final phone = TextEditingController(text: widget.contact?.phone ?? '');
  late final relationship = TextEditingController(
    text: widget.contact?.relationship ?? '',
  );
  late bool included = widget.contact?.included ?? true;
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    relationship.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.preferences,
    builder: (context, _) => AlertDialog(
      title: Text(
        widget.contact == null
            ? 'Add emergency contact'
            : 'Edit emergency contact',
      ),
      scrollable: true,
      content: SizedBox(
        width: 460,
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Contact name'),
                maxLength: 60,
                validator: (v) => EmergencyContact.validName(v ?? '')
                    ? null
                    : 'Enter a name from 1 to 60 characters.',
              ),
              TextFormField(
                controller: phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  helperText:
                      '7–15 digits; include country code when appropriate.',
                ),
                keyboardType: TextInputType.phone,
                validator: (v) => EmergencyContact.validPhone(v ?? '')
                    ? null
                    : 'Enter a phone number with 7–15 digits.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: relationship,
                decoration: const InputDecoration(
                  labelText: 'Relationship (optional)',
                ),
                maxLength: 40,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include in Emergency Dispatch'),
                subtitle: const Text('Receives SMS with GPS location and/or calls on fall alert'),
                value: included,
                onChanged: widget.preferences.saving
                    ? null
                    : (value) => setState(() => included = value),
              ),
              const Text(
                'Saved on this device for emergency fall notifications.',
                style: TextStyle(fontSize: 11),
              ),
              if (widget.preferences.saveError != null)
                Text(
                  widget.preferences.saveError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.preferences.saving
              ? null
              : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: widget.preferences.editable
              ? () async {
                  if (!form.currentState!.validate()) {
                    return;
                  }
                  final saved = await widget.preferences.saveContact(
                    id: widget.contact?.id,
                    name: name.text,
                    phone: phone.text,
                    relationship: relationship.text,
                    included: included,
                  );
                  if (saved && context.mounted) {
                    Navigator.pop(context);
                  }
                }
              : null,
          child: Text(widget.preferences.saving ? 'Saving…' : 'Save contact'),
        ),
      ],
    ),
  );
}
