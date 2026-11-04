import 'dart:async';
import 'package:stride_ai/domain/coach/coach_models.dart';
import 'package:stride_ai/domain/coach/local_coach_provider.dart';

class DeferredCoach implements CoachProvider {
  @override
  String get name => 'Local Coach';
  final result = Completer<CoachResponse>();
  CoachRequest? request;
  @override
  Future<CoachResponse> respond(CoachRequest request) {
    this.request = request;
    return result.future;
  }

  void complete() => result.complete(LocalCoachProvider().answer(request!));
}

class FlakyCoach implements CoachProvider {
  @override
  String get name => 'Local Coach';
  bool fail = true;
  @override
  Future<CoachResponse> respond(CoachRequest request) async {
    if (fail) {
      throw StateError('Test failure');
    }
    return LocalCoachProvider().answer(request);
  }
}
