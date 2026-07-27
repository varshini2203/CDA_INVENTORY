// lib/screens/gamification/achievement_screen.dart

import 'package:flutter/material.dart';

import '../../models/gamification_models.dart';
import '../../services/gamification_service.dart';
import 'reward_widgets.dart';

class AchievementScreen extends StatelessWidget {
  const AchievementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GKColors.navyDeep,
      appBar: AppBar(
        backgroundColor: GKColors.navy,
        elevation: 0,
        title: const Text('Achievements',
            style: TextStyle(color: GKColors.textPrimary, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: GKColors.textPrimary),
      ),
      body: StreamBuilder<GamificationProfile>(
        stream: GamificationService.watchProfile(),
        builder: (context, snap) {
          final profile = snap.data ?? GamificationProfile.empty('');
          final unlockedSet = profile.achievementIds.toSet();
          final catalog = GamificationService.achievementCatalog;
          final unlockedCount = catalog.where((a) => unlockedSet.contains(a.id)).length;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeScaleIn(
                      child: GlassCard(
                        gradientColors: [GKColors.purple.withOpacity(0.25), GKColors.surface],
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: GKColors.purpleGradient),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.military_tech_rounded,
                                  color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$unlockedCount / ${catalog.length} Unlocked',
                                    style: const TextStyle(
                                        color: GKColors.textPrimary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800)),
                                const Text('Keep completing missions to earn more',
                                    style: TextStyle(color: GKColors.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cols = gkGridColumns(constraints.maxWidth);
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: catalog.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.85,
                          ),
                          itemBuilder: (context, i) {
                            final def = catalog[i];
                            final unlocked = unlockedSet.contains(def.id);
                            return FadeScaleIn(
                              delayMs: 60 * i,
                              child: AchievementBadge(def: def, unlocked: unlocked),
                            );
                          },
                        );
                      },
                    ),
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
