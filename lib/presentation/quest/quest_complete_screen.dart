import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quest_guide/core/di/app_router.dart';
import 'package:quest_guide/core/l10n/app_localizations.dart';
import 'package:quest_guide/core/theme/app_theme.dart';
import 'package:quest_guide/data/repositories/progress_repository.dart';
import 'package:quest_guide/data/repositories/quest_repository.dart';
import 'package:quest_guide/data/repositories/user_repository.dart';
import 'package:quest_guide/data/services/achievement_service.dart';
import 'package:quest_guide/data/services/time_bonus_service.dart';
import 'package:quest_guide/domain/models/quest.dart';
import 'package:quest_guide/domain/models/quest_progress.dart';
import 'package:quest_guide/presentation/common/premium_button.dart';
import 'package:quest_guide/presentation/common/glass_card.dart';

class QuestCompleteScreen extends StatefulWidget {
  final String questId;
  final int score;
  final int totalLocations;
  final String? progressId;
  final int correctAnswers;
  final int totalAnswers;

  const QuestCompleteScreen({
    super.key,
    required this.questId,
    this.score = 0,
    this.totalLocations = 0,
    this.progressId,
    this.correctAnswers = 0,
    this.totalAnswers = 0,
  });

  @override
  State<QuestCompleteScreen> createState() => _QuestCompleteScreenState();
}

class _QuestCompleteScreenState extends State<QuestCompleteScreen>
    with SingleTickerProviderStateMixin {
  Quest? _quest;
  final TimeBonusService _timeBonusService = const TimeBonusService();
  bool _saving = true;
  bool _saved = false;
  bool _alreadyCompleted = false;
  String? _error;
  int _awardedBadges = 0;
  int _finalScore = 0;
  int _baseScore = 0;
  int _timeBonusPoints = 0;
  late final AnimationController _animCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut);
    _saveAndLoad();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAndLoad() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final questRepo = QuestRepository();
      final quest = await questRepo.getQuestById(widget.questId);

      bool savedNow = false;
      bool alreadySaved = false;
      int awarded = 0;
      int finalScore = widget.score;
      int baseScore = widget.score;
      int timeBonusPoints = 0;

      if (userId != null) {
        final progressRepo = ProgressRepository();
        final userRepo = UserRepository();
        final achievementService = AchievementService(userRepository: userRepo);

        QuestProgress? progress;
        if (widget.progressId != null && widget.progressId!.isNotEmpty) {
          progress = await progressRepo.getProgressById(widget.progressId!);
        }

        progress ??=
            await progressRepo.getActiveProgress(userId, widget.questId);

        if (progress != null) {
          final finalCorrect = progress.correctAnswers > 0
              ? progress.correctAnswers
              : widget.correctAnswers;
          final finalAnswers = progress.totalAnswers > 0
              ? progress.totalAnswers
              : widget.totalAnswers;
          final finalTaskIds = progress.completedTaskIds;
          final finalLocationIndex = widget.totalLocations > 0
              ? widget.totalLocations - 1
              : progress.currentLocationIndex;

          if (progress.status == QuestStatus.completed) {
            alreadySaved = true;
            finalScore = progress.earnedPoints;
            timeBonusPoints = progress.timeBonusPoints;
            baseScore = (progress.earnedPoints - progress.timeBonusPoints)
                .clamp(0, progress.earnedPoints)
                .toInt();
          } else {
            final questEstimatedMinutes = quest?.estimatedMinutes ?? 0;
            final basePoints = progress.earnedPoints > 0
                ? progress.earnedPoints
                : widget.score;
            final bonusResult = _timeBonusService.calculate(
              basePoints: basePoints,
              questEstimatedMinutes: questEstimatedMinutes,
              completionDuration: DateTime.now().difference(progress.startedAt),
            );

            finalScore = bonusResult.totalPoints;
            baseScore = bonusResult.basePoints;
            timeBonusPoints = bonusResult.bonusPoints;

            final completed = await progressRepo.completeQuest(
              progressId: progress.id,
              finalPoints: finalScore,
              timeBonusPoints: timeBonusPoints,
              correctAnswers: finalCorrect,
              totalAnswers: finalAnswers,
              completedTaskIds: finalTaskIds,
              finalLocationIndex: finalLocationIndex,
            );

            if (completed) {
              savedNow = true;

              if (finalScore > 0) {
                await userRepo.addPoints(userId, finalScore);
              }
              await userRepo.incrementQuestsCompleted(userId);

              final completedProgress =
                  (await progressRepo.getProgressById(progress.id)) ??
                      progress.copyWith(
                        status: QuestStatus.completed,
                        earnedPoints: finalScore,
                        timeBonusPoints: timeBonusPoints,
                        completedAt: DateTime.now(),
                      );

              final awardedIds = await achievementService.evaluateAndAward(
                userId: userId,
                progress: completedProgress,
              );
              awarded = awardedIds.length;
            } else {
              alreadySaved = true;
              final persisted = await progressRepo.getProgressById(progress.id);
              if (persisted != null) {
                finalScore = persisted.earnedPoints;
                timeBonusPoints = persisted.timeBonusPoints;
                baseScore = (persisted.earnedPoints - persisted.timeBonusPoints)
                    .clamp(0, persisted.earnedPoints)
                    .toInt();
              }
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _quest = quest;
        _saving = false;
        _saved = savedNow;
        _alreadyCompleted = alreadySaved;
        _awardedBadges = awarded;
        _finalScore = finalScore;
        _baseScore = baseScore;
        _timeBonusPoints = timeBonusPoints;
      });
      _animCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '${AppLocalizations.of(context).saveError}: $e';
      });
      _animCtrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_saving) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l10n.savingResult),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.warning.withValues(alpha: 0.2),
                        AppColors.warning.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    size: 64,
                    color: AppColors.warning,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.questComplete,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _quest?.title ?? l10n.questFallbackTitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              GlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      l10n.finalScore,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_finalScore',
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                                color: AppColors.primary,
                                fontSize: 56,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    Text(
                      l10n.pointsLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    if (_timeBonusPoints > 0) ...[
                      const SizedBox(height: 10),
                      Text(
                        '${l10n.basePointsLabel}: $_baseScore ${l10n.pointsLabel}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bolt_rounded,
                              size: 18,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l10n.speedBonusAwarded(_timeBonusPoints),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ResultStat(
                          label: l10n.locationsLabel,
                          value: '${widget.totalLocations}',
                          icon: Icons.location_on_rounded,
                        ),
                        _ResultStat(
                          label: l10n.maxPoints,
                          value: '${_quest?.totalPoints ?? 0}',
                          icon: Icons.star_rounded,
                        ),
                        _ResultStat(
                          label: l10n.result,
                          value: _quest != null && _quest!.totalPoints > 0
                              ? '${(_finalScore / _quest!.totalPoints * 100).round()}%'
                              : '—',
                          icon: Icons.analytics_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_saved) ...[
                const SizedBox(height: 16),
                _StatusBanner(
                  icon: Icons.check_circle_rounded,
                  color: AppColors.success,
                  text: l10n.resultSaved,
                ),
              ],
              if (_alreadyCompleted) ...[
                const SizedBox(height: 16),
                _StatusBanner(
                  icon: Icons.info_outline_rounded,
                  color: AppColors.primary,
                  text: l10n.resultAlreadySaved,
                ),
              ],
              if (_awardedBadges > 0) ...[
                const SizedBox(height: 16),
                _StatusBanner(
                  icon: Icons.workspace_premium_rounded,
                  color: AppColors.warning,
                  text: l10n.newBadgesUnlocked(_awardedBadges),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                _StatusBanner(
                  icon: Icons.warning_rounded,
                  color: AppColors.error,
                  text: _error!,
                ),
              ],
              const SizedBox(height: 32),
              PremiumButton(
                text: l10n.toHome,
                onPressed: () => context.go(AppRoutes.home),
              ),
              const SizedBox(height: 12),
              PremiumButton(
                text: l10n.playAgain,
                isSecondary: true,
                onPressed: () => context.go('/quest/${widget.questId}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _StatusBanner({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Flexible(child: Text(text, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ResultStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(height: 6),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}
