import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:quest_guide/core/l10n/app_localizations.dart';
import 'package:quest_guide/core/theme/app_theme.dart';
import 'package:quest_guide/data/services/achievement_evaluator.dart';
import 'package:quest_guide/domain/models/achievement.dart';
import 'package:quest_guide/domain/models/quest_progress.dart';
import 'package:quest_guide/domain/models/user_model.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar:
          AppBar(title: Text(AppLocalizations.of(context).achievementsTitle)),
      body: FutureBuilder<_AchievementData>(
        future: _loadAchievements(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text(
                    '${AppLocalizations.of(context).error}: ${snapshot.error}'));
          }

          final data = snapshot.data!;
          if (data.achievements.isEmpty) {
            return Center(
                child: Text(AppLocalizations.of(context).noAchievements));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemCount: data.achievements.length,
            itemBuilder: (context, index) {
              final achievement = data.achievements[index];
              final earned = data.earnedIds.contains(achievement.id);
              final color = Color(achievement.colorValue);
              final progress = data.progressByAchievement[achievement.id];

              return GestureDetector(
                onTap: () =>
                    _showDetail(context, achievement, earned, progress),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: earned
                            ? LinearGradient(
                                colors: [color, color.withValues(alpha: 0.7)])
                            : null,
                        color: earned ? null : AppColors.divider,
                        shape: BoxShape.circle,
                        boxShadow: earned
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        _iconFromString(achievement.iconName),
                        color: earned ? Colors.white : AppColors.textHint,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      achievement.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontSize: 11,
                            color: earned
                                ? AppColors.textPrimary
                                : AppColors.textHint,
                          ),
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(999),
                      value: earned ? 1 : (progress?.progressPercent ?? 0),
                      backgroundColor: AppColors.divider,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        earned ? color : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showDetail(
    BuildContext context,
    Achievement a,
    bool earned,
    AchievementProgressSnapshot? progress,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconFromString(a.iconName),
              size: 48,
              color: earned ? AppColors.primary : AppColors.textHint,
            ),
            const SizedBox(height: 12),
            Text(a.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(a.description, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              earned
                  ? AppLocalizations.of(context).achievementEarnedLabel
                  : AppLocalizations.of(context).achievementLockedLabel,
              style: TextStyle(
                color: earned ? AppColors.success : AppColors.textHint,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              progress?.progressText ?? '—',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<_AchievementData> _loadAchievements(String? userId) async {
    final firestore = FirebaseFirestore.instance;

    final achievementsSnap = await firestore.collection('achievements').get();
    final achievements = achievementsSnap.docs
        .map((d) => Achievement.fromMap(d.data(), d.id))
        .toList();

    UserModel? userModel;
    QuestProgress? latestProgress;
    List<String> earnedIds = [];
    if (userId != null) {
      final userDoc = await firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        userModel = UserModel.fromMap(userDoc.data()!, userDoc.id);
        final badges = (userDoc.data()?['earnedBadgeIds'] as List<dynamic>?) ??
            (userDoc.data()?['badges'] as List<dynamic>?) ??
            [];
        earnedIds = badges.cast<String>();
      }

      final latestProgressSnap = await firestore
          .collection('progress')
          .where('userId', isEqualTo: userId)
          .orderBy('startedAt', descending: true)
          .limit(1)
          .get();
      if (latestProgressSnap.docs.isNotEmpty) {
        final doc = latestProgressSnap.docs.first;
        latestProgress = QuestProgress.fromMap(doc.data(), doc.id);
      }
    }

    final evaluator = const AchievementEvaluator();
    final effectiveUser = userModel ??
        UserModel(
          id: userId ?? 'guest',
          name: '',
          email: '',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        );
    final effectiveProgress = latestProgress ??
        QuestProgress(
          id: 'none',
          userId: userId ?? 'guest',
          questId: '',
          startedAt: DateTime.now(),
          completedAt: DateTime.now(),
        );

    final progressByAchievement = <String, AchievementProgressSnapshot>{};
    for (final achievement in achievements) {
      progressByAchievement[achievement.id] = evaluator.evaluateProgress(
        achievement: achievement,
        user: effectiveUser,
        progress: effectiveProgress,
      );
    }

    return _AchievementData(
      achievements: achievements,
      earnedIds: earnedIds,
      progressByAchievement: progressByAchievement,
    );
  }

  static IconData _iconFromString(String name) {
    switch (name) {
      case 'explore':
        return Icons.explore_rounded;
      case 'hiking':
        return Icons.hiking_rounded;
      case 'stars':
        return Icons.stars_rounded;
      case 'workspace_premium':
        return Icons.workspace_premium_rounded;
      case 'military_tech':
        return Icons.military_tech_rounded;
      case 'speed':
        return Icons.speed_rounded;
      case 'camera':
        return Icons.camera_alt_rounded;
      case 'map':
        return Icons.map_rounded;
      default:
        return Icons.emoji_events_rounded;
    }
  }
}

class _AchievementData {
  final List<Achievement> achievements;
  final List<String> earnedIds;
  final Map<String, AchievementProgressSnapshot> progressByAchievement;

  _AchievementData({
    required this.achievements,
    required this.earnedIds,
    required this.progressByAchievement,
  });
}
