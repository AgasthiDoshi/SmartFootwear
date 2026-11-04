enum DemoConnectionPhase { demo, connecting, connected, disconnected, error }

enum HapticPattern { gentleDouble, attentionTriple, longPulse }

extension HapticPatternDefinition on HapticPattern {
  String get label => switch (this) {
    HapticPattern.gentleDouble => 'Gentle double',
    HapticPattern.attentionTriple => 'Attention triple',
    HapticPattern.longPulse => 'Long pulse',
  };
  Map<String, Object> get command => {
    'mode': 'preview_only',
    'pattern': name,
    'pulses': switch (this) {
      HapticPattern.gentleDouble => 2,
      HapticPattern.attentionTriple => 3,
      HapticPattern.longPulse => 1,
    },
    'on_ms': this == HapticPattern.longPulse ? 500 : 150,
    'off_ms': 150,
    'intensity_percent': this == HapticPattern.attentionTriple ? 60 : 40,
  };
}

class HapticPreviewReceipt {
  const HapticPreviewReceipt(this.command);
  final Map<String, Object> command;
}

/// Future hardware commands belong in a separate adapter with verified device
/// capabilities and real OS permission checks. This port only renders a command.
abstract interface class HapticPreviewPort {
  Future<HapticPreviewReceipt> preview(HapticPattern pattern);
}

class LocalHapticPreview implements HapticPreviewPort {
  @override
  Future<HapticPreviewReceipt> preview(HapticPattern pattern) async =>
      HapticPreviewReceipt(Map.unmodifiable(pattern.command));
}
