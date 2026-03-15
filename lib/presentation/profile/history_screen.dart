import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quest_guide/core/l10n/app_localizations.dart';
import 'package:quest_guide/core/theme/app_theme.dart';
import 'package:quest_guide/data/repositories/progress_repository.dart';
import 'package:quest_guide/data/repositories/quest_repository.dart';
import 'package:quest_guide/domain/models/quest.dart';
import 'package:quest_guide/domain/models/quest_progress.dart';
import 'package:quest_guide/presentation/common/glass_card.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context).historyTitle)),
        body: Center(child: Text(AppLocalizations.of(context).loginTitle)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).historyTitle)),
      body: FutureBuilder<List<_HistoryItem>>(
        future: _loadHistory(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '${AppLocalizations.of(context).error}: ${snapshot.error}',
              ),
            );
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 64,
                    color: AppColors.textHint.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(AppLocalizations.of(context).noHistory),
                ],
              ),
            );
          }

          int totalPoints = 0;
          int completedQuests = 0;
          double totalDistance = 0;
          Duration totalTime = Duration.zero;

          for (final item in items) {
            if (item.progress.status == QuestStatus.completed) {
              completedQuests++;
              totalPoints += item.progress.earnedPoints;
              if (item.quest != null) {
                totalDistance += item.quest!.distanceKm;
              }
              if (item.progress.completedAt != null) {
                totalTime += item.progress.completedAt!
                    .difference(item.progress.startedAt);
              }
            }
          }

          final avgScore =
              completedQuests > 0 ? (totalPoints / completedQuests).round() : 0;
          final weeklyActivity = _buildWeeklyActivity(context, items);

          return Column(
            children: [
              _HistoryStatsSummary(
                completedQuests: completedQuests,
                avgScore: avgScore,
                totalDistance: totalDistance,
                totalTime: totalTime,
              ),
              _HistoryActivityChart(data: weeklyActivity),
              Expanded(
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isCompleted =
                        item.progress.status == QuestStatus.completed;
                    final color = isCompleted
                        ? const Color(0xFF34A853)
                        : const Color(0xFFFF6B35);

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              isCompleted
                                  ? Icons.check_circle_rounded
                                  : Icons.timer_rounded,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.quest?.title ??
                                      AppLocalizations.of(context)
                                          .questFallbackTitle,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(context, item.progress.startedAt),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                if (item.progress.completedAt != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    AppLocalizations.of(context).time(
                                      _formatDuration(
                                        context,
                                        item.progress.startedAt,
                                        item.progress.completedAt,
                                      ),
                                    ),
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${item.progress.earnedPoints}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: AppColors.primary,
                                    ),
                              ),
                              Text(
                                AppLocalizations.of(context).pointsLabel,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (item.progress.totalAnswers > 0) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${item.progress.correctAnswers}/${item.progress.totalAnswers}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<_DailyActivity> _buildWeeklyActivity(
    BuildContext context,
    List<_HistoryItem> items,
  ) {
    final locale = AppLocalizations.of(context).locale;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final bucket = <DateTime, int>{};
    for (var offset = 6; offset >= 0; offset--) {
      final date = today.subtract(Duration(days: offset));
      bucket[date] = 0;
    }

    for (final item in items) {
      final rawDate = item.progress.completedAt ?? item.progress.startedAt;
      final day = DateTime(rawDate.year, rawDate.month, rawDate.day);
      if (bucket.containsKey(day)) {
        bucket[day] = (bucket[day] ?? 0) + 1;
      }
    }

    return bucket.entries
        .map(
          (entry) => _DailyActivity(
            label: DateFormat.E(locale).format(entry.key),
            value: entry.value,
          ),
        )
        .toList(growable: false);
  }

  Future<List<_HistoryItem>> _loadHistory(String userId) async {
    final progressRepo = ProgressRepository();
    final questRepo = QuestRepository();

    final progressList = await progressRepo.getUserHistory(userId);
    final items = <_HistoryItem>[];

    for (final p in progressList) {
      final quest = await questRepo.getQuestById(p.questId);
      items.add(_HistoryItem(progress: p, quest: quest));
    }

    return items;
  }

  String _formatDate(BuildContext context, DateTime dt) {
    final locale = AppLocalizations.of(context).locale;
    return DateFormat('d MMM yyyy', locale).format(dt);
  }

  String _formatDuration(BuildContext context, DateTime start, DateTime? end) {
    if (end == null) return '—';
    final l10n = AppLocalizations.of(context);
    final d = end.difference(start);
    if (d.inHours > 0) {
      return l10n.durationHoursMinutes(d.inHours, d.inMinutes.remainder(60));
    }
    return l10n.durationMinutes(d.inMinutes);
  }
}

class _HistoryItem {
  final QuestProgress progress;
  final Quest? quest;

  _HistoryItem({required this.progress, this.quest});
}

class _DailyActivity {
  final String label;
  final int value;

  const _DailyActivity({required this.label, required this.value});
}

class _HistoryStatsSummary extends StatelessWidget {
  final int completedQuests;
  final int avgScore;
  final double totalDistance;
  final Duration totalTime;

  const _HistoryStatsSummary({
    required this.completedQuests,
    required this.avgScore,
    required this.totalDistance,
    required this.totalTime,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    String formatDuration() {
      if (totalTime.inHours > 0) {
        return l10n.durationHoursMinutes(
          totalTime.inHours,
          totalTime.inMinutes.remainder(60),
        );
      }
      if (totalTime.inMinutes > 0) {
        return l10n.durationMinutes(totalTime.inMinutes);
      }
      return '—';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.analytics_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Общая статистика',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatItem(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Завершено',
                  value: '$completedQuests',
                ),
                _StatItem(
                  icon: Icons.star_border_rounded,
                  label: 'Ср. балл',
                  value: '$avgScore',
                ),
                _StatItem(
                  icon: Icons.directions_walk_rounded,
                  label: 'Пройдено',
                  value: '${totalDistance.toStringAsFixed(1)} км',
                ),
                _StatItem(
                  icon: Icons.timer_outlined,
                  label: 'Время',
                  value: formatDuration(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryActivityChart extends StatelessWidget {
  final List<_DailyActivity> data;

  const _HistoryActivityChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxValue = data.isEmpty
        ? 1
        : math.max(1, data.map((it) => it.value).reduce(math.max));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Активность за 7 дней',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 112,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: data
                    .map(
                      (point) => Expanded(
                        child: _ActivityBar(
                          label: point.label,
                          value: point.value,
                          maxValue: maxValue,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityBar extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;

  const _ActivityBar({
    required this.label,
    required this.value,
    required this.maxValue,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = value / maxValue;
    final height = value == 0 ? 4.0 : 8 + (ratio * 56);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$value',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF4C9AFF), AppColors.primary],
              ),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textHint,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textHint,
              ),
        ),
      ],
    );
  }
}
