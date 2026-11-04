import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stride_ai/app.dart';
import 'package:stride_ai/core/app_controller.dart';
import 'package:stride_ai/domain/demo_repository.dart';

void main() {
  Future<AppController> controller({bool onboarded = true}) async {
    SharedPreferences.setMockInitialValues({'onboarded': onboarded});
    final c = AppController();
    await c.restore();
    return c;
  }

  test('repository failures become recoverable error state', () async {
    final c = AppController(repository: FailingRepository());
    await c.refresh();
    expect(c.state, PreviewState.error);
    expect(c.data, isNull);
  });
  testWidgets('device previews and detail routing work', (tester) async {
    final c = await controller();
    await tester.pumpWidget(StrideApp(controller: c));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Demo wearable'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('disconnected'));
    await tester.pumpAndSettle();
    expect(find.text('No wearable connected'), findsOneWidget);
    await tester.tap(find.text('Connected (simulated)'));
    await tester.pumpAndSettle();
    expect(c.device, DeviceState.connected);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Connected · simulated'), findsOneWidget);
    await tester.tap(find.text('Live'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Open sample walk'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Open sample walk'));
    await tester.pumpAndSettle();
    expect(find.text('2840 steps · 24 minutes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('demo is deterministic and progress is bounded', () async {
    final repository = DemoMovementRepository();
    expect((await repository.loadDashboard()).steps, 6420);
    expect((await repository.loadDashboard()).progress, .8025);
  });
  testWidgets('onboarding completes and stays completed', (tester) async {
    final c = await controller(onboarded: false);
    await tester.pumpWidget(StrideApp(controller: c));
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Explore demo'));
    await tester.tap(find.text('Explore demo'));
    await tester.pumpAndSettle();
    expect(find.text('A little better,\nevery day.'), findsOneWidget);
    final restored = AppController();
    await restored.restore();
    expect(restored.onboarded, isTrue);
  });
  testWidgets('navigation, appearance and all dashboard states work', (
    tester,
  ) async {
    final c = await controller();
    await tester.pumpWidget(StrideApp(controller: c));
    await tester.pumpAndSettle();
    expect(find.text('6420'), findsOneWidget);
    for (final tab in ['Live', 'AI Coach', 'Safety', 'Profile']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(c.themeMode, ThemeMode.light);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    c.preview(PreviewState.loading);
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    c.preview(PreviewState.empty);
    await tester.pumpAndSettle();
    expect(find.text('Your first step starts here'), findsOneWidget);
    await tester.tap(find.text('Load sample walks'));
    await tester.pumpAndSettle();
    expect(find.text('6420'), findsOneWidget);
    c.preview(PreviewState.error);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('6420'), findsOneWidget);
  });
  testWidgets('compact screen supports dashboard without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(StrideApp(controller: await controller()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class FailingRepository implements MovementRepository {
  @override
  Future<DashboardData> loadDashboard() async =>
      throw StateError('Demo failure');
}
