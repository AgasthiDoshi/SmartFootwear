import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import 'components.dart';
import 'stride_live_map.dart';

class SmartFootwearMapCard extends StatelessWidget {
  const SmartFootwearMapCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: StrideColors.mint,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: StrideColors.mint,
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'LIVE GPS LOCATION & ROUTE',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const StatusPill('GPS TRACKING'),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Interactive footwear navigation map with live GPS tracking.',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 14),

          // Live Interactive Map View
          const StrideLiveMap(
            height: 250,
            showControls: true,
            showTelemetryOverlay: true,
            trackTrail: true,
          ),

          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1A9850),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => context.push('/navigation'),
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: const Text(
                    'Open Navigation',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

