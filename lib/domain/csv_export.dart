import 'session_repository.dart';

String sessionsCsv(List<RecordedSession> sessions) {
  String cell(Object? value) {
    var text = value?.toString() ?? '';
    // Quote CSV syntax and neutralize spreadsheet formulas in textual IDs.
    if (value is String && RegExp(r'^\s*[=+@\-\t\r]').hasMatch(text)) {
      text = "'$text";
    }
    return '"${text.replaceAll('"', '""')}"';
  }

  final rows = <List<Object?>>[
    [
      'session_id',
      'started_at_utc',
      'source',
      'steps',
      'active_seconds',
      'average_contacts_per_min',
      'recent_timing_consistency_0_100',
      'heel_adc_share_percent',
      'forefoot_adc_share_percent',
      'toe_adc_share_percent',
      'calibrated',
      'replay_checkpoints',
    ],
    ...sessions.map(
      (s) => [
        s.id,
        s.startedAt.toUtc().toIso8601String(),
        'simulated',
        s.steps,
        (s.activeMilliseconds / 1000).toStringAsFixed(3),
        s.activeMilliseconds == 0 ? null : s.cadence.toStringAsFixed(3),
        s.consistency?.toStringAsFixed(3),
        ...s.pressureShares.map((v) => v.toStringAsFixed(3)),
        s.calibrated,
        s.replay.length,
      ],
    ),
  ];
  return '${rows.map((row) => row.map(cell).join(',')).join('\r\n')}\r\n';
}
