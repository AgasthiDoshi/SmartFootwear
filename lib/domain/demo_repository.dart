enum PreviewState { ready, loading, empty, error }

enum DeviceState { demo, connected, disconnected }

class WalkSession {
  const WalkSession(
    this.id,
    this.title,
    this.date,
    this.minutes,
    this.steps,
    this.score,
  );
  final String id, title, date;
  final int minutes, steps, score;
}

class DashboardData {
  const DashboardData({
    required this.steps,
    required this.goal,
    required this.sessions,
  });
  final int steps, goal;
  final List<WalkSession> sessions;
  double get progress => (steps / goal).clamp(0, 1);
}

abstract interface class MovementRepository {
  Future<DashboardData> loadDashboard();
}

class DemoMovementRepository implements MovementRepository {
  static const walks = [
    WalkSession('morning', 'Morning reset', '21 Oct · 7:30 AM', 24, 2840, 92),
    WalkSession(
      'evening',
      'An evening unwind',
      '20 Oct · 6:15 PM',
      32,
      3620,
      88,
    ),
  ];
  @override
  Future<DashboardData> loadDashboard() async =>
      const DashboardData(steps: 6420, goal: 8000, sessions: walks);
}
