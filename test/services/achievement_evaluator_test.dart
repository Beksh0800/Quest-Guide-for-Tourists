import 'package:flutter_test/flutter_test.dart';
import 'package:quest_guide/data/services/achievement_evaluator.dart';
import 'package:quest_guide/domain/models/achievement.dart';
import 'package:quest_guide/domain/models/quest_progress.dart';
import 'package:quest_guide/domain/models/user_model.dart';

void main() {
  const evaluator = AchievementEvaluator();

  UserModel makeUser({
    int questsCompleted = 0,
    int totalPoints = 0,
    int photosUploaded = 0,
    int reviewsLeft = 0,
    List<String> visitedCities = const <String>[],
    int currentQuestStreakDays = 0,
    List<String> completedQuestIds = const <String>[],
  }) {
    return UserModel(
      id: 'u1',
      name: 'Test',
      email: 'test@test.com',
      createdAt: DateTime(2025, 1, 1),
      questsCompleted: questsCompleted,
      totalPoints: totalPoints,
      photosUploaded: photosUploaded,
      reviewsLeft: reviewsLeft,
      visitedCities: visitedCities,
      currentQuestStreakDays: currentQuestStreakDays,
      completedQuestIds: completedQuestIds,
    );
  }

  QuestProgress makeProgress({
    int correctAnswers = 0,
    int totalAnswers = 0,
    String questId = 'q1',
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return QuestProgress(
      id: 'p1',
      userId: 'u1',
      questId: questId,
      status: QuestStatus.completed,
      currentLocationIndex: 3,
      earnedPoints: 200,
      correctAnswers: correctAnswers,
      totalAnswers: totalAnswers,
      completedTaskIds: const [],
      startedAt: startedAt ?? DateTime(2025, 1, 1, 10, 0),
      completedAt: completedAt ?? DateTime(2025, 1, 1, 11, 0),
    );
  }

  group('AchievementEvaluator V1', () {
    test('questsCompleted threshold', () {
      const achievement = Achievement(
        id: 'a1',
        title: 'First',
        description: 'Complete 1',
        condition: AchievementCondition(
          type: AchievementType.questsCompleted,
          targetValue: 1,
        ),
      );
      expect(
        evaluator.isAchieved(
          achievement: achievement,
          user: makeUser(questsCompleted: 1),
          progress: makeProgress(),
        ),
        isTrue,
      );
    });

    test('citiesVisited uses user metric', () {
      const achievement = Achievement(
        id: 'a5',
        title: 'Cities',
        description: 'Visit 3 cities',
        condition: AchievementCondition(
          type: AchievementType.citiesVisited,
          targetValue: 3,
        ),
      );
      expect(
        evaluator.isAchieved(
          achievement: achievement,
          user: makeUser(visitedCities: const ['A', 'B', 'C']),
          progress: makeProgress(),
        ),
        isTrue,
      );
    });
  });

  group('AchievementEvaluator V2', () {
    test('all operator requires all rules', () {
      const achievement = Achievement(
        id: 'v2_all',
        title: 'All',
        description: '',
        condition: AchievementCondition(
          type: AchievementType.questsCompleted,
          targetValue: 999,
        ),
        conditionV2: AchievementConditionV2(
          operatorType: AchievementRuleOperator.all,
          rules: [
            AchievementRule(
              type: AchievementRuleType.questsCompleted,
              targetValue: 2,
            ),
            AchievementRule(
              type: AchievementRuleType.streakDays,
              targetValue: 2,
            ),
          ],
        ),
      );

      expect(
        evaluator.isAchieved(
          achievement: achievement,
          user: makeUser(questsCompleted: 2, currentQuestStreakDays: 2),
          progress: makeProgress(),
        ),
        isTrue,
      );
    });

    test('any operator passes if any rule true', () {
      const achievement = Achievement(
        id: 'v2_any',
        title: 'Any',
        description: '',
        condition: AchievementCondition(
          type: AchievementType.totalPoints,
          targetValue: 999,
        ),
        conditionV2: AchievementConditionV2(
          operatorType: AchievementRuleOperator.any,
          rules: [
            AchievementRule(
              type: AchievementRuleType.totalPoints,
              targetValue: 1000,
            ),
            AchievementRule(
              type: AchievementRuleType.specificQuestCompleted,
              questId: 'q42',
            ),
          ],
        ),
      );

      expect(
        evaluator.isAchieved(
          achievement: achievement,
          user: makeUser(completedQuestIds: const ['q42']),
          progress: makeProgress(),
        ),
        isTrue,
      );
    });

    test('timeOfDay handles wrapped interval', () {
      const achievement = Achievement(
        id: 'night_owl',
        title: 'Night',
        description: '',
        condition: AchievementCondition(
          type: AchievementType.totalPoints,
          targetValue: 1,
        ),
        conditionV2: AchievementConditionV2(
          operatorType: AchievementRuleOperator.all,
          rules: [
            AchievementRule(
              type: AchievementRuleType.timeOfDay,
              startHour: 22,
              endHour: 6,
            ),
          ],
        ),
      );

      final progress = makeProgress(
        completedAt: DateTime(2025, 1, 1, 23, 30),
      );

      expect(
        evaluator.isAchieved(
          achievement: achievement,
          user: makeUser(),
          progress: progress,
        ),
        isTrue,
      );
    });

    test('evaluateProgress returns percent and text', () {
      const achievement = Achievement(
        id: 'progress',
        title: 'Progress',
        description: '',
        condition: AchievementCondition(
          type: AchievementType.questsCompleted,
          targetValue: 10,
        ),
      );

      final snapshot = evaluator.evaluateProgress(
        achievement: achievement,
        user: makeUser(questsCompleted: 4),
        progress: makeProgress(),
      );

      expect(snapshot.achieved, isFalse);
      expect(snapshot.progressPercent, closeTo(0.4, 0.001));
      expect(snapshot.progressText, '4/10');
    });
  });
}
