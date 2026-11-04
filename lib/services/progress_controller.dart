import 'package:flutter/foundation.dart';
import '../domain/progress.dart';
import '../domain/progress_repository.dart';
import '../domain/session_repository.dart';

class ProgressController extends ChangeNotifier {
  ProgressController({
    ProgressRepository? repository,
    DateTime Function()? clock,
  }) : repository = repository ?? LocalProgressRepository(),
       clock = clock ?? DateTime.now;
  final ProgressRepository repository;
  final DateTime Function() clock;
  ProgressPreferences preferences = const ProgressPreferences();
  bool loading = true, saving = false;
  String? loadError, saveError;
  bool _disposed = false, _loading = false;
  PersonalGoals get goals => preferences.goals;
  QuestEnrollment? get quest => preferences.quest;
  bool get editable => !loading && !saving && loadError == null;
  Future<void> load() async {
    if (_loading || saving) {
      return;
    }
    _loading = true;
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      preferences = await repository.load();
    } catch (_) {
      loadError =
          'Goals and quests could not be loaded. Retry to protect saved choices.';
    }
    loading = false;
    _loading = false;
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<bool> _save(ProgressPreferences next) async {
    if (!editable) {
      return false;
    }
    saving = true;
    saveError = null;
    notifyListeners();
    var success = false;
    try {
      await repository.save(next);
      preferences = next;
      success = true;
    } catch (_) {
      saveError =
          'Could not save this change. Your previous settings are unchanged. Please retry.';
    }
    saving = false;
    if (!_disposed) {
      notifyListeners();
    }
    return success;
  }

  Future<bool> setGoals(PersonalGoals goals) async {
    if (!goals.valid) {
      return false;
    }
    return _save(ProgressPreferences(goals: goals, quest: quest));
  }

  Future<bool> join(QuestKind kind, List<RecordedSession> existing) => _save(
    ProgressPreferences(
      goals: goals,
      quest: QuestEnrollment(
        kind: kind,
        joinedAt: clock(),
        excludedIds: List.unmodifiable(existing.map((s) => s.id)),
      ),
    ),
  );
  Future<bool> leaveQuest() => _save(ProgressPreferences(goals: goals));
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
