import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:quest_guide/core/l10n/app_localizations.dart';
import 'package:quest_guide/core/theme/app_theme.dart';
import 'package:quest_guide/domain/models/achievement.dart';

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

              return GestureDetector(
                onTap: () => _showDetail(context, achievement, earned),
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
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showDetail(BuildContext context, Achievement a, bool earned) {
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

    List<String> earnedIds = [];
    if (userId != null) {
      final userDoc = await firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final badges = (userDoc.data()?['earnedBadgeIds'] as List<dynamic>?) ??
            (userDoc.data()?['badges'] as List<dynamic>?) ??
            [];
        earnedIds = badges.cast<String>();
      }
    }

    return _AchievementData(achievements: achievements, earnedIds: earnedIds);
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
  _AchievementData({required this.achievements, required this.earnedIds});
}
