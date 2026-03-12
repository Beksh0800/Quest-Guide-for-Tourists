import 'package:flutter_test/flutter_test.dart';
import 'package:quest_guide/domain/models/quest_task.dart';
import 'package:quest_guide/domain/models/quest_task_answer.dart';

void main() {
  group('QuestTaskAnswer.fromMap / toMap', () {
    test('roundtrip keeps cloud evidence fields', () {
      final now = DateTime(2026, 1, 2, 12, 30, 45);
      final original = QuestTaskAnswer(
        taskId: 'task_photo_1',
        taskType: TaskType.photo,
        selectedOptionIndex: null,
        textAnswer: null,
        evidencePath: 'local/evidence/task_photo_1.jpg',
        evidenceStatus: EvidenceStatus.uploaded,
        evidenceRemotePath:
            'quest_evidence/u1/q1/task_photo_1/1700000000000.jpg',
        evidenceRemoteUrl: 'https://example.com/evidence/task_photo_1.jpg',
        evidenceError: null,
        moderationStatus: ModerationStatus.rejected,
        moderationComment: 'Фото не соответствует заданию',
        moderatedAt: DateTime(2026, 1, 2, 12, 40),
        moderatedBy: 'admin@example.com',
        answeredAt: now,
      );

      final map = original.toMap();
      final restored = QuestTaskAnswer.fromMap('task_photo_1', map);

      expect(restored.taskId, original.taskId);
      expect(restored.taskType, TaskType.photo);
      expect(restored.evidencePath, original.evidencePath);
      expect(restored.evidenceStatus, EvidenceStatus.uploaded);
      expect(restored.evidenceRemotePath, original.evidenceRemotePath);
      expect(restored.evidenceRemoteUrl, original.evidenceRemoteUrl);
      expect(restored.evidenceError, isNull);
      expect(restored.moderationStatus, ModerationStatus.rejected);
      expect(restored.moderationComment, 'Фото не соответствует заданию');
      expect(restored.moderatedAt, DateTime(2026, 1, 2, 12, 40));
      expect(restored.moderatedBy, 'admin@example.com');
      expect(restored.answeredAt, now);
    });

    test('fromMap defaults taskType to quiz when unknown', () {
      final restored = QuestTaskAnswer.fromMap('task_1', {
        'taskType': 'unknown_type',
        'answeredAt': DateTime(2026, 1, 1).toIso8601String(),
      });

      expect(restored.taskType, TaskType.quiz);
    });

    test('fromMap applies backward compatible uploaded for legacy evidence',
        () {
      final restored = QuestTaskAnswer.fromMap('task_photo_legacy', {
        'taskType': 'photo',
        'evidencePath': 'local/evidence/legacy.jpg',
        'answeredAt': DateTime(2026, 1, 1).toIso8601String(),
      });

      expect(restored.evidenceStatus, EvidenceStatus.uploaded);
      expect(restored.evidencePath, 'local/evidence/legacy.jpg');
      expect(restored.moderationStatus, isNull);
    });

    test('fromMap keeps null status for non evidence task types', () {
      final restored = QuestTaskAnswer.fromMap('task_text_legacy', {
        'taskType': 'textInput',
        'textAnswer': 'answer',
        'answeredAt': DateTime(2026, 1, 1).toIso8601String(),
      });

      expect(restored.evidenceStatus, isNull);
      expect(restored.textAnswer, 'answer');
    });

    test(
        'fromMap sets pendingReview for cloud uploaded records without moderation fields',
        () {
      final restored = QuestTaskAnswer.fromMap('task_photo_cloud', {
        'taskType': 'photo',
        'evidencePath': 'local/evidence/cloud.jpg',
        'evidenceStatus': 'uploaded',
        'evidenceRemotePath': 'quest_evidence/u1/q1/task_photo_cloud/file.jpg',
        'answeredAt': DateTime(2026, 1, 1).toIso8601String(),
      });

      expect(restored.evidenceStatus, EvidenceStatus.uploaded);
      expect(restored.moderationStatus, ModerationStatus.pendingReview);
    });

    test('withEvidenceUploadUpdate resets moderation decision on new upload',
        () {
      final rejected = QuestTaskAnswer(
        taskId: 'task_photo_2',
        taskType: TaskType.photo,
        evidencePath: 'local/evidence/old.jpg',
        evidenceStatus: EvidenceStatus.uploaded,
        evidenceRemotePath: 'quest_evidence/u1/q1/task_photo_2/old.jpg',
        evidenceRemoteUrl: 'https://example.com/old.jpg',
        moderationStatus: ModerationStatus.rejected,
        moderationComment: 'Объект не в кадре',
        moderatedAt: DateTime(2026, 1, 3, 10, 0),
        moderatedBy: 'admin@old.com',
        answeredAt: DateTime(2026, 1, 3, 9, 59),
      );

      final updated = rejected.withEvidenceUploadUpdate(
        evidencePath: 'local/evidence/new.jpg',
        evidenceStatus: EvidenceStatus.uploaded,
        evidenceRemotePath: 'quest_evidence/u1/q1/task_photo_2/new.jpg',
        evidenceRemoteUrl: 'https://example.com/new.jpg',
        evidenceError: null,
        answeredAt: DateTime(2026, 1, 3, 11, 0),
      );

      expect(updated.evidencePath, 'local/evidence/new.jpg');
      expect(updated.moderationStatus, ModerationStatus.pendingReview);
      expect(updated.moderationComment, isNull);
      expect(updated.moderatedAt, isNull);
      expect(updated.moderatedBy, isNull);
    });
  });
}
