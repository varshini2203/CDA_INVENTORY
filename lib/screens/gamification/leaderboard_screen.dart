// lib/screens/gamification/leaderboard_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/gamification_models.dart';
import '../../services/gamification_service.dart';
import 'reward_widgets.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: GKColors.navyDeep,
      appBar: AppBar(
        backgroundColor: GKColors.navy,
        elevation: 0,
        title: const Text('Leaderboard',
            style: TextStyle(color: GKColors.textPrimary, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: GKColors.textPrimary),
      ),
      body: StreamBuilder<List<LeaderboardEntry>>(
        stream: GamificationService.watchLeaderboard(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: GKColors.teal));
          }
          final entries = snap.data!;
          if (entries.isEmpty) {
            return const Center(
              child: Text('No staff on the leaderboard yet.',
                  style: TextStyle(color: GKColors.textSecondary)),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  children: List.generate(entries.length, (i) {
                    final entry = entries[i];
                    final isMe = entry.uid == myUid;
                    final rank = i + 1;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FadeScaleIn(
                        delayMs: 30 * i,
                        child: _LeaderboardRow(entry: entry, rank: rank, isMe: isMe),
                      ),
                    );
                  }),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank;
  final bool isMe;

  const _LeaderboardRow({required this.entry, required this.rank, required this.isMe});

  Color get _rankColor {
    switch (rank) {
      case 1:
        return GKColors.amber;
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return GKColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = entry.name.isNotEmpty
        ? entry.name.trim().split(RegExp(r'\s+')).map((w) => w[0]).take(2).join().toUpperCase()
        : '?';

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      gradientColors: isMe
          ? [GKColors.teal.withOpacity(0.25), GKColors.surface]
          : null,
      borderRadius: 16,
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: rank <= 3
                ? Icon(Icons.emoji_events_rounded, color: _rankColor, size: 24)
                : Text('#$rank',
                style: const TextStyle(
                    color: GKColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 20,
            backgroundColor: (isMe ? GKColors.teal : GKColors.purple).withOpacity(0.25),
            child: Text(initials,
                style: TextStyle(
                    color: isMe ? GKColors.teal : GKColors.purple,
                    fontWeight: FontWeight.w800,
                    fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: GKColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: GKColors.teal.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('You',
                            style: TextStyle(
                                color: GKColors.teal, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                Text('Level ${entry.level}',
                    style: const TextStyle(color: GKColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.local_fire_department_rounded, color: GKColors.coral, size: 16),
              const SizedBox(width: 3),
              Text('${entry.currentStreak}',
                  style: const TextStyle(color: GKColors.coral, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(width: 14),
          Text('${entry.totalXP} XP',
              style: const TextStyle(
                  color: GKColors.amber, fontSize: 13, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
