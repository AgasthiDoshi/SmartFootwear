import '../progress.dart';
import 'coach_models.dart';

class CoachPeriod {
  CoachPeriod(this.start, this.end, List<CoachSessionFacts> all)
    : sessions = List.unmodifiable(
        all.where(
          (s) =>
              !s.startedAt.toLocal().isBefore(start) &&
              s.startedAt.toLocal().isBefore(end),
        ),
      );
  final DateTime start, end;
  final List<CoachSessionFacts> sessions;
  int get steps => sessions.fold(0, (sum, s) => sum + s.steps);
  int get activeMilliseconds =>
      sessions.fold(0, (sum, s) => sum + s.activeMilliseconds);
  double get minutes => activeMilliseconds / 60000;
  double? get cadence =>
      activeMilliseconds > 0 ? steps * 60000 / activeMilliseconds : null;
  int get recordedDates =>
      sessions.map((s) => localDay(s.startedAt)).toSet().length;
  List<String> get ids => List.unmodifiable(sessions.map((s) => s.id));
  String get range =>
      '${dateLabel(start)} – ${dateLabel(DateTime(end.year, end.month, end.day - 1))}';
}

class CoachBaseline {
  CoachBaseline(List<CoachSessionFacts> sessions) {
    final moving =
        sessions.where((s) => s.activeMilliseconds > 0 && s.steps > 0).toList()
          ..sort(compareFacts);
    if (moving.isEmpty) {
      return;
    }
    latest = moving.last;
    final day = localDay(latest!.startedAt);
    final cutoff = DateTime(day.year, day.month, day.day - 28);
    final eligible = moving
        .where(
          (s) =>
              s.startedAt.isBefore(latest!.startedAt) &&
              !s.startedAt.toLocal().isBefore(cutoff),
        )
        .toList();
    prior = List.unmodifiable(eligible.reversed.take(10).toList().reversed);
  }
  CoachSessionFacts? latest;
  List<CoachSessionFacts> prior = const [];
  int get dates => prior.map((s) => localDay(s.startedAt)).toSet().length;
  bool get sufficient => prior.length >= 3 && dates >= 2;
  double? get cadence => !sufficient
      ? null
      : prior.fold<int>(0, (sum, s) => sum + s.steps) *
            60000 /
            prior.fold<int>(0, (sum, s) => sum + s.activeMilliseconds);
}

class CoachAnalytics {
  CoachAnalytics(this.snapshot);
  final CoachSnapshot snapshot;
  DateTime get today => localDay(snapshot.asOf);
  CoachPeriod get daily => CoachPeriod(
    today,
    DateTime(today.year, today.month, today.day + 1),
    snapshot.sessions,
  );
  CoachPeriod get weekly {
    final monday = weekStart(today);
    return CoachPeriod(
      monday,
      DateTime(today.year, today.month, today.day + 1),
      snapshot.sessions,
    );
  }

  CoachPeriod get recentWeek => CoachPeriod(
    DateTime(today.year, today.month, today.day - 7),
    today,
    snapshot.sessions,
  );
  CoachPeriod get previousWeek => CoachPeriod(
    DateTime(today.year, today.month, today.day - 14),
    DateTime(today.year, today.month, today.day - 7),
    snapshot.sessions,
  );
  CoachBaseline get baseline => CoachBaseline(snapshot.sessions);
  CoachSessionFacts? get latest {
    if (snapshot.sessions.isEmpty) {
      return null;
    }
    return (snapshot.sessions.toList()..sort(compareFacts)).last;
  }
}

int compareFacts(CoachSessionFacts a, CoachSessionFacts b) {
  final date = a.startedAt.compareTo(b.startedAt);
  return date == 0 ? a.id.compareTo(b.id) : date;
}

String dateLabel(DateTime date) => '${date.day}/${date.month}/${date.year}';
