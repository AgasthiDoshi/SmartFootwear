import 'package:flutter/foundation.dart';
import '../domain/progress.dart';
import '../domain/session_repository.dart';
import '../domain/coach/coach_models.dart';
import '../domain/coach/local_coach_provider.dart';
import 'studio_controller.dart';
import 'progress_controller.dart';

class CoachExchange {
  const CoachExchange({
    required this.id,
    required this.question,
    required this.version,
    required this.asOf,
    this.intent,
    this.response,
    this.error,
    this.pending = false,
  });
  final int id, version;
  final String question;
  final DateTime asOf;
  final CoachIntent? intent;
  final CoachResponse? response;
  final String? error;
  final bool pending;
}

class CoachController extends ChangeNotifier {
  CoachController({
    required this.studio,
    required this.progress,
    CoachProvider? provider,
    DateTime Function()? clock,
    this.requestTimeout = const Duration(seconds: 8),
  }) : provider = provider ?? LocalCoachProvider(),
       clock = clock ?? progress.clock {
    studio.addListener(_sourceChanged);
    progress.addListener(_sourceChanged);
    _synchronize();
  }
  final StudioController studio;
  final ProgressController progress;
  final CoachProvider provider;
  final DateTime Function() clock;
  final Duration requestTimeout;
  static const maxExchanges = 20, maxQuestionLength = 400;
  final List<CoachExchange> _exchanges = [];
  List<CoachExchange> get exchanges => List.unmodifiable(_exchanges);
  int version = 0;
  int _nextId = 0, _generation = 0;
  bool busy = false, _disposed = false;
  List<RecordedSession> _records = [];
  Object? _preferences;
  String? _sourceStatus;
  DateTime? _date;
  bool _synchronize() {
    final records = studio.sessions;
    final status =
        '${studio.historyLoading}:${studio.historyError}:${progress.loading}:${progress.loadError}';
    final date = localDay(clock());
    if (listEquals(records, _records) &&
        identical(_preferences, progress.preferences) &&
        status == _sourceStatus &&
        date == _date) {
      return false;
    }
    _records = records;
    _preferences = progress.preferences;
    _sourceStatus = status;
    _date = date;
    version++;
    return true;
  }

  void _sourceChanged() {
    if (!_disposed && _synchronize()) {
      notifyListeners();
    }
  }

  void refresh() {
    if (_disposed) {
      return;
    }
    _synchronize();
    notifyListeners();
  }

  CoachSnapshot snapshot() => CoachSnapshot(
    asOf: clock(),
    sessions: studio.sessions.map(CoachSessionFacts.fromSession).toList(),
    historyState: studio.historyLoading
        ? CoachDataState.loading
        : studio.historyError != null
        ? CoachDataState.error
        : CoachDataState.ready,
    goals: progress.loading || progress.loadError != null
        ? null
        : progress.goals,
    preferencesState: progress.loading
        ? CoachDataState.loading
        : progress.loadError != null
        ? CoachDataState.error
        : CoachDataState.ready,
  );
  bool stale(CoachExchange exchange) => exchange.version != version;
  Future<bool> ask(String question, {CoachIntent? intent}) async {
    final trimmed = question.trim();
    if (_disposed ||
        busy ||
        trimmed.isEmpty ||
        trimmed.length > maxQuestionLength) {
      return false;
    }
    _synchronize();
    final snapshot = this.snapshot();
    final exchange = CoachExchange(
      id: _nextId++,
      question: trimmed,
      version: version,
      asOf: snapshot.asOf,
      intent: intent,
      pending: true,
    );
    _exchanges.add(exchange);
    if (_exchanges.length > maxExchanges) {
      _exchanges.removeAt(0);
    }
    await _respond(exchange, snapshot);
    return true;
  }

  Future<void> regenerate(int id) async {
    if (_disposed || busy) {
      return;
    }
    final index = _exchanges.indexWhere((e) => e.id == id);
    if (index < 0) {
      return;
    }
    _synchronize();
    final old = _exchanges[index], snapshot = this.snapshot();
    final updated = CoachExchange(
      id: id,
      question: old.question,
      intent: old.intent,
      version: version,
      asOf: snapshot.asOf,
      pending: true,
    );
    _exchanges[index] = updated;
    await _respond(updated, snapshot);
  }

  Future<void> _respond(CoachExchange exchange, CoachSnapshot snapshot) async {
    final generation = ++_generation;
    busy = true;
    notifyListeners();
    CoachResponse? response;
    String? error;
    try {
      response = await provider
          .respond(
            CoachRequest(
              question: exchange.question,
              snapshot: snapshot,
              intent: exchange.intent,
            ),
          )
          .timeout(requestTimeout);
    } catch (_) {
      error =
          'The coach could not prepare an answer. Retry using the current saved data.';
    }
    if (_disposed || generation != _generation) {
      return;
    }
    _synchronize();
    final index = _exchanges.indexWhere((e) => e.id == exchange.id);
    if (index >= 0) {
      _exchanges[index] = CoachExchange(
        id: exchange.id,
        question: exchange.question,
        intent: exchange.intent,
        version: exchange.version,
        asOf: exchange.asOf,
        response: response,
        error: error,
      );
    }
    busy = false;
    notifyListeners();
  }

  void clear() {
    _generation++;
    _exchanges.clear();
    busy = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    studio.removeListener(_sourceChanged);
    progress.removeListener(_sourceChanged);
    super.dispose();
  }
}
