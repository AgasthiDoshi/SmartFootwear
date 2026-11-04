import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/app_controller.dart';
import 'core/theme.dart';
import 'domain/demo_repository.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/explore/explore_screen.dart';
import 'features/live/live_screen.dart';
import 'features/gait/gait_screen.dart';
import 'features/history/history_screen.dart';
import 'features/history/session_details_screen.dart';
import 'features/progress/goals_screen.dart';
import 'features/progress/quests_screen.dart';
import 'features/replay/replay_screen.dart';
import 'features/coach/coach_screen.dart';
import 'features/safety/safety_screen.dart';
import 'features/safety/contacts_screen.dart';
import 'features/devices/device_hub_screen.dart';
import 'features/settings/profile_screen.dart';
import 'features/settings/privacy_screen.dart';
import 'features/settings/notifications_screen.dart';
import 'features/settings/app_settings_screen.dart';
import 'features/admin/admin_login_screen.dart';
import 'features/navigation/navigation_screen.dart';
import 'widgets/fall_emergency_modal.dart';
import 'widgets/admin_pin_dialog.dart';

class StrideApp extends StatefulWidget {
  const StrideApp({super.key, required this.controller});
  final AppController controller;
  @override
  State<StrideApp> createState() => _StrideAppState();
}

class _StrideAppState extends State<StrideApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      widget.controller.studio.stopFeed();
      widget.controller.safety.cancel(
        reason:
            'Practice cancelled because the app left the foreground. No delivery was attempted.',
      );
    }
  }

  late final GoRouter router = GoRouter(
    initialLocation: '/home',
    refreshListenable: widget.controller,
    redirect: (context, state) {
      if (!widget.controller.onboarded) {
        return state.matchedLocation == '/onboarding' ? null : '/onboarding';
      }
      return state.matchedLocation == '/onboarding' ? '/home' : null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) =>
            OnboardingScreen(controller: widget.controller),
      ),
      ShellRoute(
        builder: (context, state, child) => _Shell(
          controller: widget.controller,
          location: state.uri.path,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) =>
                HomeScreen(controller: widget.controller),
          ),
          GoRoute(
            path: '/live',
            builder: (context, state) => LiveScreen(
              studio: widget.controller.studio,
              controller: widget.controller,
              onConnectionChanged: (value) => widget.controller.setDevice(
                value ? DeviceState.demo : DeviceState.disconnected,
              ),
            ),
          ),
          GoRoute(
            path: '/coach',
            builder: (context, state) =>
                CoachScreen(controller: widget.controller.coach),
          ),
          GoRoute(
            path: '/safety',
            builder: (context, state) => SafetyScreen(
              safety: widget.controller.safety,
              preferences: widget.controller.preferences,
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => ProfileScreen(app: widget.controller),
          ),
        ],
      ),
      GoRoute(
        path: '/gait',
        builder: (context, state) =>
            GaitScreen(studio: widget.controller.studio),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => HistoryScreen(
          studio: widget.controller.studio,
          progress: widget.controller.progress,
        ),
      ),
      GoRoute(
        path: '/goals',
        builder: (context, state) => GoalsScreen(
          progress: widget.controller.progress,
          studio: widget.controller.studio,
        ),
      ),
      GoRoute(
        path: '/quests',
        builder: (context, state) => QuestsScreen(
          progress: widget.controller.progress,
          studio: widget.controller.studio,
        ),
      ),
      GoRoute(
        path: '/replay/:id',
        builder: (context, state) => ReplayScreen(
          studio: widget.controller.studio,
          id: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/devices',
        builder: (context, state) => DeviceHubScreen(app: widget.controller),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => PrivacyScreen(app: widget.controller),
      ),
      GoRoute(
        path: '/contacts',
        builder: (context, state) =>
            ContactsScreen(preferences: widget.controller.preferences),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => NotificationsScreen(
          preferences: widget.controller.preferences,
          safety: widget.controller.safety,
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => AppSettingsScreen(app: widget.controller),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) =>
            AdminLoginScreen(controller: widget.controller.adminReadings),
      ),
      GoRoute(
        path: '/navigation',
        builder: (context, state) => NavigationScreen(
          hapticService: widget.controller.hapticService,
          adminReadings: widget.controller.adminReadings,
        ),
      ),
      GoRoute(
        path: '/session/:id',
        builder: (context, state) =>
            !DemoMovementRepository.walks.any(
              (s) => s.id == state.pathParameters['id'],
            )
            ? RecordedSessionScreen(
                studio: widget.controller.studio,
                id: state.pathParameters['id']!,
              )
            : ExploreScreen(
                kind: 'session',
                sessionId: state.pathParameters['id'],
                controller: widget.controller,
              ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => context.go('/home'),
          child: const Text('Page not found · Go Home'),
        ),
      ),
    ),
  );
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    router.dispose();
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => MaterialApp.router(
      title: 'Smartfootwear',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations:
              MediaQuery.disableAnimationsOf(context) ||
              (widget.controller.preferences.ready &&
                  widget.controller.preferences.data.settings.reduceMotion),
        ),
        child: FallEmergencyModal(
          safety: widget.controller.safety,
          adminReadings: widget.controller.adminReadings,
          child: SafetyActivityBanner(
            safety: widget.controller.safety,
            onOpen: () => router.go('/safety'),
            child: child!,
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      theme: strideTheme(Brightness.light),
      darkTheme: strideTheme(Brightness.dark),
      themeMode: widget.controller.themeMode,
      routerConfig: router,
    ),
  );
}

class _Shell extends StatefulWidget {
  const _Shell({
    required this.controller,
    required this.location,
    required this.child,
  });
  final AppController controller;
  final String location;
  final Widget child;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  static const paths = ['/home', '/live', '/coach', '/safety', '/profile'];
  DateTime? _lastProfileTap;
  int _profileTaps = 0;

  void _selectDestination(BuildContext context, int index) async {
    if (index != paths.length - 1) {
      _profileTaps = 0;
      _lastProfileTap = null;
      context.go(paths[index]);
      return;
    }

    final now = DateTime.now();
    if (_lastProfileTap == null ||
        now.difference(_lastProfileTap!) > const Duration(seconds: 4)) {
      _profileTaps = 0;
    }
    _lastProfileTap = now;
    _profileTaps++;
    if (_profileTaps >= 4) {
      _profileTaps = 0;
      _lastProfileTap = null;
      final unlocked = await showAdminPinDialog(context);
      if (unlocked && context.mounted) {
        widget.controller.adminReadings.authenticateWithPin();
        context.push('/admin');
      }
    } else {
      context.go(paths[index]);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: widget.child,
        ),
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: paths.contains(widget.location)
          ? paths.indexOf(widget.location)
          : 0,
      onDestinationSelected: (i) => _selectDestination(context, i),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(icon: Icon(Icons.graphic_eq), label: 'Live'),
        NavigationDestination(
          icon: Icon(Icons.auto_awesome_outlined),
          label: 'AI Coach',
        ),
        NavigationDestination(
          icon: Icon(Icons.shield_outlined),
          label: 'Safety',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ],
    ),
  );
}
