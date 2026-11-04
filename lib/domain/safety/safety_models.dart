enum SafetyPhase {
  idle,
  countdown,
  previewing,
  completed,
  cancelled,
  blocked,
  error,
}

enum SafetyEventKind { fallSimulation, testAlert }

/// The request intentionally contains no phone numbers, names or delivery URL.
class EmergencyPreviewRequest {
  const EmergencyPreviewRequest({
    required this.eventId,
    required this.kind,
    required this.recipientCount,
  });
  final String eventId;
  final SafetyEventKind kind;
  final int recipientCount;
}

class EmergencyPreviewReceipt {
  const EmergencyPreviewReceipt(this.recipientCount);
  final int recipientCount;
  String get description =>
      'SIMULATED ONLY · $recipientCount recipient preview(s). No message, call or emergency request was sent.';
}

/// Preview-only boundary. It has no send method and accepts no recipient address.
/// A future real integration must be a separate, explicitly configured and tested
/// module with consent, verified delivery and OS permissions. It cannot be enabled
/// by any preference in this app. Never attach real delivery to this preview port.
abstract interface class EmergencyPreviewPort {
  Future<EmergencyPreviewReceipt> preview(EmergencyPreviewRequest request);
}

class LocalEmergencyPreview implements EmergencyPreviewPort {
  @override
  Future<EmergencyPreviewReceipt> preview(
    EmergencyPreviewRequest request,
  ) async => EmergencyPreviewReceipt(request.recipientCount);
}

abstract final class IntegrationCapabilities {
  static const realEmergencyDelivery = false;
  static const automaticFallDetection = false;
  static const bluetooth = false;
  static const hardwareHaptics = false;
  static const osNotifications = false;
}

class SafetyPracticeEvent {
  const SafetyPracticeEvent(this.kind, this.phase, this.at, this.message);
  final SafetyEventKind kind;
  final SafetyPhase phase;
  final DateTime at;
  final String message;
}
