import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quest_guide/core/l10n/app_localizations.dart';
import 'package:quest_guide/core/theme/app_theme.dart';
import 'package:quest_guide/data/repositories/progress_repository.dart';
import 'package:quest_guide/data/repositories/quest_repository.dart';
import 'package:quest_guide/domain/models/quest.dart';
import 'package:quest_guide/domain/models/quest_progress.dart';

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
                    '${AppLocalizations.of(context).error}: ${snapshot.error}'));
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded,
                      size: 64,
                      color: AppColors.textHint.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text(AppLocalizations.of(context).noHistory),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              final isCompleted = item.progress.status == QuestStatus.completed;
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
                                AppLocalizations.of(context).questFallbackTitle,
                            style: Theme.of(context).textTheme.titleMedium,
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
                                    item.progress.completedAt),
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
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
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppColors.primary,
                                  ),
                        ),
                        Text(AppLocalizations.of(context).pointsLabel,
                            style: Theme.of(context).textTheme.bodySmall),
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
          );
        },
      ),
    );
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
