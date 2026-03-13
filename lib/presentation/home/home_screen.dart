import 'package:flutter/material.dart';
import 'package:quest_guide/core/l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:quest_guide/core/theme/app_theme.dart';
import 'package:quest_guide/data/repositories/quest_repository.dart';
import 'package:quest_guide/domain/models/quest_catalog_status.dart';
import 'package:quest_guide/domain/models/quest.dart';
import 'package:quest_guide/presentation/home/cubit/quest_list_cubit.dart';
import 'package:quest_guide/presentation/home/cubit/quest_list_state.dart';
import 'package:quest_guide/presentation/common/loading_skeletons.dart';
import 'package:quest_guide/presentation/common/premium_button.dart';
import 'package:quest_guide/presentation/common/glass_card.dart';
import 'package:quest_guide/presentation/profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          QuestListCubit(questRepository: QuestRepository())..loadQuests(),
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: const [
            _QuestListTab(),
            _MapTab(),
            _ProfileTab(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).navigationBarTheme.backgroundColor,
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) =>
                setState(() => _currentIndex = index),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.explore_outlined),
                selectedIcon: const Icon(Icons.explore_rounded),
                label: AppLocalizations.of(context).homeTitle,
              ),
              NavigationDestination(
                icon: const Icon(Icons.map_outlined),
                selectedIcon: const Icon(Icons.map_rounded),
                label: AppLocalizations.of(context).mapTitle,
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline_rounded),
                selectedIcon: const Icon(Icons.person_rounded),
                label: AppLocalizations.of(context).profileTitle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== ВКЛАДКА КВЕСТОВ ====================

class _QuestListTab extends StatelessWidget {
  const _QuestListTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<QuestListCubit, QuestListState>(
      builder: (context, state) {
        return CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              title: Text(AppLocalizations.of(context).appTitle),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => context.read<QuestListCubit>().loadQuests(),
                ),
              ],
            ),
            if (state is QuestListLoading) const QuestListSkeleton(),
            if (state is QuestListError)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text(state.message, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      PremiumButton(
                        onPressed: () =>
                            context.read<QuestListCubit>().loadQuests(),
                        text: AppLocalizations.of(context).retry,
                      ),
                    ],
                  ),
                ),
              ),
            if (state is QuestListLoaded) ...[
              // Фильтр по городам
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLocalizations.of(context).filterByCity,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(
                                    AppLocalizations.of(context).allCities),
                                selected: state.selectedCity == null,
                                onSelected: (_) => context
                                    .read<QuestListCubit>()
                                    .selectCity(null),
                              ),
                            ),
                            ...state.cities.map(
                              (city) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(city),
                                  selected: state.selectedCity == city,
                                  onSelected: (_) => context
                                      .read<QuestListCubit>()
                                      .selectCity(city),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        state.selectedCity != null
                            ? '${AppLocalizations.of(context).homeTitle}: ${state.selectedCity}'
                            : AppLocalizations.of(context).homeTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
              // Список квестов
              if (state.filteredQuests.isEmpty)
                SliverFillRemaining(
                  child: Center(
                      child: Text(AppLocalizations.of(context).noQuests)),
                )
              else
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final quest = state.filteredQuests[index];
                        return _QuestCard(
                          quest: quest,
                          status: state.statusForQuest(quest.id),
                        );
                      },
                      childCount: state.filteredQuests.length,
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

// ==================== КАРТОЧКА КВЕСТА ====================

class _QuestCard extends StatelessWidget {
  final Quest quest;
  final QuestCatalogStatus status;

  const _QuestCard({required this.quest, required this.status});

  Color get _accentColor {
    switch (quest.difficulty) {
      case QuestDifficulty.easy:
        return const Color(0xFF34A853);
      case QuestDifficulty.medium:
        return const Color(0xFFFF6B35);
      case QuestDifficulty.hard:
        return const Color(0xFFE91E63);
    }
  }

  Color get _statusColor {
    switch (status) {
      case QuestCatalogStatus.notStarted:
        return AppColors.textSecondary;
      case QuestCatalogStatus.inProgress:
        return AppColors.accent;
      case QuestCatalogStatus.completed:
        return AppColors.success;
    }
  }

  IconData get _statusIcon {
    switch (status) {
      case QuestCatalogStatus.notStarted:
        return Icons.radio_button_unchecked_rounded;
      case QuestCatalogStatus.inProgress:
        return Icons.play_circle_outline_rounded;
      case QuestCatalogStatus.completed:
        return Icons.check_circle_outline_rounded;
    }
  }

  String _statusLabel(AppLocalizations l10n) {
    switch (status) {
      case QuestCatalogStatus.notStarted:
        return l10n.questStatusNotStarted;
      case QuestCatalogStatus.inProgress:
        return l10n.questStatusInProgress;
      case QuestCatalogStatus.completed:
        return l10n.questStatusCompleted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        onTap: () => context.push('/quest/${quest.id}'),
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Изображение / placeholder
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: _QuestCardCover(
                  imageUrl: quest.imageUrl,
                  accentColor: _accentColor,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Город + рейтинг
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _accentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                quest.city,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _accentColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                l10n.difficultyLabel(quest.difficulty.name),
                                style: TextStyle(
                                    fontSize: 11, color: _accentColor),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_statusIcon,
                                      size: 12, color: _statusColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    _statusLabel(l10n),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _statusColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (quest.rating > 0) ...[
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              quest.rating.toStringAsFixed(1),
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Название
                  Text(quest.title,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    quest.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  // Статистика
                  Row(
                    children: [
                      _InfoChip(
                          icon: Icons.timer_outlined,
                          label: quest.durationLabel),
                      const SizedBox(width: 10),
                      _InfoChip(
                        icon: Icons.route_outlined,
                        label:
                            '${quest.distanceKm.toStringAsFixed(1)} ${l10n.kmLabel}',
                      ),
                      const SizedBox(width: 10),
                      _InfoChip(
                        icon: Icons.location_on_outlined,
                        label:
                            '${quest.locationIds.length} ${l10n.locationsLabel}',
                      ),
                      const Spacer(),
                      Text(
                        '${quest.totalPoints} ${l10n.pointsLabel}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestCardCover extends StatelessWidget {
  final String imageUrl;
  final Color accentColor;

  const _QuestCardCover({
    required this.imageUrl,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    if (url.isEmpty) {
      return _buildFallback();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallback(),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.25),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallback() {
    return ColoredBox(
      color: accentColor.withValues(alpha: 0.15),
      child: Center(
        child: Icon(Icons.explore_rounded, size: 54, color: accentColor),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(label,
            style:
                Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
      ],
    );
  }
}

// ==================== ЗАГЛУШКИ ВКЛАДОК ====================

class _MapTab extends StatelessWidget {
  const _MapTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.map_rounded,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.mapTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.mapSelectQuestHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    return const ProfileScreen();
  }
}
