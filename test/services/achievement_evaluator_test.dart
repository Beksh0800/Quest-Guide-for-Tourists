import 'package:flutter_test/flutter_test.dart';
import 'package:quest_guide/data/services/achievement_evaluator.dart';
import 'package:quest_guide/domain/models/achievement.dart';
import 'package:quest_guide/domain/models/quest_progress.dart';
import 'package:quest_guide/domain/models/user_model.dart';

void main() {
  const evaluator = AchievementEvaluator();

  UserModel makeUser({int questsCompleted = 0, int totalPoints = 0}) {
    return UserModel(
      id: 'u1',
      name: 'Test',
      email: 'test@test.com',
      createdAt: DateTime(2025, 1, 1),
      questsCompleted: questsCompleted,
      totalPoints: totalPoints,
    );
  }

  QuestProgress makeProgress({
    int correctAnswers = 0,
    int totalAnswers = 0,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return QuestProgress(
      id: 'p1',
      userId: 'u1',
      questId: 'q1',
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

  group('AchievementEvaluator.isAchieved', () {
    test('questsCompleted — met threshold', () {
      const achievement = Achievement(
        id: 'a1',
        title: 'First',
        description: 'Complete 1',
        iconName: 'flag',
        colorValue: 0xFF000000,
        condition: AchievementCondition(
          type: AchievementType.questsCompleted,
          targetValue: 1,
        ),
      );
      final user = makeUser(questsCompleted: 1);
      final progress = makeProgress();

      expect(
          evaluator.isAchieved(
              achievement: achievement, user: user, progress: progress),
          isTrue);
    });

    test('questsCompleted — below threshold', () {
      const achievement = Achievement(
        id: 'a1',
        title: 'Explorer',
        description: 'Complete 5',
        iconName: 'explore',
        colorValue: 0xFF000000,
        condition: AchievementCondition(
          type: AchievementType.questsCompleted,
          targetValue: 5,
        ),
      );
      final user = makeUser(questsCompleted: 3);
      final progress = makeProgress();

      expect(
          evaluator.isAchieved(
              achievement: achievement, user: user, progress: progress),
          isFalse);
    });

    test('totalPoints — met threshold', () {
      const achievement = Achievement(
        id: 'a2',
        title: 'Score 100',
        description: 'Score 100',
        iconName: 'stars',
        colorValue: 0xFF000000,
        condition: AchievementCondition(
          type: AchievementType.totalPoints,
          targetValue: 100,
        ),
      );
      final user = makeUser(totalPoints: 150);
      final progress = makeProgress();

      expect(
          evaluator.isAchieved(
              achievement: achievement, user: user, progress: progress),
          isTrue);
    });

    test('totalPoints — below threshold', () {
      const achievement = Achievement(
        id: 'a2',
        title: 'Score 500',
        description: 'Score 500',
        iconName: 'stars',
        colorValue: 0xFF000000,
        condition: AchievementCondition(
          type: AchievementType.totalPoints,
          targetValue: 500,
        ),
      );
      final user = makeUser(totalPoints: 100);
      final progress = makeProgress();

      expect(
          evaluator.isAchieved(
              achievement: achievement, user: user, progress: progress),
          isFalse);
    });

    test('perfectScore — all correct', () {
      const achievement = Achievement(
        id: 'a3',
        title: 'Perfect',
        description: 'All correct',
        iconName: 'verified',
        colorValue: 0xFF000000,
        condition: AchievementCondition(
          type: AchievementType.perfectScore,
          targetValue: 1,
        ),
      );
      final user = makeUser();
      final progress = makeProgress(correctAnswers: 4, totalAnswers: 4);

      expect(
          evaluator.isAchieved(
              achievement: achievement, user: user, progress: progress),
          isTrue);
    });

    test('perfectScore — not all correct', () {
      const achievement = Achievement(
        id: 'a3',
        title: 'Perfect',
        description: 'All correct',
        iconName: 'verified',
        colorValue: 0xFF000000,
        condition: AchievementCondition(
          type: AchievementType.perfectScore,
          targetValue: 1,
        ),
      );
      final user = makeUser();
      final progress = makeProgress(correctAnswers: 3, totalAnswers: 4);

      expect(
          evaluator.isAchieved(
              achievement: achievement, user: user, progress: progress),
          isFalse);
    });

    test('perfectScore — no answers returns false', () {
      const achievement = Achievement(
        id: 'a3',
        title: 'Perfect',
        description: 'All correct',
        iconName: 'verified',
        colorValue: 0xFF000000,
        condition: AchievementCondition(
          type: AchievementType.perfectScore,
          targetValue: 1,
        ),
      );
      final user = makeUser();
      final progress = makeProgress(correctAnswers: 0, totalAnswers: 0);

      expect(
          evaluator.isAchieved(
              achievement: achievement, user: user, progress: progress),
          isFalse);
    });

    test('speedRun — completed within time', () {
      const achievement = Achievement(
        id: 'a4',
        title: 'Fast',
        description: 'Under 30 min',
        iconName: 'speed',
        colorValue: 0xFF000000,
        condition: AchievementCondition(
          type: AchievementType.speedRun,
          targetValue: 30,
        ),
      );
      final user = makeUser();
      final start = DateTime(2025, 1, 1, 10, 0);
      final end = DateTime(2025, 1, 1, 10, 25); // 25 minutes
      final progress = makeProgress(startedAt: start, completedAt: end);

      expect(
          evaluator.isAchieved(
              achievement: achievement, user: user, progress: progress),
          isTrue);
    });

    test('speedRun — over time', () {
      const achievement = Achievement(
        id: 'a4',
        title: 'Fast',
        description: 'Under 30 min',
        iconName: 'speed',
        colorValue: 0xFF000000,
        condition: AchievementCondition(
          type: AchievementType.speedRun,
          targetValue: 30,
        ),
      );
      final user = makeUser();
      final start = DateTime(2025, 1, 1, 10, 0);
      final end = DateTime(2025, 1, 1, 10, 45); // 45 minutes
      final progress = makeProgress(startedAt: start, completedAt: end);

      expect(
          evaluator.isAchieved(
              achievement: achievement, user: user, progress: progress),
          isFalse);
    });

    test('citiesVisited — always false (not implemented)', () {
      const achievement = Achievement(
        id: 'a5',
        title: 'Cities',
        description: 'Visit 3 cities',
        iconName: 'map',
        colorValue: 0xFF000000,
        condition: AchievementCondition(
          type: AchievementType.citiesVisited,
          targetValue: 3,
        ),
      );
      final user = makeUser(questsCompleted: 10);
      final progress = makeProgress();

      expect(
          evaluator.isAchieved(
              achievement: achievement, user: user, progress: progress),
          isFalse);
    });
  });
}
