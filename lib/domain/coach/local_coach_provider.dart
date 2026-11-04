import 'dart:math' as math;
import 'coach_models.dart';
import 'coach_analytics.dart';

/// Finite, auditable templates over saved facts; no generative measurements.
class LocalCoachProvider implements CoachProvider {
  @override
  String get name => 'Local Coach';
  static final _medical = RegExp(
    r'\b(diagnos\w*|disease\w*|parkinson\w*|diabet\w*|arthritis|pain|injur\w*|medical|medicin\w*|medication\w*|healthy|normal|abnormal|condition\w*|stroke|fracture\w*|fall\s+risk|prevent\s+falls?)\b',
  );
  static final _unmeasured = RegExp(
    r'\b(heart|pulse|bpm|blood|oxygen|spo2|temperature|calorie\w*|burn\w*|distance|kilomet\w*|miles?|gps|location|weight|sleep|speed|vo2|stress|hydration)\b',
  );
  @override
  Future<CoachResponse> respond(CoachRequest request) async => answer(request);
  CoachResponse answer(CoachRequest request) {
    final question = request.question
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (_medical.hasMatch(question)) {
      return _response(
        CoachResponseKind.boundary,
        'I cannot diagnose a condition, judge whether your gait is healthy, or assess injury or fall risk from simulated recordings. I can explain saved movement values, but they are not a medical assessment.',
        'Limits of these data',
        'The app stores simulated insole contacts, active recording time, relative ADC shares and recent timing consistency. These are not diagnostic measurements.',
      );
    }
    if (_unmeasured.hasMatch(question)) {
      return _response(
        CoachResponseKind.unsupported,
        'That measurement is not available in saved app data. I cannot infer vital signs, distance, calories, location or walking speed from these simulated recordings. Ask about recorded contacts, active time or contact timing instead.',
        'Unavailable measurement',
        'No heart rate, oxygen, temperature, location, distance or energy measurement is supplied to this provider.',
      );
    }
    final intent = request.intent ?? _classify(question);
    if (intent == CoachIntent.help || intent == null) {
      return _response(
        CoachResponseKind.unsupported,
        'I can summarize today or this week, compare two completed seven-day windows, describe your personal recording baseline, explain the latest recording, or check saved goals. I use focused local rules and cannot answer other questions or fill in missing measurements. Try a suggested question.',
        'Focused local answers',
        'No network service is connected. Responses are deterministic calculations from a snapshot of saved recordings and available targets.',
      );
    }
    final snapshot = request.snapshot;
    if (snapshot.historyState != CoachDataState.ready) {
      return _response(
        CoachResponseKind.unavailable,
        snapshot.historyState == CoachDataState.loading
            ? 'Saved history is still loading. I cannot summarize it yet.'
            : 'Saved history could not be read. Retry loading it before asking for movement insights; unread data is not an empty history.',
        'History availability',
        'No measurements are inferred from missing or unreadable history.',
      );
    }
    final data = CoachAnalytics(snapshot);
    return switch (intent) {
      CoachIntent.daily => _summary(
        data.daily,
        'Today',
        '${dateLabel(data.today)} · through the snapshot time',
      ),
      CoachIntent.weekly => _summary(
        data.weekly,
        'This week',
        '${data.weekly.range} · Monday to the snapshot time',
      ),
      CoachIntent.comparison => _comparison(data),
      CoachIntent.baseline => _baseline(data),
      CoachIntent.observations => _observations(data),
      CoachIntent.goals => _goals(data),
      CoachIntent.help => throw StateError('Help handled above'),
    };
  }

  CoachIntent? _classify(String question) {
    if (RegExp(r'\b(goal\w*|targets?)\b').hasMatch(question)) {
      return CoachIntent.goals;
    }
    if (RegExp(r'\b(baseline|usual|typical)\b').hasMatch(question)) {
      return CoachIntent.baseline;
    }
    if (question.contains('compare') ||
        question.contains('last two') ||
        question.contains('previous week') ||
        question.contains('last week') ||
        question.contains('improv')) {
      return CoachIntent.comparison;
    }
    if (question.contains('weekly summary') ||
        question.contains('this week') ||
        question.contains('week summary')) {
      return CoachIntent.weekly;
    }
    if (question.contains('daily summary') ||
        (question.contains('today') &&
            RegExp(
              r'\b(summary|summarize|steps?|contacts?|cadence|walk\w*|record\w*|active|movement)\b',
            ).hasMatch(question))) {
      return CoachIntent.daily;
    }
    if (RegExp(
          r'\b(observations?|gait|pressure|cadence|consistency)\b',
        ).hasMatch(question) ||
        question.contains('latest recording') ||
        question.contains('latest walk') ||
        question.contains('last walk')) {
      return CoachIntent.observations;
    }
    return null;
  }

  CoachResponse _summary(CoachPeriod period, String title, String range) {
    if (period.sessions.isEmpty) {
      return _response(
        CoachResponseKind.insufficient,
        '$title has no saved recordings in this snapshot ($range). I do not know your real-world activity. Record and save a simulated session to make a summary available.',
        'No recordings in this period',
        'Only saved sessions with a local start date in this period count. Bundled Home examples and unsaved live sessions are excluded.',
      );
    }
    return _response(
      CoachResponseKind.answer,
      '$title: ${period.steps} simulated contacts and ${period.minutes.toStringAsFixed(2)} active recording minutes across ${period.sessions.length} saved recording(s). ${period.recordedDates} local date(s) have recordings.\n\nWeighted recording cadence: ${_cadence(period.cadence)}. These totals describe saved simulation time, not your entire day or physical fitness.',
      'Period and calculation',
      '$range. Contacts and active milliseconds are summed. Minutes = active milliseconds ÷ 60,000; cadence = total contacts × 60,000 ÷ total active milliseconds. Zero-duration cadence is unavailable. Sessions belong wholly to their local start date; pauses are excluded.',
      ids: period.ids,
    );
  }

  CoachResponse _comparison(CoachAnalytics data) {
    final recent = data.recentWeek, previous = data.previousWeek;
    if (recent.sessions.isEmpty || previous.sessions.isEmpty) {
      return _response(
        CoachResponseKind.insufficient,
        'I need saved recordings in both completed seven-day windows to compare them. Recent (${recent.range}): ${recent.sessions.length} recording(s). Previous (${previous.range}): ${previous.sessions.length} recording(s). Missing recordings do not mean you were inactive.',
        'Comparison coverage',
        'Today is excluded to avoid comparing a partial day. Each window has seven local calendar dates. No change in health or fitness is inferred.',
        ids: [...previous.ids, ...recent.ids],
      );
    }
    final delta = recent.steps - previous.steps;
    final percentage = previous.steps == 0
        ? 'A percentage change is unavailable because the previous recorded contact total is zero.'
        : 'Recorded contact change: ${_signed(delta / previous.steps * 100)}%.';
    return _response(
      CoachResponseKind.answer,
      'Recent (${recent.range}): ${recent.steps} contacts, ${recent.minutes.toStringAsFixed(2)} active min, ${recent.recordedDates}/7 dates with recordings.\n\nPrevious (${previous.range}): ${previous.steps} contacts, ${previous.minutes.toStringAsFixed(2)} active min, ${previous.recordedDates}/7 dates with recordings.\n\nDifference: ${delta >= 0 ? '+' : ''}$delta recorded contacts. $percentage\nWeighted cadence: ${_cadence(previous.cadence)} → ${_cadence(recent.cadence)}. Different recording coverage can explain the difference; this is not evidence of improved or declining health.',
      'Like-length recording windows',
      'Today is excluded. Change = recent − previous; percentage = change ÷ previous × 100, only when previous contacts > 0. Cadence uses summed contacts and active time in each window. All values are simulated.',
      ids: [...previous.ids, ...recent.ids],
    );
  }

  CoachResponse _baseline(CoachAnalytics data) {
    final baseline = data.baseline;
    if (!baseline.sufficient) {
      return _response(
        CoachResponseKind.insufficient,
        'There is not enough data for a personal recording baseline. I need a latest moving recording and at least 3 earlier moving recordings across 2 local dates within its preceding 28-calendar-day window. Available earlier: ${baseline.prior.length} recording(s) across ${baseline.dates} date(s). A moving recording must have positive duration and at least one contact. I will not substitute a population norm.',
        'Baseline eligibility',
        'Use up to 10 most recent eligible prior recordings. The latest qualifying recording is excluded from its own baseline; no real-world gait norm or medical score is assumed.',
        ids: baseline.prior.map((s) => s.id).toList(),
      );
    }
    final latest = baseline.latest!;
    final difference = latest.cadence! - baseline.cadence!;
    return _response(
      CoachResponseKind.answer,
      'Your recording baseline is ${baseline.cadence!.toStringAsFixed(1)} contacts/min, from ${baseline.prior.length} earlier moving recordings across ${baseline.dates} local dates.\n\nLatest moving recording (${dateLabel(latest.startedAt.toLocal())}): ${latest.cadence!.toStringAsFixed(1)} contacts/min, ${_signed(difference)} contacts/min (${_signed(difference / baseline.cadence! * 100)}%) relative to that baseline. This compares simulated recording cadence; it does not say whether your gait is healthy or better.',
      'Personal baseline calculation',
      'The baseline is total contacts × 60,000 ÷ total active milliseconds across up to 10 earlier moving recordings, within 28 local calendar days before the latest moving recording. At least 3 earlier sessions on 2 dates are required. Latest cadence uses its own contacts and active time. Relative change = (latest − baseline) ÷ baseline × 100.',
      ids: [...baseline.prior.map((s) => s.id), latest.id],
    );
  }

  CoachResponse _observations(CoachAnalytics data) {
    final latest = data.latest;
    if (latest == null) {
      return _response(
        CoachResponseKind.insufficient,
        'There is no saved recording to explain. Save a simulated walk first. I cannot describe pressure or timing from the bundled examples or an unsaved session.',
        'Observation source',
        'Only the latest retained saved recording supplies these observations.',
      );
    }
    final shares = latest.pressureShares;
    final hasPressure =
        latest.activeMilliseconds > 0 &&
        shares.length == 3 &&
        shares.every((v) => v.isFinite && v >= 0 && v <= 100) &&
        (shares.reduce((a, b) => a + b) - 100).abs() < .1;
    final pressure = !hasPressure
        ? 'Relative pressure shares are unavailable; I cannot infer a distribution.'
        : 'Relative ADC shares: heel ${shares[0].toStringAsFixed(1)}%, forefoot ${shares[1].toStringAsFixed(1)}%, toe ${shares[2].toStringAsFixed(1)}%. These are relative signal totals, not force or bilateral balance.';
    final timing = latest.consistency == null
        ? 'Recent timing consistency is unavailable; the recording did not retain sufficient recent intervals.'
        : 'Saved recent timing consistency is ${latest.consistency!.toStringAsFixed(1)}/100. It describes the latest valid intervals, not the full walk or a clinical gait score.';
    return _response(
      CoachResponseKind.answer,
      'Latest saved recording (${dateLabel(latest.startedAt.toLocal())}): ${latest.steps} simulated contacts in ${(latest.activeMilliseconds / 1000).toStringAsFixed(2)} active seconds. Average recording cadence: ${_cadence(latest.cadence)}.\n\n$pressure\n\n$timing\n\nBaseline status: ${latest.calibrated ? 'calibrated sensor offsets' : 'factory sensor offsets; resting offsets remain in the ADC totals'}. I cannot infer left/right symmetry, diagnosis or fall safety from one simulated insole.',
      'Explainable movement calculations',
      'A rising total FSR signal at or above 700 ADC marks a contact; below 150 re-arms it, with a 300 ms minimum gap. Cadence = contacts × 60,000 ÷ active milliseconds. Zone share = accumulated zone ADC ÷ all zone ADC × 100. Consistency = 100 × (1 − interval standard deviation ÷ mean), clamped 0–100, requiring 3 recent intervals. Calibration changes offsets, not a physical force conversion.',
      ids: [latest.id],
    );
  }

  CoachResponse _goals(CoachAnalytics data) {
    final goals = data.snapshot.goals;
    if (data.snapshot.preferencesState != CoachDataState.ready ||
        goals == null ||
        !goals.valid) {
      return _response(
        CoachResponseKind.unavailable,
        'Saved targets are unavailable. Load your goals before asking for a comparison; I will not invent a target or treat a preference error as a default.',
        'Goal availability',
        'The coach needs successfully loaded app targets as well as readable saved history.',
      );
    }
    final today = data.daily;
    return _response(
      CoachResponseKind.answer,
      'Today’s saved simulation progress: ${today.steps}/${goals.dailySteps} recorded contacts and ${today.minutes.toStringAsFixed(2)}/${goals.dailyMinutes} active minutes.\n\nRemaining to the current app targets: ${math.max(0, goals.dailySteps - today.steps)} recorded contacts and ${math.max(0.0, goals.dailyMinutes - today.minutes).toStringAsFixed(2)} active minutes. ${today.sessions.isEmpty ? 'No recordings are saved today; your real-world activity is unknown.' : 'Only completed, saved recordings count.'} Targets are user-adjustable app goals, not health recommendations.',
      'Saved targets and progress',
      '${dateLabel(data.today)} through the snapshot time. Progress sums today’s retained sessions; remaining = max(0, target − saved total). Defaults, when active, are example app targets. Nothing is inferred about unsaved or real-world movement.',
      ids: today.ids,
    );
  }

  String _cadence(double? value) => value == null
      ? 'unavailable (no positive recorded duration)'
      : '${value.toStringAsFixed(1)} contacts/min';
  String _signed(double value) =>
      '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}';
  CoachResponse _response(
    CoachResponseKind kind,
    String text,
    String title,
    String explanation, {
    List<String> ids = const [],
  }) => CoachResponse(
    kind: kind,
    text: text,
    evidence: [
      CoachEvidence(title, explanation, sessionIds: List.unmodifiable(ids)),
    ],
  );
}
