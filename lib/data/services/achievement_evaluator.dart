import 'dart:math' as math;

import 'package:quest_guide/domain/models/achievement.dart';
import 'package:quest_guide/domain/models/quest_progress.dart';
import 'package:quest_guide/domain/models/user_model.dart';

class AchievementEvaluator {
  const AchievementEvaluator();

  bool isAchieved({
    required Achievement achievement,
    required UserModel user,
    required QuestProgress progress,
  }) {
    final conditionV2 = achievement.conditionV2;
    if (conditionV2 != null && conditionV2.rules.isNotEmpty) {
      final checks = conditionV2.rules
          .map((rule) =>
              _evaluateV2Rule(rule: rule, user: user, progress: progress))
          .toList(growable: false);

      return conditionV2.operatorType == AchievementRuleOperator.any
          ? checks.any((value) => value)
          : checks.every((value) => value);
    }

    return _evaluateV1Condition(
      type: achievement.condition.type,
      target: achievement.condition.targetValue,
      user: user,
      progress: progress,
    );
  }

  AchievementProgressSnapshot evaluateProgress({
    required Achievement achievement,
    required UserModel user,
    required QuestProgress progress,
  }) {
    final achieved = isAchieved(
      achievement: achievement,
      user: user,
      progress: progress,
    );

    final conditionV2 = achievement.conditionV2;
    if (conditionV2 != null && conditionV2.rules.isNotEmpty) {
      final values = conditionV2.rules
          .map((rule) =>
              _progressForRule(rule: rule, user: user, progress: progress))
          .toList(growable: false);

      final aggregatePercent = conditionV2.operatorType ==
              AchievementRuleOperator.any
          ? values.map((e) => e.$1).fold<double>(0, math.max)
          : values.isEmpty
              ? 0.0
              : values.map((e) => e.$1).reduce((a, b) => a + b) / values.length;

      final details =
          values.map((e) => e.$2).where((e) => e.isNotEmpty).join(' | ');
      return AchievementProgressSnapshot(
        achieved: achieved,
        progressPercent: achieved ? 1.0 : aggregatePercent.clamp(0.0, 1.0),
        progressText:
            details.isEmpty ? (achieved ? 'Done' : 'In progress') : details,
      );
    }

    final current =
        _currentValueForV1(achievement.condition.type, user, progress);
    final target = achievement.condition.targetValue <= 0
        ? 1
        : achievement.condition.targetValue;
    final percent = (current / target).clamp(0.0, 1.0);
    return AchievementProgressSnapshot(
      achieved: achieved,
      progressPercent: achieved ? 1.0 : percent,
      progressText: '${current.clamp(0, target)}/$target',
    );
  }

  bool _evaluateV1Condition({
    required AchievementType type,
    required int target,
    required UserModel user,
    required QuestProgress progress,
  }) {
    switch (type) {
      case AchievementType.questsCompleted:
        return user.questsCompleted >= target;
      case AchievementType.totalPoints:
        return user.totalPoints >= target;
      case AchievementType.perfectScore:
        return progress.totalAnswers > 0 &&
            progress.correctAnswers == progress.totalAnswers;
      case AchievementType.speedRun:
        return progress.duration.inMinutes <= target;
      case AchievementType.citiesVisited:
        return user.visitedCities.length >= target;
      case AchievementType.photosUploaded:
        return user.photosUploaded >= target;
      case AchievementType.reviewsLeft:
        return user.reviewsLeft >= target;
    }
  }

  int _currentValueForV1(
    AchievementType type,
    UserModel user,
    QuestProgress progress,
  ) {
    switch (type) {
      case AchievementType.questsCompleted:
        return user.questsCompleted;
      case AchievementType.totalPoints:
        return user.totalPoints;
      case AchievementType.perfectScore:
        return progress.totalAnswers > 0 &&
                progress.correctAnswers == progress.totalAnswers
            ? 1
            : 0;
      case AchievementType.speedRun:
        return progress.duration.inMinutes;
      case AchievementType.citiesVisited:
        return user.visitedCities.length;
      case AchievementType.photosUploaded:
        return user.photosUploaded;
      case AchievementType.reviewsLeft:
        return user.reviewsLeft;
    }
  }

  bool _evaluateV2Rule({
    required AchievementRule rule,
    required UserModel user,
    required QuestProgress progress,
  }) {
    switch (rule.type) {
      case AchievementRuleType.questsCompleted:
        return user.questsCompleted >= rule.targetValue;
      case AchievementRuleType.totalPoints:
        return user.totalPoints >= rule.targetValue;
      case AchievementRuleType.perfectScore:
        return progress.totalAnswers > 0 &&
            progress.correctAnswers == progress.totalAnswers;
      case AchievementRuleType.speedRun:
        return progress.duration.inMinutes <= rule.targetValue;
      case AchievementRuleType.citiesVisited:
        return user.visitedCities.length >= rule.targetValue;
      case AchievementRuleType.photosUploaded:
        return user.photosUploaded >= rule.targetValue;
      case AchievementRuleType.reviewsLeft:
        return user.reviewsLeft >= rule.targetValue;
      case AchievementRuleType.streakDays:
        return user.currentQuestStreakDays >= rule.targetValue;
      case AchievementRuleType.specificQuestCompleted:
        final questId = rule.questId?.trim();
        if (questId == null || questId.isEmpty) return false;
        return user.completedQuestIds.contains(questId) ||
            progress.questId == questId;
      case AchievementRuleType.allCitiesVisited:
        if (rule.cityIds.isNotEmpty) {
          return rule.cityIds.every(user.visitedCities.contains);
        }
        return user.visitedCities.length >= math.max(1, rule.targetValue);
      case AchievementRuleType.timeOfDay:
        final start = rule.startHour ?? 0;
        final end = rule.endHour ?? 24;
        final completedAt = progress.completedAt ?? DateTime.now();
        final hour = completedAt.hour;
        if (start == end) return true;
        if (start < end) {
          return hour >= start && hour < end;
        }
        return hour >= start || hour < end;
    }
  }

  (double, String) _progressForRule({
    required AchievementRule rule,
    required UserModel user,
    required QuestProgress progress,
  }) {
    switch (rule.type) {
      case AchievementRuleType.perfectScore:
      case AchievementRuleType.specificQuestCompleted:
      case AchievementRuleType.timeOfDay:
        final achieved =
            _evaluateV2Rule(rule: rule, user: user, progress: progress);
        return (achieved ? 1.0 : 0.0, achieved ? 'Done' : 'Pending');
      case AchievementRuleType.allCitiesVisited:
        if (rule.cityIds.isNotEmpty) {
          final matched =
              rule.cityIds.where(user.visitedCities.contains).length;
          final total = rule.cityIds.length;
          return (total == 0 ? 0.0 : matched / total, '$matched/$total cities');
        }
        final target = math.max(1, rule.targetValue);
        final current = user.visitedCities.length;
        return ((current / target).clamp(0.0, 1.0), '$current/$target cities');
      case AchievementRuleType.questsCompleted:
        return _asProgress(user.questsCompleted, rule.targetValue, 'quests');
      case AchievementRuleType.totalPoints:
        return _asProgress(user.totalPoints, rule.targetValue, 'pts');
      case AchievementRuleType.speedRun:
        final target = math.max(1, rule.targetValue);
        final current = progress.duration.inMinutes;
        return (
          current <= target ? 1.0 : (target / current).clamp(0.0, 1.0),
          '$current/$target min'
        );
      case AchievementRuleType.citiesVisited:
        return _asProgress(
            user.visitedCities.length, rule.targetValue, 'cities');
      case AchievementRuleType.photosUploaded:
        return _asProgress(user.photosUploaded, rule.targetValue, 'photos');
      case AchievementRuleType.reviewsLeft:
        return _asProgress(user.reviewsLeft, rule.targetValue, 'reviews');
      case AchievementRuleType.streakDays:
        return _asProgress(
            user.currentQuestStreakDays, rule.targetValue, 'day streak');
    }
  }

  (double, String) _asProgress(int current, int targetRaw, String suffix) {
    final target = math.max(1, targetRaw);
    return ((current / target).clamp(0.0, 1.0), '$current/$target $suffix');
  }
}
