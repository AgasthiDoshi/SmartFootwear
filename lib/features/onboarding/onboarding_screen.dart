import 'package:flutter/material.dart';
import '../../core/app_controller.dart';
import '../../core/theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int page = 0;
  static const titles = [
    'Every step\ntells a story.',
    'Find your\nnatural rhythm.',
    'Your journey.\nYour control.',
  ];
  static const descriptions = [
    'Meet your movement companion. Turn everyday walks into a clearer picture of how you move.',
    'Explore balance, cadence and progress with thoughtful insights that meet you where you are.',
    'Start your smart walking journey with intelligent gait tracking and emergency fall protection.',
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: StrideColors.mint),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'SMART FOOTWEAR',
                        style: TextStyle(
                          letterSpacing: 4,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                    TextButton(
                      onPressed: widget.controller.completeOnboarding,
                      child: const Text('Skip'),
                    ),
                  ],
                ),
                SizedBox(
                  height: 260,
                  child: Center(
                    child: Semantics(
                      label: 'Movement illustration',
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: .2),
                              Colors.transparent,
                            ],
                          ),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: .3),
                          ),
                        ),
                        child: Icon(
                          [
                            Icons.route_rounded,
                            Icons.balance_rounded,
                            Icons.shield_outlined,
                          ][page],
                          size: 100,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                Text(
                  'MOVE WITH INTENTION',
                  style: TextStyle(
                    letterSpacing: 2,
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  child: Text(
                    titles[page],
                    key: ValueKey(page),
                    style: const TextStyle(
                      fontSize: 44,
                      height: 1.08,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -2,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  descriptions[page],
                  style: const TextStyle(fontSize: 16, height: 1.6),
                ),
                const SizedBox(height: 30),
                Row(
                  children: List.generate(
                    3,
                    (i) => Container(
                      margin: const EdgeInsets.only(right: 6),
                      width: i == page ? 28 : 8,
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: i == page
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (page < 2) {
                        setState(() => page++);
                      } else {
                        widget.controller.completeOnboarding();
                      }
                    },
                    child: Text(page == 2 ? 'Get started' : 'Continue'),
                  ),
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'Designed for movement. Built around you.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
