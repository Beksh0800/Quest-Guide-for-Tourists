import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quest_guide/data/repositories/user_repository.dart';
import 'package:quest_guide/data/services/achievement_evaluator.dart';
import 'package:quest_guide/domain/models/achievement.dart';
import 'package:quest_guide/domain/models/quest_progress.dart';

class AchievementService {
  final FirebaseFirestore _firestore;
  final UserRepository _userRepository;
  final AchievementEvaluator _evaluator;

  AchievementService({
    FirebaseFirestore? firestore,
    UserRepository? userRepository,
    AchievementEvaluator? evaluator,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _userRepository = userRepository ?? UserRepository(),
        _evaluator = evaluator ?? const AchievementEvaluator();

  Future<List<String>> evaluateAndAward({
    required String userId,
    required QuestProgress progress,
  }) async {
    final user = await _userRepository.getUserById(userId);
    if (user == null) return const [];

    final snap = await _firestore.collection('achievements').get();
    final achievements =
        snap.docs.map((d) => Achievement.fromMap(d.data(), d.id)).toList();

    final awarded = <String>[];
    for (final achievement in achievements) {
      final alreadyEarned = user.earnedBadgeIds.contains(achievement.id);
      if (alreadyEarned) continue;

      final achieved = _evaluator.isAchieved(
        achievement: achievement,
        user: user,
        progress: progress,
      );

      if (achieved) {
        await _userRepository.addBadge(userId, achievement.id);
        awarded.add(achievement.id);
      }
    }

    return awarded;
  }
}
