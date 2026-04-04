import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quest_guide/core/l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:quest_guide/core/di/app_router.dart';
import 'package:quest_guide/core/theme/app_theme.dart';
import 'package:quest_guide/data/repositories/progress_repository.dart';
import 'package:quest_guide/data/repositories/quest_repository.dart';
import 'package:quest_guide/domain/models/quest_catalog_status.dart';
import 'package:quest_guide/domain/models/quest.dart';
import 'package:quest_guide/domain/models/quest_progress.dart';
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
  DateTime? _lastBackPressedAt;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          QuestListCubit(questRepository: QuestRepository())..loadQuests(),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _handleBackPressed();
        },
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
      ),
    );
  }

  void _handleBackPressed() {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return;
    }

    final now = DateTime.now();
    if (_lastBackPressedAt == null ||
        now.difference(_lastBackPressedAt!) > const Duration(seconds: 2)) {
      _lastBackPressedAt = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нажмите еще раз, чтобы выйти'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    SystemNavigator.pop();
  }
}

// ==================== ВКЛАДКА КВЕСТОВ ====================

class _QuestListTab extends StatefulWidget {
  const _QuestListTab();
  @override
  State<_QuestListTab> createState() => _QuestListTabState();
}

class _QuestListTabState extends State<_QuestListTab> {
  final ProgressRepository _progressRepository = ProgressRepository();
  late Future<QuestProgress?> _resumeProgressFuture;
  String? _dismissedResumeProgressId;
  @override
  void initState() {
    super.initState();
    _resumeProgressFuture = _loadResumeProgress();
  }

  Future<QuestProgress?> _loadResumeProgress() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return null;
    return _progressRepository.getLatestActiveProgressForUser(userId);
  }

  void _reloadAll() {
    context.read<QuestListCubit>().loadQuests();
    setState(() {
      _resumeProgressFuture = _loadResumeProgress();
    });
  }

  Quest? _findQuestById(List<Quest> quests, String questId) {
    for (final quest in quests) {
      if (quest.id == questId) return quest;
    }
    return null;
  }

  String _resolveResumeRoute(QuestProgress progress) {
    switch (progress.currentStage) {
      case QuestRunStage.task:
        return '/quest/${progress.questId}/task/${progress.currentLocationIndex}';
      case QuestRunStage.navigating:
        return '/quest/${progress.questId}/map';
      case QuestRunStage.completed:
        return AppRoutes.home;
    }
  }

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
                  onPressed: _reloadAll,
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
                        onPressed: _reloadAll,
                        text: AppLocalizations.of(context).retry,
                      ),
                    ],
                  ),
                ),
              ),
            if (state is QuestListLoaded) ...[
              SliverToBoxAdapter(
                child: FutureBuilder<QuestProgress?>(
                  future: _resumeProgressFuture,
                  builder: (context, snapshot) {
                    final progress = snapshot.data;
                    if (progress == null ||
                        progress.status != QuestStatus.inProgress ||
                        progress.id == _dismissedResumeProgressId) {
                      return const SizedBox.shrink();
                    }
                    final l10n = AppLocalizations.of(context);
                    final quest =
                        _findQuestById(state.quests, progress.questId);
                    final subtitle = quest != null
                        ? '${l10n.homeResumeQuestSubtitle}: ${quest.title}'
                        : l10n.homeResumeQuestSubtitle;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: GlassCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.play_circle_fill_rounded,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.homeResumeQuestTitle,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                  ),
                                  const SizedBox(height: 10),
                                  FilledButton.icon(
                                    onPressed: () => context
                                        .push(_resolveResumeRoute(progress)),
                                    icon: const Icon(Icons.navigation_rounded,
                                        size: 16),
                                    label: Text(l10n.continueQuest),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _dismissedResumeProgressId = progress.id;
                                });
                              },
                              tooltip: 'Hide',
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Filter by city
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
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
    return BlocBuilder<QuestListCubit, QuestListState>(
      builder: (context, state) {
        if (state is QuestListLoading || state is QuestListInitial) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is QuestListError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error),
                  const SizedBox(height: 8),
                  Text(state.message, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  PremiumButton(
                    text: l10n.retry,
                    onPressed: () =>
                        context.read<QuestListCubit>().loadQuests(),
                  ),
                ],
              ),
            ),
          );
        }

        final loaded = state as QuestListLoaded;
        final inProgress = loaded.quests
            .where(
              (quest) =>
                  loaded.statusForQuest(quest.id) ==
                  QuestCatalogStatus.inProgress,
            )
            .toList(growable: false);

        if (loaded.quests.isEmpty) {
          return Center(child: Text(l10n.noQuests));
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          children: [
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.map_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.mapRoute,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          inProgress.isEmpty
                              ? l10n.mapSelectQuestHint
                              : '${l10n.inProgress}: ${inProgress.length}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (inProgress.isNotEmpty) ...[
              ...inProgress.map((quest) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                quest.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${quest.city} • ${quest.distanceKm.toStringAsFixed(1)} ${l10n.kmLabel}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: () => context.go('/quest/${quest.id}/map'),
                          icon: const Icon(Icons.navigation_rounded, size: 16),
                          label: Text(l10n.mapTitle),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ] else ...[
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.mapSelectQuestHint,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () =>
                          context.push('/quest/${loaded.quests.first.id}'),
                      icon: const Icon(Icons.explore_rounded, size: 16),
                      label: Text(l10n.startQuest),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
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
