import 'dart:async';
import 'dart:convert';
import 'package:stride_ai/domain/session_repository.dart';
import 'helpers/progress_fixtures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stride_ai/app.dart';
import 'package:stride_ai/core/app_controller.dart';
import 'package:stride_ai/domain/demo_repository.dart';

class PendingDashboard implements MovementRepository {
  final requests = <Completer<DashboardData>>[];
  @override
  Future<DashboardData> loadDashboard() {
    final request = Completer<DashboardData>();
    requests.add(request);
    return request.future;
  }
}

void main() {
  test(
    'invalid persisted summaries fail without overwriting storage',
    () async {
      final valid = savedSession().toJson();
      for (final change in <Map<String, Object?>>[
        {'id': ''},
        {
          'shares': [20, 20, 20],
        },
        {'activeMs': 0},
      ]) {
        final raw = jsonEncode([
          {...valid, ...change},
        ]);
        SharedPreferences.setMockInitialValues({
          LocalSessionRepository.key: raw,
        });
        await expectLater(
          LocalSessionRepository().load(),
          throwsFormatException,
        );
        expect(
          (await SharedPreferences.getInstance()).getString(
            LocalSessionRepository.key,
          ),
          raw,
        );
      }
      SharedPreferences.setMockInitialValues({
        LocalSessionRepository.key: jsonEncode([valid, valid]),
      });
      await expectLater(LocalSessionRepository().load(), throwsFormatException);
    },
  );

  test(
    'latest dashboard request wins and disposal ignores pending results',
    () async {
      final repository = PendingDashboard();
      final c = AppController(repository: repository);
      final first = c.refresh();
      final second = c.refresh();
      repository.requests[1].complete(
        await DemoMovementRepository().loadDashboard(),
      );
      await second;
      repository.requests[0].completeError(StateError('stale'));
      await first;
      expect(c.state, PreviewState.ready);
      final pending = c.refresh();
      c.dispose();
      repository.requests.last.completeError(StateError('disposed'));
      await pending;
    },
  );

  testWidgets('every route renders on compact screens in both themes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final c = AppController();
    await c.restore();
    await tester.pumpWidget(StrideApp(controller: c));
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.text('Home')));
    for (final light in [false, true]) {
      c.setLightTheme(light);
      for (final route in [
        '/home',
        '/live',
        '/coach',
        '/safety',
        '/profile',
        '/gait',
        '/history',
        '/goals',
        '/quests',
        '/devices',
        '/privacy',
        '/contacts',
        '/notifications',
        '/settings',
        '/session/morning',
        '/session/missing',
        '/replay/missing',
        '/missing',
      ]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$route light=$light');
      }
    }
  });

  testWidgets('onboarding scrolls on a short screen with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({});
    final c = AppController();
    await c.restore();
    await tester.pumpWidget(StrideApp(controller: c));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Continue'), 200);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
