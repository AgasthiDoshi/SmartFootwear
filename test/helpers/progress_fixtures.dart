import 'package:stride_ai/domain/session_repository.dart';
import 'package:stride_ai/domain/progress_repository.dart';
import 'package:stride_ai/domain/replay.dart';

RecordedSession savedSession({
  String id = 'demo-test',
  DateTime? date,
  int steps = 100,
  int ms = 60000,
  bool replay = false,
}) => RecordedSession(
  id: id,
  startedAt: date ?? DateTime(2026, 10, 21, 9),
  activeMilliseconds: ms,
  steps: steps,
  pressureShares: const [25, 50, 25],
  calibrated: true,
  consistency: null,
  replay: replay
      ? [
          ReplayPoint(
            activeMilliseconds: 50,
            steps: 0,
            values: const [0, 0, 0, 0, 0, 1, 0, 0, 0],
          ),
          ReplayPoint(
            activeMilliseconds: ms,
            steps: steps,
            values: const [100, 200, 300, .1, .2, 1.1, 1, 2, 3],
          ),
        ]
      : const [],
);

class MemoryProgress implements ProgressRepository {
  ProgressPreferences data = const ProgressPreferences();
  bool failLoad = false, failSave = false;
  @override
  Future<ProgressPreferences> load() async {
    if (failLoad) {
      throw StateError('Read failed');
    }
    return data;
  }

  @override
  Future<void> save(ProgressPreferences preferences) async {
    if (failSave) {
      throw StateError('Write failed');
    }
    data = preferences;
  }
}
