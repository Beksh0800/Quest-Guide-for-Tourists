import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quest_guide/core/l10n/app_localizations.dart';
import 'package:quest_guide/core/theme/app_theme.dart';
import 'package:quest_guide/data/repositories/quest_repository.dart';
import 'package:quest_guide/data/repositories/user_repository.dart';
import 'package:quest_guide/domain/models/quest_progress.dart';
import 'package:quest_guide/domain/models/user_model.dart';
import 'package:quest_guide/presentation/common/glass_card.dart';

class AdminUserStatsScreen extends StatelessWidget {
  const AdminUserStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminUserStatsTitle)),
      body: FutureBuilder<_AdminStatsData>(
        future: _loadStats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${l10n.adminUserStatsLoadError}: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _StatsGrid(data: data),
              const SizedBox(height: 12),
              _TopUsersCard(data: data),
              const SizedBox(height: 12),
              _CityCoverageCard(data: data),
              const SizedBox(height: 12),
              _RecentActivityCard(data: data),
            ],
          );
        },
      ),
    );
  }

  Future<_AdminStatsData> _loadStats() async {
    final firestore = FirebaseFirestore.instance;
    final userRepository = UserRepository();
    final questRepository = QuestRepository();

    final usersSnapshot = await firestore.collection('users').get();
    final users = usersSnapshot.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .toList(growable: false);

    final progressSnapshot = await firestore
        .collection('progress')
        .orderBy('lastUpdatedAt', descending: true)
        .limit(500)
        .get();
    final progress = progressSnapshot.docs
        .map((doc) => QuestProgress.fromMap(doc.data(), doc.id))
        .toList(growable: false);

    final topUsers = await userRepository.getTopUsers(limit: 10);

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final activeRuns =
        progress.where((item) => item.status == QuestStatus.inProgress).length;
    final completedRuns =
        progress.where((item) => item.status == QuestStatus.completed).length;
    final todayCompletions = progress
        .where((item) => item.status == QuestStatus.completed)
        .where((item) => item.completedAt != null)
        .where((item) =>
            item.completedAt!.isAfter(todayStart) &&
            item.completedAt!.isBefore(todayEnd))
        .length;

    final roleCounts = <String, int>{
      'user': 0,
      'admin': 0,
      'superuser': 0,
    };
    for (final user in users) {
      final role = user.role.trim().toLowerCase();
      if (role == 'superuser') {
        roleCounts['superuser'] = (roleCounts['superuser'] ?? 0) + 1;
      } else if (role == 'admin') {
        roleCounts['admin'] = (roleCounts['admin'] ?? 0) + 1;
      } else {
        roleCounts['user'] = (roleCounts['user'] ?? 0) + 1;
      }
    }

    final cityCoverage = <String, int>{};
    for (final user in users) {
      for (final city in user.visitedCities) {
        final normalized = city.trim();
        if (normalized.isEmpty) continue;
        cityCoverage[normalized] = (cityCoverage[normalized] ?? 0) + 1;
      }
    }
    final sortedCities = cityCoverage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final recentCompleted = progress
        .where((item) => item.status == QuestStatus.completed)
        .where((item) => item.completedAt != null)
        .toList()
      ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    final recent = recentCompleted.take(12).toList(growable: false);

    final questTitleById = <String, String>{};
    for (final questId in recent.map((e) => e.questId).toSet()) {
      final quest = await questRepository.getQuestById(questId);
      questTitleById[questId] =
          quest?.title.trim().isNotEmpty == true ? quest!.title : questId;
    }

    final userNameById = <String, String>{
      for (final user in users)
        user.id: user.name.trim().isEmpty ? user.email : user.name
    };

    return _AdminStatsData(
      totalUsers: users.length,
      activeRuns: activeRuns,
      completedRuns: completedRuns,
      todayCompletions: todayCompletions,
      roleCounts: roleCounts,
      topUsers: topUsers,
      cityCoverage: sortedCities,
      recentRuns: recent,
      questTitleById: questTitleById,
      userNameById: userNameById,
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.data});

  final _AdminStatsData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.6,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: [
        _StatCard(
          title: l10n.adminUserStatsTotalUsers,
          value: '${data.totalUsers}',
          icon: Icons.people_alt_rounded,
        ),
        _StatCard(
          title: l10n.adminUserStatsActiveRuns,
          value: '${data.activeRuns}',
          icon: Icons.directions_walk_rounded,
        ),
        _StatCard(
          title: l10n.adminUserStatsCompletedRuns,
          value: '${data.completedRuns}',
          icon: Icons.flag_circle_rounded,
        ),
        _StatCard(
          title: l10n.adminUserStatsTodayCompletions,
          value: '${data.todayCompletions}',
          icon: Icons.today_rounded,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopUsersCard extends StatelessWidget {
  const _TopUsersCard({required this.data});

  final _AdminStatsData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.adminUserStatsTopUsers,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (data.topUsers.isEmpty)
            Text(l10n.adminUserStatsNoUsers)
          else
            ...data.topUsers.take(8).toList().asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final user = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text(
                        '$rank.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        user.name.trim().isEmpty ? user.email : user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${user.totalPoints}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _RoleChip(
                label: 'user: ${data.roleCounts['user'] ?? 0}',
                color: AppColors.textSecondary,
              ),
              _RoleChip(
                label: 'admin: ${data.roleCounts['admin'] ?? 0}',
                color: AppColors.primary,
              ),
              _RoleChip(
                label: 'superuser: ${data.roleCounts['superuser'] ?? 0}',
                color: AppColors.accent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _CityCoverageCard extends StatelessWidget {
  const _CityCoverageCard({required this.data});

  final _AdminStatsData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.adminUserStatsCitiesCoverage,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (data.cityCoverage.isEmpty)
            Text(l10n.adminUserStatsNoUsers)
          else
            ...data.cityCoverage.take(8).map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${entry.value}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.data});

  final _AdminStatsData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.adminUserStatsRecentActivity,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (data.recentRuns.isEmpty)
            Text(l10n.adminUserStatsNoRecent)
          else
            ...data.recentRuns.take(10).map((run) {
              final userLabel = data.userNameById[run.userId] ?? run.userId;
              final questLabel =
                  data.questTitleById[run.questId] ?? run.questId;
              final completed = run.completedAt?.toLocal();
              final completedLabel = completed == null
                  ? '—'
                  : '${completed.day.toString().padLeft(2, '0')}.${completed.month.toString().padLeft(2, '0')} ${completed.hour.toString().padLeft(2, '0')}:${completed.minute.toString().padLeft(2, '0')}';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      questLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          completedLabel,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                        const Spacer(),
                        Text(
                          '${run.earnedPoints}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _AdminStatsData {
  final int totalUsers;
  final int activeRuns;
  final int completedRuns;
  final int todayCompletions;
  final Map<String, int> roleCounts;
  final List<UserModel> topUsers;
  final List<MapEntry<String, int>> cityCoverage;
  final List<QuestProgress> recentRuns;
  final Map<String, String> questTitleById;
  final Map<String, String> userNameById;

  const _AdminStatsData({
    required this.totalUsers,
    required this.activeRuns,
    required this.completedRuns,
    required this.todayCompletions,
    required this.roleCounts,
    required this.topUsers,
    required this.cityCoverage,
    required this.recentRuns,
    required this.questTitleById,
    required this.userNameById,
  });
}
