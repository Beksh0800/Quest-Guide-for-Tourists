import 'package:flutter/material.dart';
import 'package:quest_guide/core/l10n/app_localizations.dart';
import 'package:quest_guide/core/l10n/locale_cubit.dart';
import 'package:quest_guide/core/security/access_control.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:quest_guide/core/di/app_router.dart';
import 'package:quest_guide/core/theme/app_theme.dart';
import 'package:quest_guide/data/repositories/user_repository.dart';
import 'package:quest_guide/domain/models/user_model.dart';
import 'package:quest_guide/presentation/auth/cubit/auth_cubit.dart';
import 'package:quest_guide/presentation/auth/cubit/auth_state.dart';
import 'package:quest_guide/presentation/common/glass_card.dart';
import 'package:quest_guide/presentation/common/premium_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final user = state is AuthAuthenticated ? state.user : null;
        final isAdmin = user != null &&
            AccessControl.hasAdminAccess(
              isAdminFlag: user.isAdmin,
              role: user.role,
            );

        // Временная отладка - выводим статус админа в консоль
        if (user != null) {
          debugPrint(
              'User: ${user.name}, isAdmin: ${user.isAdmin}, role: ${user.role}, hasAdminAccess: $isAdmin');
        }
        final deniedByRouter = GoRouterState.of(context)
                .uri
                .queryParameters[AppRoutes.adminDeniedQueryParam] ==
            AppRoutes.adminDeniedQueryValue;

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              title: Text(AppLocalizations.of(context).profileTitle),
              actions: [
                IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () {}),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    if (deniedByRouter) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.lock_outline_rounded,
                              color: AppColors.error,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context)
                                    .adminAccessDeniedMessage,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Avatar
                    CircleAvatar(
                      radius: 44,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.15),
                      backgroundImage: user?.photoUrl != null
                          ? NetworkImage(user!.photoUrl!)
                          : null,
                      child: user?.photoUrl == null
                          ? const Icon(Icons.person_rounded,
                              size: 44, color: AppColors.primary)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?.name ?? AppLocalizations.of(context).tourist,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (isAdmin) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '⚡ Администратор',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Stats grid
                    Row(
                      children: [
                        _ProfileStat(
                          value: '${user?.totalPoints ?? 0}',
                          label: AppLocalizations.of(context).points,
                        ),
                        const SizedBox(width: 8),
                        _ProfileStat(
                          value: '${user?.questsCompleted ?? 0}',
                          label: AppLocalizations.of(context).questsLabel,
                        ),
                        const SizedBox(width: 8),
                        _ProfileStat(
                          value: '${user?.earnedBadgeIds.length ?? 0}',
                          label: AppLocalizations.of(context).badgesLabel,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    if (user != null) ...[
                      _LeaderboardSection(
                        userId: user.id,
                        fallbackUserName: user.name,
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Menu items
                    GlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          _MenuItem(
                            icon: Icons.emoji_events_outlined,
                            title: AppLocalizations.of(context).achievements,
                            onTap: () => context.push(AppRoutes.achievements),
                          ),
                          _MenuItem(
                            icon: Icons.history_rounded,
                            title: AppLocalizations.of(context).history,
                            onTap: () => context.push(AppRoutes.history),
                          ),
                          _MenuItem(
                            icon: Icons.language_rounded,
                            title: AppLocalizations.of(context).languageLabel,
                            subtitle: context.watch<LocaleCubit>().state ==
                                    AppLanguage.kz
                                ? AppLocalizations.of(context).kazakh
                                : AppLocalizations.of(context).russian,
                            onTap: () => _showLanguageDialog(context),
                          ),
                          if (isAdmin) ...[
                            _MenuItem(
                              icon: Icons.admin_panel_settings_outlined,
                              title: AppLocalizations.of(context)
                                  .adminContentTitle,
                              onTap: () => context.push(AppRoutes.adminContent),
                            ),
                            _MenuItem(
                              icon: Icons.fact_check_outlined,
                              title: AppLocalizations.of(context)
                                  .adminModerationQueueOpen,
                              onTap: () =>
                                  context.push(AppRoutes.adminModerationQueue),
                            ),
                          ] else ...[
                            // Временная кнопка для получения админ прав
                            _MenuItem(
                              icon: Icons.admin_panel_settings,
                              title: '🔑 Получить админ права',
                              subtitle: 'Временная функция для разработки',
                              onTap: () {
                                final userId = user?.id;
                                if (userId == null || userId.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Ошибка: ID пользователя не найден'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                  return;
                                }
                                _makeAdmin(context, userId);
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    PremiumButton(
                      onPressed: () {
                        context.read<AuthCubit>().signOut();
                        context.go(AppRoutes.login);
                      },
                      text: AppLocalizations.of(context).signOut,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<LocaleCubit>();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.languageLabel),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.russian),
              trailing: cubit.state == AppLanguage.ru
                  ? const Icon(Icons.check_rounded, color: AppColors.primary)
                  : null,
              onTap: () {
                cubit.setLanguage(AppLanguage.ru);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(l10n.kazakh),
              trailing: cubit.state == AppLanguage.kz
                  ? const Icon(Icons.check_rounded, color: AppColors.primary)
                  : null,
              onTap: () {
                cubit.setLanguage(AppLanguage.kz);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _makeAdmin(BuildContext context, String userId) async {
    debugPrint('_makeAdmin: Starting with userId: $userId');

    if (userId.isEmpty) {
      debugPrint('_makeAdmin: Error - userId is empty');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка: ID пользователя пустой'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Получить админ права?'),
          content: const Text(
              'Это предоставит вам доступ к административным функциям управления контентом.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Предоставить'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      debugPrint('_makeAdmin: User cancelled');
      return;
    }

    debugPrint('_makeAdmin: User confirmed, updating Firestore...');

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isAdmin': true,
        'role': 'admin',
      });

      debugPrint('_makeAdmin: Firestore update successful');

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Админ права предоставлены! Перезайдите в приложение.'),
          backgroundColor: AppColors.success,
        ),
      );

      // Перезапускаем проверку авторизации
      debugPrint('_makeAdmin: Triggering AuthCubit.checkAuthStatus...');
      context.read<AuthCubit>().checkAuthStatus();
    } catch (e) {
      debugPrint('_makeAdmin: Error updating Firestore: $e');
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _ProfileStat extends StatelessWidget {
  final String value;
  final String label;
  const _ProfileStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const color = AppColors.textPrimary;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      leading: Icon(icon, color: color),
      title: Text(title,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: color)),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing:
          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
      onTap: onTap,
    );
  }
}

class _LeaderboardSection extends StatefulWidget {
  final String userId;
  final String fallbackUserName;

  const _LeaderboardSection({
    required this.userId,
    required this.fallbackUserName,
  });

  @override
  State<_LeaderboardSection> createState() => _LeaderboardSectionState();
}

class _LeaderboardSectionState extends State<_LeaderboardSection> {
  final UserRepository _userRepository = UserRepository();
  late Future<_LeaderboardData> _leaderboardFuture;

  @override
  void initState() {
    super.initState();
    _leaderboardFuture = _loadLeaderboard();
  }

  @override
  void didUpdateWidget(covariant _LeaderboardSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _leaderboardFuture = _loadLeaderboard();
    }
  }

  Future<_LeaderboardData> _loadLeaderboard() async {
    // Три запроса запускаются параллельно
    final results = await Future.wait([
      _userRepository.getTopUsers(limit: 5),
      _userRepository.getUserRank(widget.userId),
      _userRepository.getUserById(widget.userId),
    ]);

    final topUsers = results[0] as List<UserModel>;
    final currentRank = results[1] as int?;
    final currentUser = results[2] as UserModel?;

    return _LeaderboardData(
      topUsers: topUsers,
      currentUserRank: currentRank,
      currentUserPoints: currentUser?.totalPoints ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return GlassCard(
      child: SizedBox(
        width: double.infinity,
        child: FutureBuilder<_LeaderboardData>(
          future: _leaderboardFuture,
          builder: (context, snapshot) {
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting;
            final hasError = snapshot.hasError;
            final data = snapshot.data;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.leaderboard_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.leaderboardTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (isLoading)
                  const SizedBox(
                    height: 64,
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (hasError)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      l10n.leaderboardLoadError,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                else if (data != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RankSummary(
                        rank: data.currentUserRank,
                        points: data.currentUserPoints,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.leaderboardTopLabel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      if (data.topUsers.isEmpty)
                        Text(
                          l10n.leaderboardEmpty,
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      else
                        Column(
                          children:
                              List.generate(data.topUsers.length, (index) {
                            final rankedUser = data.topUsers[index];
                            final isCurrentUser =
                                rankedUser.id == widget.userId;
                            return _RankRow(
                              rank: index + 1,
                              user: rankedUser,
                              isCurrentUser: isCurrentUser,
                            );
                          }),
                        ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RankSummary extends StatelessWidget {
  final int? rank;
  final int points;

  const _RankSummary({required this.rank, required this.points});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rankLabel = rank != null ? '#$rank' : l10n.leaderboardUnranked;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.leaderboardYourRank,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '$points ${l10n.pointsLabel}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          Text(
            rankLabel,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final int rank;
  final UserModel user;
  final bool isCurrentUser;

  const _RankRow({
    required this.rank,
    required this.user,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final userName = user.name.trim().isNotEmpty ? user.name : l10n.tourist;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.divider,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '#$rank',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isCurrentUser
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isCurrentUser ? '$userName (${l10n.leaderboardYou})' : userName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${user.totalPoints}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardData {
  final List<UserModel> topUsers;
  final int? currentUserRank;
  final int currentUserPoints;

  const _LeaderboardData({
    required this.topUsers,
    required this.currentUserRank,
    required this.currentUserPoints,
  });
}
