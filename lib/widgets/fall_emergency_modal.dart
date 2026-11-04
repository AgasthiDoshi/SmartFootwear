import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../domain/safety/safety_models.dart';
import '../services/safety_controller.dart';
import '../services/admin_readings_controller.dart';

class FallEmergencyModal extends StatelessWidget {
  const FallEmergencyModal({
    super.key,
    required this.safety,
    required this.adminReadings,
    required this.child,
  });

  final SafetyController safety;
  final AdminReadingsController adminReadings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([safety, adminReadings]),
      builder: (context, _) {
        final isCountingDown = safety.phase == SafetyPhase.countdown;
        final isDispatching = safety.phase == SafetyPhase.previewing;
        final isCompleted = safety.phase == SafetyPhase.completed && safety.lastDispatch != null;

        // Never show emergency popup while user is actively in Admin mode
        final showModal = (isCountingDown || isDispatching || isCompleted) && !adminReadings.authenticated;

        return Stack(
          children: [
            child,
            if (showModal)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withAlpha(220),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161B26),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: isCountingDown
                                ? Colors.redAccent
                                : (isCompleted ? Colors.greenAccent : Colors.orangeAccent),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isCountingDown
                                  ? Colors.redAccent.withAlpha(100)
                                  : Colors.black87,
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1. Icon Header
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (isCountingDown
                                        ? Colors.red
                                        : (isCompleted ? Colors.green : Colors.orange))
                                    .withAlpha(35),
                              ),
                              child: Icon(
                                isCountingDown
                                    ? Icons.warning_rounded
                                    : (isCompleted
                                        ? Icons.check_circle_rounded
                                        : Icons.phone_forwarded),
                                color: isCountingDown
                                    ? Colors.redAccent
                                    : (isCompleted ? Colors.greenAccent : Colors.orangeAccent),
                                size: 48,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 2. Title & Status
                            Text(
                              isCountingDown
                                  ? 'FALL DETECTED!'
                                  : (isCompleted
                                      ? 'EMERGENCY DISPATCHED'
                                      : 'DISPATCHING ALERT…'),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: isCountingDown
                                    ? Colors.redAccent
                                    : (isCompleted ? Colors.greenAccent : Colors.orangeAccent),
                              ),
                            ),
                            const SizedBox(height: 8),

                            Text(
                              isCountingDown
                                  ? 'Smart Footwear detected an abrupt fall or impact.\nAre you okay?'
                                  : (isCompleted
                                      ? 'Emergency alert and live GPS location have been sent to your emergency contacts.'
                                      : 'Obtaining GPS coordinates via Geolocator…'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.white70),
                            ),

                            const SizedBox(height: 24),

                            // 3. Countdown / Dispatch Content
                            if (isCountingDown) ...[
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 110,
                                    height: 110,
                                    child: CircularProgressIndicator(
                                      value: safety.initialSeconds > 0
                                          ? (safety.remainingSeconds / safety.initialSeconds)
                                          : 0,
                                      strokeWidth: 8,
                                      color: Colors.redAccent,
                                      backgroundColor: Colors.white12,
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                        '${safety.remainingSeconds}',
                                        style: const TextStyle(
                                          fontSize: 38,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const Text(
                                        'SECONDS',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white54,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 28),

                              // Big "I AM SAFE" Button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF00C853),
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () {
                                    safety.cancel(
                                      reason: 'Alert cancelled by user. I am safe.',
                                    );
                                    adminReadings.resetRemoteFallAlert();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Fall alert cancelled: You are safe!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.check_circle, size: 26),
                                  label: const Text(
                                    'I AM SAFE · CANCEL ALERT',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'If you do not press this button before the timer ends, emergency SMS and phone calls will be dispatched automatically.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11, color: Colors.white38),
                              ),
                            ] else if (isDispatching) ...[
                              const CircularProgressIndicator(color: Colors.orangeAccent),
                              const SizedBox(height: 16),
                              const Text(
                                'Sending SMS & Placing Emergency Call…',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ] else if (isCompleted) ...[
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (safety.lastDispatch?.latitude != null) ...[
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on, color: Colors.redAccent, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'GPS: ${safety.lastDispatch!.latitude!.toStringAsFixed(6)}, ${safety.lastDispatch!.longitude!.toStringAsFixed(6)}',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    if (safety.lastDispatch?.callRecipient != null) ...[
                                      Row(
                                        children: [
                                          const Icon(Icons.phone_in_talk, color: Colors.greenAccent, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Call Placed: ${safety.lastDispatch!.callRecipient}',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    if (safety.lastDispatch != null &&
                                        safety.lastDispatch!.smsRecipients.isNotEmpty) ...[
                                      Row(
                                        children: [
                                          const Icon(Icons.message, color: Colors.cyanAccent, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'SMS Sent To: ${safety.lastDispatch!.smsRecipients.join(", ")}',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              if (safety.lastDispatch != null)
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => launchUrl(
                                      Uri.parse(safety.lastDispatch!.googleMapsUrl),
                                      mode: LaunchMode.externalApplication,
                                    ),
                                    icon: const Icon(Icons.map, size: 18),
                                    label: const Text('View Location on Google Maps'),
                                  ),
                                ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: () {
                                    safety.reset();
                                    adminReadings.resetRemoteFallAlert();
                                  },
                                  child: const Text('I am okay now · Dismiss'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
