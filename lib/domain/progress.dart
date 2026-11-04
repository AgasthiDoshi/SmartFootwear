import 'session_repository.dart';

enum TrendPeriod { daily, weekly, monthly }

enum TrendMetric { steps, activeMinutes }

DateTime localDay(DateTime date) {
  final d = date.toLocal();
  return DateTime(d.year, d.month, d.day);
}

DateTime weekStart(DateTime date) {
  final d = localDay(date);
  return DateTime(d.year, d.month, d.day - d.weekday + 1);
}

String shortDate(DateTime date) => '${date.day}/${date.month}';

class SessionTotals {
  const SessionTotals(this.sessions, this.steps, this.activeMilliseconds);
  factory SessionTotals.from(Iterable<RecordedSession> sessions) {
    var count = 0, steps = 0, ms = 0;
    for (final session in sessions) {
      count++;
      steps += session.steps;
      ms += session.activeMilliseconds;
    }
    return SessionTotals(count, steps, ms);
  }
  final int sessions, steps, activeMilliseconds;
  double get minutes => activeMilliseconds / 60000;
  double? get cadence =>
      activeMilliseconds == 0 ? null : steps * 60000 / activeMilliseconds;
}

class TrendBucket {
  const TrendBucket(this.start, this.end, this.totals);
  final DateTime start, end;
  final SessionTotals totals;
  String get label => shortDate(start);
}

class TrendWindow {
  TrendWindow(
    List<RecordedSession> sessions,
    TrendPeriod period,
    DateTime anchor,
  ) {
    final day = localDay(anchor);
    final count = period == TrendPeriod.daily
        ? 7
        : period == TrendPeriod.weekly
        ? 8
        : 6;
    final base = period == TrendPeriod.weekly
        ? weekStart(day)
        : period == TrendPeriod.monthly
        ? DateTime(day.year, day.month)
        : day;
    for (var i = count - 1; i >= 0; i--) {
      final start = period == TrendPeriod.monthly
          ? DateTime(base.year, base.month - i)
          : DateTime(
              base.year,
              base.month,
              base.day - i * (period == TrendPeriod.weekly ? 7 : 1),
            );
      final end = period == TrendPeriod.monthly
          ? DateTime(start.year, start.month + 1)
          : DateTime(
              start.year,
              start.month,
              start.day + (period == TrendPeriod.weekly ? 7 : 1),
            );
      buckets.add(
        TrendBucket(
          start,
          end,
          SessionTotals.from(
            sessions.where(
              (s) =>
                  !s.startedAt.toLocal().isBefore(start) &&
                  s.startedAt.toLocal().isBefore(end),
            ),
          ),
        ),
      );
    }
  }
  final List<TrendBucket> buckets = [];
  DateTime get start => buckets.first.start;
  DateTime get end => buckets.last.end;
  SessionTotals get totals => SessionTotals(
    buckets.fold(0, (s, b) => s + b.totals.sessions),
    buckets.fold(0, (s, b) => s + b.totals.steps),
    buckets.fold(0, (s, b) => s + b.totals.activeMilliseconds),
  );
}

class PersonalGoals {
  const PersonalGoals({this.dailySteps = 1000, this.dailyMinutes = 10});
  final int dailySteps, dailyMinutes;
  bool get valid =>
      dailySteps >= 1 &&
      dailySteps <= 100000 &&
      dailyMinutes >= 1 &&
      dailyMinutes <= 1440;
  Map<String, Object> toJson() => {
    'steps': dailySteps,
    'minutes': dailyMinutes,
  };
  factory PersonalGoals.fromJson(Map<String, dynamic> json) {
    final goals = PersonalGoals(
      dailySteps: json['steps'] as int,
      dailyMinutes: json['minutes'] as int,
    );
    if (!goals.valid) {
      throw const FormatException('Invalid goals');
    }
    return goals;
  }
}

enum QuestKind { hundredSteps, fiveMinutes, threeWalks }

extension QuestDefinition on QuestKind {
  String get title => switch (this) {
    QuestKind.hundredSteps => 'One hundred little steps',
    QuestKind.fiveMinutes => 'Five minutes for you',
    QuestKind.threeWalks => 'Build a walking ritual',
  };
  String get description => switch (this) {
    QuestKind.hundredSteps => 'Record 100 simulated contacts.',
    QuestKind.fiveMinutes => 'Save 5 active recording minutes.',
    QuestKind.threeWalks => 'Save 3 recordings with at least one contact.',
  };
  double get target => switch (this) {
    QuestKind.hundredSteps => 100,
    QuestKind.fiveMinutes => 300000,
    QuestKind.threeWalks => 3,
  };
  String get unit => switch (this) {
    QuestKind.hundredSteps => 'contacts',
    QuestKind.fiveMinutes => 'minutes',
    QuestKind.threeWalks => 'walks',
  };
}

class QuestEnrollment {
  const QuestEnrollment({
    required this.kind,
    required this.joinedAt,
    required this.excludedIds,
  });
  final QuestKind kind;
  final DateTime joinedAt;
  final List<String> excludedIds;
  double value(List<RecordedSession> sessions) {
    final eligible = sessions.where(
      (s) => !excludedIds.contains(s.id) && !s.startedAt.isBefore(joinedAt),
    );
    return switch (kind) {
      QuestKind.hundredSteps => eligible.fold<double>(
        0,
        (sum, s) => sum + s.steps,
      ),
      QuestKind.fiveMinutes => eligible.fold<double>(
        0,
        (sum, s) => sum + s.activeMilliseconds,
      ),
      QuestKind.threeWalks =>
        eligible.where((s) => s.steps > 0).length.toDouble(),
    };
  }

  double progress(List<RecordedSession> sessions) =>
      (value(sessions) / kind.target).clamp(0, 1).toDouble();
  String displayValue(List<RecordedSession> sessions) =>
      kind == QuestKind.fiveMinutes
      ? (value(sessions) / 60000).toStringAsFixed(1)
      : value(sessions).toStringAsFixed(0);
  String get displayTarget =>
      kind == QuestKind.fiveMinutes ? '5' : kind.target.toStringAsFixed(0);
  Map<String, Object> toJson() => {
    'kind': kind.name,
    'joinedAt': joinedAt.toIso8601String(),
    'excluded': excludedIds,
  };
  factory QuestEnrollment.fromJson(Map<String, dynamic> json) =>
      QuestEnrollment(
        kind: QuestKind.values.byName(json['kind'] as String),
        joinedAt: DateTime.parse(json['joinedAt'] as String),
        excludedIds: List<String>.from(json['excluded'] as List),
      );
}

class Achievement {
  const Achievement(this.title, this.description, this.unlocked);
  final String title, description;
  final bool unlocked;
  static List<Achievement> evaluate(List<RecordedSession> sessions) => [
    Achievement(
      'The first step',
      'Save a recording with at least one contact.',
      sessions.any((s) => s.steps > 0),
    ),
    Achievement(
      'A thousand moments',
      'Accumulate 1,000 recorded contacts.',
      SessionTotals.from(sessions).steps >= 1000,
    ),
    Achievement(
      'Show up three times',
      'Record contacts on three distinct local dates.',
      sessions
              .where((s) => s.steps > 0)
              .map((s) => localDay(s.startedAt))
              .toSet()
              .length >=
          3,
    ),
  ];
}
