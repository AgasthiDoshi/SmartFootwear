import '../progress.dart';
import '../session_repository.dart';

enum CoachDataState { ready, loading, error }

enum CoachIntent {
  daily,
  weekly,
  comparison,
  baseline,
  observations,
  goals,
  help,
}

enum CoachResponseKind {
  answer,
  insufficient,
  unavailable,
  unsupported,
  boundary,
}

class CoachSuggestion {
  const CoachSuggestion(this.intent, this.label, this.question);
  final CoachIntent intent;
  final String label, question;
  static const all = [
    CoachSuggestion(
      CoachIntent.daily,
      'Today',
      'Summarize my recorded movement today.',
    ),
    CoachSuggestion(
      CoachIntent.weekly,
      'This week',
      'Give me my weekly summary.',
    ),
    CoachSuggestion(
      CoachIntent.comparison,
      'Compare weeks',
      'Compare my last two completed weeks.',
    ),
    CoachSuggestion(
      CoachIntent.baseline,
      'My baseline',
      'What is my personal recording baseline?',
    ),
    CoachSuggestion(
      CoachIntent.observations,
      'Explain my walk',
      'Explain observations from my latest recording.',
    ),
    CoachSuggestion(
      CoachIntent.goals,
      'My goals',
      'How am I doing against my saved goals today?',
    ),
  ];
}

/// Minimal immutable aggregate facts. No raw sensor trace, profile, location,
/// chat history or account information is needed by the local coach.
class CoachSessionFacts {
  CoachSessionFacts.fromSession(RecordedSession session)
    : id = session.id,
      startedAt = session.startedAt,
      steps = session.steps,
      activeMilliseconds = session.activeMilliseconds,
      calibrated = session.calibrated,
      consistency = session.consistency,
      pressureShares = List.unmodifiable(session.pressureShares);
  final String id;
  final DateTime startedAt;
  final int steps, activeMilliseconds;
  final bool calibrated;
  final double? consistency;
  final List<double> pressureShares;
  double? get cadence =>
      activeMilliseconds > 0 ? steps * 60000 / activeMilliseconds : null;
}

class CoachSnapshot {
  CoachSnapshot({
    required this.asOf,
    required List<CoachSessionFacts> sessions,
    this.historyState = CoachDataState.ready,
    this.goals,
    this.preferencesState = CoachDataState.ready,
  }) : sessions = List.unmodifiable(
         sessions.where((s) => !s.startedAt.isAfter(asOf)),
       );
  final DateTime asOf;
  final List<CoachSessionFacts> sessions;
  final CoachDataState historyState, preferencesState;
  final PersonalGoals? goals;
}

class CoachRequest {
  const CoachRequest({
    required this.question,
    required this.snapshot,
    this.intent,
  });
  final String question;
  final CoachSnapshot snapshot;
  final CoachIntent? intent;
}

class CoachEvidence {
  const CoachEvidence(
    this.title,
    this.explanation, {
    this.sessionIds = const [],
  });
  final String title, explanation;
  final List<String> sessionIds;
}

class CoachResponse {
  const CoachResponse({
    required this.kind,
    required this.text,
    required this.evidence,
  });
  final CoachResponseKind kind;
  final String text;
  final List<CoachEvidence> evidence;
}

/// A future API adapter must use an authenticated server that holds its secrets,
/// obtain explicit consent before sending data, minimize the request, and validate
/// returned claims against the supplied snapshot. Never embed an API key in Flutter.
/// No remote adapter or paid credential is required or configured in this app.
abstract interface class CoachProvider {
  String get name;
  Future<CoachResponse> respond(CoachRequest request);
}
