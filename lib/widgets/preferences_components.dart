import 'package:flutter/material.dart';
import '../services/preferences_controller.dart';
import '../domain/app_preferences.dart';
import 'components.dart';

class PreferencesGate extends StatelessWidget {
  const PreferencesGate({
    super.key,
    required this.controller,
    required this.child,
  });
  final PreferencesController controller;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (controller.loading) {
      return const Surface(
        child: Column(
          children: [
            LinearProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading local preferences…'),
          ],
        ),
      );
    }
    if (controller.loadError != null) {
      return StatePanel(
        icon: Icons.error_outline,
        title: 'Local preferences unavailable',
        message: controller.loadError!,
        action: 'Retry preferences',
        onAction: controller.load,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        child,
        if (controller.saveError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              controller.saveError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}

class PermissionPreviewPicker extends StatelessWidget {
  const PermissionPreviewPicker({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.enabled,
  });
  final String label;
  final PermissionPreview value;
  final ValueChanged<PermissionPreview> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      helperText: 'Demo only; OS status is not queried or changed.',
      helperMaxLines: 2,
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<PermissionPreview>(
        value: value,
        isExpanded: true,
        items: PermissionPreview.values
            .map(
              (p) => DropdownMenuItem(
                value: p,
                child: Text('${p.label} (preview)'),
              ),
            )
            .toList(),
        onChanged: enabled
            ? (p) {
                if (p != null) {
                  onChanged(p);
                }
              }
            : null,
      ),
    ),
  );
}

class PermissionFacts extends StatelessWidget {
  const PermissionFacts({super.key});
  @override
  Widget build(BuildContext context) => const Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Real permission status',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 12),
        Text(
          'Notifications and nearby devices: OS status is not queried; STRIDE does not request these permissions in this build.\n\nAddress book, phone/SMS and location: not requested or used. Contacts are entered manually. Preview choices simulate future permission flows; “Allowed” does not grant a real OS permission.\n\nReal fall detection, emergency delivery, system notifications and hardware vibration are unavailable.',
          style: TextStyle(fontSize: 12, height: 1.6),
        ),
      ],
    ),
  );
}
