import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:quest_guide/core/l10n/app_localizations.dart';
import 'package:quest_guide/core/theme/app_theme.dart';
import 'package:quest_guide/data/repositories/quest_repository.dart';
import 'package:quest_guide/domain/models/quest_catalog_status.dart';
import 'package:quest_guide/domain/models/quest_location.dart';
import 'package:quest_guide/presentation/quest/cubit/quest_detail_cubit.dart';
import 'package:quest_guide/presentation/quest/cubit/quest_detail_state.dart';
import 'package:quest_guide/presentation/common/loading_skeletons.dart';
import 'package:quest_guide/presentation/common/premium_button.dart';

class QuestDetailScreen extends StatelessWidget {
  final String questId;

  const QuestDetailScreen({super.key, required this.questId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => QuestDetailCubit(questRepository: QuestRepository())
        ..loadQuest(questId),
      child: const _QuestDetailView(),
    );
  }
}

class _QuestDetailView extends StatelessWidget {
  const _QuestDetailView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocBuilder<QuestDetailCubit, QuestDetailState>(
      builder: (context, state) {
        if (state is QuestDetailLoading || state is QuestDetailInitial) {
          return const Scaffold(
            body: QuestDetailSkeleton(),
          );
        }

        if (state is QuestDetailError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text(state.message),
                ],
              ),
            ),
          );
        }

        final loaded = state as QuestDetailLoaded;
        final quest = loaded.quest;
        final locations = loaded.locations;
        final questStatus = loaded.questStatus;
        final activeProgress = loaded.activeProgress;
        final continueIndex = activeProgress?.currentLocationIndex ?? 0;
        final canContinue =
            activeProgress != null && continueIndex < locations.length;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 60),
                        const Icon(Icons.explore_rounded,
                            size: 64, color: Colors.white30),
                        const SizedBox(height: 12),
                        Text(
                          quest.city,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                leading: IconButton(
                  icon: const CircleAvatar(
                    backgroundColor: Colors.black26,
                    child: Icon(Icons.arrow_back_ios_rounded,
                        color: Colors.white, size: 16),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              quest.title,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ),
                          if (quest.rating > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.star_rounded,
                                      size: 18, color: AppColors.warning),
                                  const SizedBox(width: 4),
                                  Text(
                                    quest.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _QuestStatusBadge(status: questStatus),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _StatBox(
                              icon: Icons.timer_outlined,
                              label: quest.durationLabel),
                          const SizedBox(width: 12),
                          _StatBox(
                            icon: Icons.location_on_outlined,
                            label: l10n.nPoints(quest.locationIds.length),
                          ),
                          const SizedBox(width: 12),
                          _StatBox(
                            icon: Icons.route_outlined,
                            label:
                                '${quest.distanceKm.toStringAsFixed(1)} ${l10n.kmLabel}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _StatBox(
                            icon: Icons.trending_up_rounded,
                            label: l10n.difficultyLabel(quest.difficulty.name),
                          ),
                          const SizedBox(width: 12),
                          _StatBox(
                            icon: Icons.stars_rounded,
                            label: '${quest.totalPoints} ${l10n.pointsLabel}',
                          ),
                          const SizedBox(width: 12),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(l10n.questDescription,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(quest.description,
                          style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 24),
                      Text(
                        '${l10n.locations} (${locations.length})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      ...locations.map((loc) => _LocationTile(location: loc)),
                      const SizedBox(height: 28),
                      if (questStatus == QuestCatalogStatus.inProgress &&
                          canContinue)
                        PremiumButton(
                          onPressed: () => context
                              .push('/quest/${quest.id}/task/$continueIndex'),
                          icon: Icons.play_arrow_rounded,
                          text: l10n.continueQuest,
                        )
                      else if (questStatus == QuestCatalogStatus.completed)
                        PremiumButton(
                          onPressed: () =>
                              context.push('/quest/${quest.id}/task/0'),
                          icon: Icons.replay_rounded,
                          text: l10n.restartQuest,
                        )
                      else
                        PremiumButton(
                          onPressed: () =>
                              context.push('/quest/${quest.id}/map'),
                          icon: Icons.play_arrow_rounded,
                          text: l10n.startQuest,
                        ),
                      const SizedBox(height: 12),
                      PremiumButton(
                        onPressed: () => context.push('/quest/${quest.id}/map'),
                        icon: Icons.map_rounded,
                        text: l10n.openRouteMap,
                        isSecondary: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuestStatusBadge extends StatelessWidget {
  final QuestCatalogStatus status;

  const _QuestStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final (Color color, IconData icon, String label) = switch (status) {
      QuestCatalogStatus.notStarted => (
          AppColors.textSecondary,
          Icons.radio_button_unchecked_rounded,
          l10n.questStatusNotStarted,
        ),
      QuestCatalogStatus.inProgress => (
          AppColors.accent,
          Icons.play_circle_outline_rounded,
          l10n.questStatusInProgress,
        ),
      QuestCatalogStatus.completed => (
          AppColors.success,
          Icons.check_circle_outline_rounded,
          l10n.questStatusCompleted,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style:
                Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatBox({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  final QuestLocation location;

  const _LocationTile({required this.location});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary,
            child: Text(
              '${location.order + 1}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.name,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  location.description,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
