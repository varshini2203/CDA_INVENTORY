// lib/screens/gamification/mission_screen.dart

import 'package:flutter/material.dart';

import '../../models/gamification_models.dart';
import '../../services/gamification_service.dart';
import 'reward_widgets.dart';

class MissionScreen extends StatelessWidget {
  const MissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GKColors.navyDeep,
      appBar: AppBar(
        backgroundColor: GKColors.navy,
        elevation: 0,
        title: const Text("Today's Missions",
            style: TextStyle(color: GKColors.textPrimary, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: GKColors.textPrimary),
      ),
      body: StreamBuilder<DailyMissionSet>(
        stream: GamificationService.watchTodayMissions(),
        builder: (context, snap) {
          final set = snap.data;
          final missions = set?.missions ?? const <Mission>[];

          if (snap.connectionState == ConnectionState.waiting && missions.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: GKColors.teal));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeScaleIn(
                      child: GlassCard(
                        gradientColors: [GKColors.teal.withOpacity(0.2), GKColors.surface],
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${set?.completedCount ?? 0}/${missions.length} completed',
                                      style: const TextStyle(
                                          color: GKColors.textPrimary,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  const Text('Complete all missions to maximize today\'s XP',
                                      style: TextStyle(color: GKColors.textSecondary, fontSize: 12)),
                                ],
                              ),
                            ),
                            if (set?.allCompleted == true)
                              const Icon(Icons.emoji_events_rounded, color: GKColors.amber, size: 30),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (missions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text('No missions available yet.',
                              style: TextStyle(color: GKColors.textSecondary)),
                        ),
                      )
                    else
                      ...List.generate(missions.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: FadeScaleIn(
                            delayMs: 60 * i,
                            child: MissionTile(mission: missions[i]),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
