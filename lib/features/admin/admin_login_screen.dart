import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/admin_readings.dart';
import '../../domain/sensor.dart';
import '../../services/admin_readings_controller.dart';
import '../../services/admin_security_service.dart';
import '../../widgets/components.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key, required this.controller});

  final AdminReadingsController controller;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _inlinePinController = TextEditingController();
  String? _inlinePinError;
  bool _verifyingPin = false;
  late final TextEditingController _steps;
  late final TextEditingController _goal;
  late final List<TextEditingController> _sensors;
  bool _editing = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final readings = widget.controller.value;
    _steps = TextEditingController(text: '${readings.dashboardSteps}');
    _goal = TextEditingController(text: '${readings.dailyGoal}');
    _sensors = readings.sensorValues
        .map((value) => TextEditingController(text: '$value'))
        .toList();
    widget.controller.restoreAuthentication();
  }

  @override
  void dispose() {
    _inlinePinController.dispose();
    _steps.dispose();
    _goal.dispose();
    for (final sensor in _sensors) {
      sensor.dispose();
    }
    super.dispose();
  }

  Future<void> _verifyInlinePin(AdminReadingsController controller) async {
    final pin = _inlinePinController.text.trim();
    if (pin.length != 4) {
      setState(() => _inlinePinError = 'Enter 4 digits.');
      return;
    }
    setState(() => _verifyingPin = true);
    final isValid = await AdminSecurityService.verifyPin(pin);
    if (!mounted) return;
    setState(() => _verifyingPin = false);
    if (isValid) {
      _inlinePinController.clear();
      setState(() => _inlinePinError = null);
      controller.authenticateWithPin();
    } else {
      setState(() => _inlinePinError = 'Incorrect PIN. Try again.');
      _inlinePinController.clear();
    }
  }

  Future<void> _showChangePinDialog(BuildContext context) async {
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    String? dialogError;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Text('Change Admin 4-Digit PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newPinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New 4-Digit PIN',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New PIN',
                  counterText: '',
                ),
              ),
              if (dialogError != null) ...[
                const SizedBox(height: 8),
                Text(
                  dialogError!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final newPin = newPinController.text.trim();
                final confirmPin = confirmPinController.text.trim();
                if (newPin.length != 4 || int.tryParse(newPin) == null) {
                  setDialogState(() => dialogError = 'PIN must be exactly 4 digits.');
                  return;
                }
                if (newPin != confirmPin) {
                  setDialogState(() => dialogError = 'PINs do not match.');
                  return;
                }
                final success = await AdminSecurityService.setPin(newPin);
                if (success && dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Admin PIN updated successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Save PIN'),
            ),
          ],
        ),
      ),
    );
  }

  void _syncDraft(AdminReadings readings) {
    if (_editing) return;
    _steps.text = '${readings.dashboardSteps}';
    _goal.text = '${readings.dailyGoal}';
    for (var i = 0; i < _sensors.length; i++) {
      _sensors[i].text = '${readings.sensorValues[i]}';
    }
  }

  Future<void> _save() async {
    final steps = int.tryParse(_steps.text.trim());
    final goal = int.tryParse(_goal.text.trim());
    final sensors = _sensors.map((field) => double.tryParse(field.text)).toList();
    if (steps == null ||
        goal == null ||
        sensors.any((value) => value == null)) {
      setState(() {
        _editing = true;
        _validationError = 'Enter a number in every field.';
      });
      return;
    }
    final values = sensors.cast<double>();
    final readings = AdminReadings(
      dashboardSteps: steps,
      dailyGoal: goal,
      sensorValues: values,
    );
    if (!readings.valid) {
      setState(() {
        _editing = true;
        _validationError = 'Enter values within each field’s allowed range.';
      });
      return;
    }
    setState(() => _validationError = null);
    final saved = await widget.controller.save(readings);
    if (saved && mounted) setState(() => _editing = false);
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset shared readings?'),
        content: const Text(
          'Every phone will return to the bundled demo values.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final reset = await widget.controller.reset();
      if (reset) setState(() => _editing = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      _syncDraft(controller.value);
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Console'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Lock & Return to Home',
            onPressed: () {
              AdminSecurityService.lock();
              controller.lockAdminAccess();
              context.go('/home');
            },
          ),
          actions: [
            IconButton(
              onPressed: () {
                AdminSecurityService.lock();
                controller.lockAdminAccess();
                context.go('/home');
              },
              icon: const Icon(Icons.home_rounded),
              tooltip: 'Return to Home',
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    AdminSecurityService.lock();
                    controller.lockAdminAccess();
                    context.go('/home');
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Return to Home Screen'),
                ),
                const SizedBox(height: 16),
                const StatusPill('SHARED SENSOR & FALL CONTROLS'),
                const SizedBox(height: 16),
                const Text(
                  'Reading controls',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Adjustments sync to every phone connected to the configured Firebase project in real time.',
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.redAccent.withAlpha(120), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Cross-Device Fall Trigger',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: StatusPill(
                          controller.value.fallDetected ? 'FALL: ACTIVE (YES)' : 'FALL: NORMAL (NO)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Triggering this broadcasts a Fall Event to all connected phones via Firebase in real time.\nOn this phone and other phones, a 10-second "I AM SAFE" emergency popup will appear immediately. If not cancelled within 10 seconds, SMS with live GPS location and automated phone calls will be dispatched.',
                        style: TextStyle(fontSize: 12, height: 1.5, color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () async {
                                await controller.triggerRemoteFallAlert();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Fall Alert broadcasted! The 10-second timer will start when you return to Home.'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.crisis_alert),
                              label: const Text(
                                'BROADCAST FALL DETECTED (YES)',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (controller.value.fallDetected)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await controller.resetRemoteFallAlert();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Fall Alert reset back to normal.'),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reset Fall Trigger to NO'),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (!controller.configured)
                  Surface(
                    child: Column(
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 40),
                        const SizedBox(height: 12),
                        const Text('Firebase setup required'),
                        const SizedBox(height: 8),
                        Text(
                          controller.unavailableMessage ??
                              'Configure Firebase to enable secure sign-in and cross-device updates.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else if (!controller.authenticated)
                  _loginForm(controller)
                else
                  _readingsEditor(controller),
                if (controller.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    controller.error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                if (_validationError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _validationError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _loginForm(AdminReadingsController controller) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.cyanAccent.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.lock_clock_rounded, color: Colors.cyanAccent),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin PIN Required',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Enter your 4-digit security PIN to unlock',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _inlinePinController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          decoration: InputDecoration(
            labelText: '4-Digit PIN',
            hintText: '••••',
            errorText: _inlinePinError,
            counterText: '',
            prefixIcon: const Icon(Icons.password),
          ),
          onSubmitted: (_) => _verifyInlinePin(controller),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: _verifyingPin ? null : () => _verifyInlinePin(controller),
          icon: _verifyingPin
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lock_open),
          label: const Text('Unlock Admin Access'),
        ),
        const SizedBox(height: 10),
        const Center(
          child: Text(
            'Default PIN: 1234',
            style: TextStyle(fontSize: 11, color: Colors.white38),
          ),
        ),
      ],
    ),
  );

  Widget _readingsEditor(AdminReadingsController controller) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: Colors.cyanAccent, size: 22),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Admin Console Unlocked',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                ),
                onPressed: () => _showChangePinDialog(context),
                icon: const Icon(Icons.pin, size: 16),
                label: const Text('Change PIN', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent.withAlpha(200),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                ),
                onPressed: () {
                  AdminSecurityService.lock();
                  controller.lockAdminAccess();
                  context.go('/home');
                },
                icon: const Icon(Icons.lock, size: 16),
                label: const Text('Lock & Exit', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(),
        const SizedBox(height: 8),
        const SizedBox(height: 12),
        TextField(
          controller: _steps,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Dashboard steps',
            helperText: 'Whole number · 0–1,000,000',
          ),
          onChanged: (_) {
            _editing = true;
            _validationError = null;
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _goal,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Daily step goal',
            helperText: 'Whole number · 1–1,000,000',
          ),
          onChanged: (_) {
            _editing = true;
            _validationError = null;
          },
        ),
        const SizedBox(height: 20),
        const Text(
          'Live simulated sensor channels',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < SensorFrame.labels.length; i++) ...[
          TextField(
            controller: _sensors[i],
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: InputDecoration(
              labelText: '${SensorFrame.labels[i]} (${SensorFrame.units[i]})',
              helperText: _sensorRange(i),
            ),
            onChanged: (_) {
              _editing = true;
              _validationError = null;
            },
          ),
          const SizedBox(height: 10),
        ],
        if (controller.value.adjusted)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: StatusPill('HARDWARE OVERRIDE VALUES ARE LIVE'),
          ),
        FilledButton(
          onPressed: controller.busy ? null : _save,
          child: Text(controller.busy ? 'Publishing…' : 'Publish to all phones'),
        ),
        TextButton(
          onPressed: controller.busy ? null : _reset,
          child: const Text('Reset to default baseline'),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.home),
          label: const Text('Return to User App'),
        ),
      ],
    ),
  );

  String _sensorRange(int index) {
    final limit = SensorFrame.limits[index];
    final minimum = index < 3 ? '0' : '-$limit';
    return 'Allowed: $minimum to $limit';
  }
}
