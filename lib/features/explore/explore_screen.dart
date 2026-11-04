import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_controller.dart';
import '../../domain/demo_repository.dart';
import '../../widgets/components.dart';

/// Retained bundled examples are intentionally separate from recorded history.
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({
    super.key,
    required this.kind,
    required this.controller,
    this.sessionId,
  });
  final String kind;
  final AppController controller;
  final String? sessionId;
  @override
  Widget build(BuildContext context) {
    final matches = DemoMovementRepository.walks.where(
      (s) => s.id == sessionId,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Walk details')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: StatusPill('BUNDLED DEMO EXAMPLE'),
          ),
          const SizedBox(height: 20),
          if (matches.isEmpty)
            StatePanel(
              icon: Icons.search_off,
              title: 'Walk not found',
              message: 'This bundled sample does not exist.',
              action: 'View saved history',
              onAction: () => context.go('/history'),
            )
          else
            Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    matches.first.title,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(matches.first.date),
                  const SizedBox(height: 24),
                  Text(
                    '${matches.first.steps} steps · ${matches.first.minutes} minutes',
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'A fixed bundled example. It is excluded from recorded progress, goals, quests and Coach observations. No replay or physical measurement is implied.',
                  ),
                  TextButton(
                    onPressed: () => context.push('/gait'),
                    child: const Text('How gait metrics work'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
