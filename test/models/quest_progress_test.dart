import 'package:flutter_test/flutter_test.dart';
import 'package:quest_guide/domain/models/quest_progress.dart';
import 'package:quest_guide/domain/models/quest_task.dart';
import 'package:quest_guide/domain/models/quest_task_answer.dart';

void main() {
  group('QuestProgress.fromMap / toMap', () {
    test('roundtrip preserves all fields', () {
      final now = DateTime(2025, 6, 15, 10, 30);
      final completedAt = DateTime(2025, 6, 15, 11, 45);

      final original = QuestProgress(
        id: 'p1',
        userId: 'u1',
        questId: 'q1',
        status: QuestStatus.completed,
        currentLocationIndex: 3,
        earnedPoints: 200,
        timeBonusPoints: 25,
        correctAnswers: 3,
        totalAnswers: 4,
        completedTaskIds: const ['t1', 't2', 't3'],
        taskAnswers: {
          't3': QuestTaskAnswer(
            taskId: 't3',
            taskType: TaskType.photo,
            evidencePath: 'local/evidence/t3.jpg',
            evidenceStatus: EvidenceStatus.uploaded,
            evidenceRemotePath: 'quest_evidence/u1/q1/t3/1700000000000.jpg',
            evidenceRemoteUrl: 'https://example.com/evidence/t3.jpg',
            moderationStatus: ModerationStatus.pendingReview,
            answeredAt: DateTime(2025, 6, 15, 11, 0),
          ),
        },
        startedAt: now,
        lastUpdatedAt: now,
        completedAt: completedAt,
      );

      final map = original.toMap();
      final restored = QuestProgress.fromMap(map, 'p1');

      expect(restored.id, original.id);
      expect(restored.userId, original.userId);
      expect(restored.questId, original.questId);
      expect(restored.status, original.status);
      expect(restored.currentLocationIndex, original.currentLocationIndex);
      expect(restored.earnedPoints, original.earnedPoints);
      expect(restored.timeBonusPoints, original.timeBonusPoints);
      expect(restored.correctAnswers, original.correctAnswers);
      expect(restored.totalAnswers, original.totalAnswers);
      expect(restored.completedTaskIds, original.completedTaskIds);
      expect(restored.taskAnswers['t3']?.evidencePath, 'local/evidence/t3.jpg');
      expect(
          restored.taskAnswers['t3']?.evidenceStatus, EvidenceStatus.uploaded);
      expect(
        restored.taskAnswers['t3']?.evidenceRemotePath,
        'quest_evidence/u1/q1/t3/1700000000000.jpg',
      );
      expect(
        restored.taskAnswers['t3']?.evidenceRemoteUrl,
        'https://example.com/evidence/t3.jpg',
      );
      expect(
        restored.taskAnswers['t3']?.moderationStatus,
        ModerationStatus.pendingReview,
      );
    });

    test('fromMap handles defaults for missing fields', () {
      final progress = QuestProgress.fromMap({
        'userId': 'u1',
        'questId': 'q1',
        'startedAt': DateTime.now().toIso8601String(),
      }, 'p2');

      expect(progress.id, 'p2');
      expect(progress.status, QuestStatus.inProgress);
      expect(progress.currentLocationIndex, 0);
      expect(progress.earnedPoints, 0);
      expect(progress.timeBonusPoints, 0);
      expect(progress.completedTaskIds, isEmpty);
      expect(progress.taskAnswers, isEmpty);
    });

    test('fromMap parses dynamic map taskAnswers', () {
      final progress = QuestProgress.fromMap({
        'userId': 'u1',
        'questId': 'q1',
        'startedAt': DateTime.now().toIso8601String(),
        'taskAnswers': {
          'task_photo_1': {
            'taskType': 'photo',
            'evidencePath': 'local/evidence/photo.jpg',
            'evidenceStatus': 'uploaded',
            'evidenceRemotePath':
                'quest_evidence/u1/q1/task_photo_1/1700000000000.jpg',
            'evidenceRemoteUrl':
                'https://example.com/evidence/task_photo_1.jpg',
            'answeredAt': DateTime.now().toIso8601String(),
          },
        },
      }, 'p_dynamic');

      expect(progress.taskAnswers.containsKey('task_photo_1'), isTrue);
      expect(
        progress.taskAnswers['task_photo_1']?.taskType,
        TaskType.photo,
      );
      expect(
        progress.taskAnswers['task_photo_1']?.evidenceStatus,
        EvidenceStatus.uploaded,
      );
      expect(
        progress.taskAnswers['task_photo_1']?.evidenceRemotePath,
        'quest_evidence/u1/q1/task_photo_1/1700000000000.jpg',
      );
      expect(
        progress.taskAnswers['task_photo_1']?.evidenceRemoteUrl,
        'https://example.com/evidence/task_photo_1.jpg',
      );
      expect(
        progress.taskAnswers['task_photo_1']?.moderationStatus,
        ModerationStatus.pendingReview,
      );
    });

    test('fromMap keeps backward compatibility for legacy evidence records',
        () {
      final progress = QuestProgress.fromMap({
        'userId': 'u1',
        'questId': 'q1',
        'startedAt': DateTime.now().toIso8601String(),
        'taskAnswers': {
          'legacy_photo_task': {
            'taskType': 'photo',
            'evidencePath': 'local/evidence/legacy.jpg',
            'answeredAt': DateTime.now().toIso8601String(),
          },
        },
      }, 'p_legacy');

      expect(
        progress.taskAnswers['legacy_photo_task']?.evidenceStatus,
        EvidenceStatus.uploaded,
      );
    });
  });

  group('QuestProgress.copyWith', () {
    test('copies with updated fields', () {
      final original = QuestProgress(
        id: 'p1',
        userId: 'u1',
        questId: 'q1',
        status: QuestStatus.inProgress,
        currentLocationIndex: 0,
        earnedPoints: 0,
        correctAnswers: 0,
        totalAnswers: 0,
        completedTaskIds: const [],
        startedAt: DateTime(2025, 1, 1),
      );

      final updated = original.copyWith(
        status: QuestStatus.completed,
        currentLocationIndex: 3,
        earnedPoints: 250,
        timeBonusPoints: 30,
        correctAnswers: 3,
        totalAnswers: 4,
        completedTaskIds: ['t1', 't2', 't3'],
        taskAnswers: {
          't3': QuestTaskAnswer(
            taskId: 't3',
            taskType: TaskType.photo,
            evidencePath: 'local/evidence/t3.jpg',
            answeredAt: DateTime(2025, 1, 1, 1),
          ),
        },
      );

      expect(updated.status, QuestStatus.completed);
      expect(updated.currentLocationIndex, 3);
      expect(updated.earnedPoints, 250);
      expect(updated.timeBonusPoints, 30);
      expect(updated.correctAnswers, 3);
      expect(updated.totalAnswers, 4);
      expect(updated.completedTaskIds, ['t1', 't2', 't3']);
      expect(updated.taskAnswers['t3']?.evidencePath, 'local/evidence/t3.jpg');
      // Unchanged fields
      expect(updated.id, 'p1');
      expect(updated.userId, 'u1');
      expect(updated.questId, 'q1');
    });

    test('copyWith preserves completedTaskIds when not provided', () {
      final original = QuestProgress(
        id: 'p1',
        userId: 'u1',
        questId: 'q1',
        status: QuestStatus.inProgress,
        currentLocationIndex: 0,
        earnedPoints: 0,
        correctAnswers: 0,
        totalAnswers: 0,
        completedTaskIds: const ['t1', 't2'],
        startedAt: DateTime(2025, 1, 1),
      );

      final updated = original.copyWith(earnedPoints: 100);
      expect(updated.completedTaskIds, ['t1', 't2']);
      expect(updated.timeBonusPoints, 0);
      expect(updated.taskAnswers, isEmpty);
    });
  });

  group('QuestProgress.duration', () {
    test('returns duration between start and completedAt', () {
      final start = DateTime(2025, 1, 1, 10, 0);
      final end = DateTime(2025, 1, 1, 11, 30);

      final progress = QuestProgress(
        id: 'p1',
        userId: 'u1',
        questId: 'q1',
        status: QuestStatus.completed,
        currentLocationIndex: 3,
        earnedPoints: 250,
        correctAnswers: 3,
        totalAnswers: 4,
        completedTaskIds: const [],
        startedAt: start,
        completedAt: end,
      );

      expect(progress.duration, const Duration(hours: 1, minutes: 30));
    });

    test('returns non-zero duration when not completed (uses DateTime.now)',
        () {
      final progress = QuestProgress(
        id: 'p1',
        userId: 'u1',
        questId: 'q1',
        status: QuestStatus.inProgress,
        currentLocationIndex: 0,
        earnedPoints: 0,
        correctAnswers: 0,
        totalAnswers: 0,
        completedTaskIds: const [],
        startedAt: DateTime(2025, 1, 1),
      );

      // duration uses DateTime.now() when completedAt is null
      expect(progress.duration.inSeconds, greaterThan(0));
    });
  });

  group('QuestProgress.accuracy', () {
    test('returns correct percentage', () {
      final progress = QuestProgress(
        id: 'p1',
        userId: 'u1',
        questId: 'q1',
        status: QuestStatus.completed,
        currentLocationIndex: 3,
        earnedPoints: 200,
        correctAnswers: 3,
        totalAnswers: 4,
        completedTaskIds: const [],
        startedAt: DateTime(2025, 1, 1),
      );

      expect(progress.accuracy, 0.75);
    });

    test('returns 0 when no answers', () {
      final progress = QuestProgress(
        id: 'p1',
        userId: 'u1',
        questId: 'q1',
        status: QuestStatus.inProgress,
        currentLocationIndex: 0,
        earnedPoints: 0,
        correctAnswers: 0,
        totalAnswers: 0,
        completedTaskIds: const [],
        startedAt: DateTime(2025, 1, 1),
      );

      expect(progress.accuracy, 0.0);
    });
  });
}
