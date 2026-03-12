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
    final target = achievement.condition.targetValue;

    switch (achievement.condition.type) {
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
      case AchievementType.photosUploaded:
        return false;
    }
  }
}
