import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quest_guide/data/repositories/progress_repository.dart';
import 'package:quest_guide/domain/models/quest_progress.dart';
import 'package:quest_guide/domain/models/quest_task.dart';
import 'package:quest_guide/domain/models/quest_task_answer.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late ProgressRepository repo;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repo = ProgressRepository(firestore: fakeFirestore);
  });

  group('ProgressRepository', () {
    test('startQuest creates a progress document', () async {
      final progress = await repo.startQuest(
        userId: 'u1',
        questId: 'q1',
      );

      expect(progress.userId, 'u1');
      expect(progress.questId, 'q1');
      expect(progress.status, QuestStatus.inProgress);
      expect(progress.currentLocationIndex, 0);
      expect(progress.earnedPoints, 0);

      // Verify it's in Firestore
      final doc =
          await fakeFirestore.collection('progress').doc(progress.id).get();
      expect(doc.exists, isTrue);
    });

    test('startQuest with initialLocationIndex', () async {
      final progress = await repo.startQuest(
        userId: 'u1',
        questId: 'q1',
        initialLocationIndex: 2,
      );

      expect(progress.currentLocationIndex, 2);
    });

    test('getActiveProgress returns active progress', () async {
      await repo.startQuest(userId: 'u1', questId: 'q1');

      final active = await repo.getActiveProgress('u1', 'q1');
      expect(active, isNotNull);
      expect(active!.userId, 'u1');
      expect(active.questId, 'q1');
      expect(active.status, QuestStatus.inProgress);
    });

    test('getActiveProgress returns null when no active progress', () async {
      final active = await repo.getActiveProgress('u1', 'q_nonexistent');
      expect(active, isNull);
    });

    test('updateProgress persists changes', () async {
      final progress = await repo.startQuest(userId: 'u1', questId: 'q1');

      final updated = progress.copyWith(
        currentLocationIndex: 2,
        earnedPoints: 100,
        correctAnswers: 2,
        totalAnswers: 3,
        taskAnswers: {
          'task_photo': QuestTaskAnswer(
            taskId: 'task_photo',
            taskType: TaskType.photo,
            evidencePath: 'local/evidence/photo.jpg',
            evidenceStatus: EvidenceStatus.uploaded,
            evidenceRemotePath:
                'quest_evidence/u1/q1/task_photo/1700000000000.jpg',
            evidenceRemoteUrl: 'https://example.com/evidence/task_photo.jpg',
            moderationStatus: ModerationStatus.pendingReview,
            answeredAt: DateTime(2026, 1, 1, 10),
          ),
        },
      );
      await repo.updateProgress(updated);

      final fetched = await repo.getProgressById(progress.id);
      expect(fetched, isNotNull);
      expect(fetched!.currentLocationIndex, 2);
      expect(fetched.earnedPoints, 100);
      expect(fetched.correctAnswers, 2);
      expect(fetched.totalAnswers, 3);
      expect(fetched.taskAnswers['task_photo']?.evidencePath,
          'local/evidence/photo.jpg');
      expect(
        fetched.taskAnswers['task_photo']?.evidenceStatus,
        EvidenceStatus.uploaded,
      );
      expect(
        fetched.taskAnswers['task_photo']?.evidenceRemotePath,
        'quest_evidence/u1/q1/task_photo/1700000000000.jpg',
      );
      expect(
        fetched.taskAnswers['task_photo']?.evidenceRemoteUrl,
        'https://example.com/evidence/task_photo.jpg',
      );
      expect(
        fetched.taskAnswers['task_photo']?.moderationStatus,
        ModerationStatus.pendingReview,
      );
    });

    test('getEvidenceStatusesForQuest returns photo/findObject records only',
        () async {
      final progress = await repo.startQuest(userId: 'u1', questId: 'q1');

      final updated = progress.copyWith(
        taskAnswers: {
          'task_photo': QuestTaskAnswer(
            taskId: 'task_photo',
            taskType: TaskType.photo,
            evidencePath: 'local/photo.jpg',
            evidenceStatus: EvidenceStatus.pending,
            evidenceRemotePath: null,
            evidenceRemoteUrl: null,
            evidenceError: 'cloud-unavailable',
            answeredAt: DateTime(2026, 1, 1, 10, 0),
          ),
          'task_find': QuestTaskAnswer(
            taskId: 'task_find',
            taskType: TaskType.findObject,
            evidencePath: 'local/find.jpg',
            evidenceStatus: EvidenceStatus.uploaded,
            evidenceRemotePath:
                'quest_evidence/u1/q1/task_find/1700000000000.jpg',
            evidenceRemoteUrl: 'https://example.com/evidence/task_find.jpg',
            moderationStatus: ModerationStatus.pendingReview,
            answeredAt: DateTime(2026, 1, 1, 10, 5),
          ),
          'task_text': QuestTaskAnswer(
            taskId: 'task_text',
            taskType: TaskType.textInput,
            textAnswer: 'answer',
            answeredAt: DateTime(2026, 1, 1, 9, 55),
          ),
        },
      );

      await repo.updateProgress(updated);

      final records = await repo.getEvidenceStatusesForQuest(
        questId: 'q1',
        taskIds: {'task_photo', 'task_find', 'task_text'},
      );

      expect(records.length, 2);
      expect(records.first.taskId, 'task_find');
      expect(records.first.evidenceStatus, EvidenceStatus.uploaded);
      expect(records.first.moderationStatus, ModerationStatus.pendingReview);
      expect(records.last.taskId, 'task_photo');
      expect(records.last.evidenceStatus, EvidenceStatus.pending);
    });

    test('getEvidenceStatusesForQuest returns empty when no evidence answers',
        () async {
      await repo.startQuest(userId: 'u1', questId: 'q_empty');

      final records =
          await repo.getEvidenceStatusesForQuest(questId: 'q_empty');

      expect(records, isEmpty);
    });

    test(
        'getModerationQueue returns only uploaded pendingReview evidence tasks',
        () async {
      final progress = await repo.startQuest(userId: 'u1', questId: 'q1');

      await repo.updateProgress(
        progress.copyWith(
          taskAnswers: {
            'task_pending': QuestTaskAnswer(
              taskId: 'task_pending',
              taskType: TaskType.photo,
              evidencePath: 'local/pending.jpg',
              evidenceStatus: EvidenceStatus.uploaded,
              evidenceRemotePath: 'quest_evidence/u1/q1/task_pending/file.jpg',
              evidenceRemoteUrl: 'https://example.com/pending.jpg',
              moderationStatus: ModerationStatus.pendingReview,
              answeredAt: DateTime(2026, 1, 1, 11, 0),
            ),
            'task_approved': QuestTaskAnswer(
              taskId: 'task_approved',
              taskType: TaskType.findObject,
              evidencePath: 'local/approved.jpg',
              evidenceStatus: EvidenceStatus.uploaded,
              evidenceRemotePath: 'quest_evidence/u1/q1/task_approved/file.jpg',
              evidenceRemoteUrl: 'https://example.com/approved.jpg',
              moderationStatus: ModerationStatus.approved,
              answeredAt: DateTime(2026, 1, 1, 10, 0),
            ),
            'task_failed': QuestTaskAnswer(
              taskId: 'task_failed',
              taskType: TaskType.photo,
              evidencePath: 'local/failed.jpg',
              evidenceStatus: EvidenceStatus.failed,
              evidenceRemotePath: null,
              moderationStatus: null,
              answeredAt: DateTime(2026, 1, 1, 9, 0),
            ),
            'task_text': QuestTaskAnswer(
              taskId: 'task_text',
              taskType: TaskType.textInput,
              textAnswer: 'ok',
              answeredAt: DateTime(2026, 1, 1, 12, 0),
            ),
          },
        ),
      );

      final queue = await repo.getModerationQueue(questId: 'q1');

      expect(queue.length, 1);
      expect(queue.first.taskId, 'task_pending');
      expect(queue.first.moderationStatus, ModerationStatus.pendingReview);
      expect(queue.first.evidenceStatus, EvidenceStatus.uploaded);
    });

    test('approveEvidence updates moderation fields', () async {
      final progress = await repo.startQuest(userId: 'u1', questId: 'q1');
      await repo.updateProgress(
        progress.copyWith(
          taskAnswers: {
            'task_photo': QuestTaskAnswer(
              taskId: 'task_photo',
              taskType: TaskType.photo,
              evidencePath: 'local/photo.jpg',
              evidenceStatus: EvidenceStatus.uploaded,
              evidenceRemotePath: 'quest_evidence/u1/q1/task_photo/file.jpg',
              evidenceRemoteUrl: 'https://example.com/photo.jpg',
              moderationStatus: ModerationStatus.pendingReview,
              answeredAt: DateTime(2026, 1, 1, 12, 0),
            ),
          },
        ),
      );

      final ok = await repo.approveEvidence(
        progressId: progress.id,
        taskId: 'task_photo',
        moderatedBy: 'admin@example.com',
      );

      expect(ok, isTrue);

      final updated = await repo.getProgressById(progress.id);
      final answer = updated!.taskAnswers['task_photo'];
      expect(answer, isNotNull);
      expect(answer!.moderationStatus, ModerationStatus.approved);
      expect(answer.moderationComment, isNull);
      expect(answer.moderatedBy, 'admin@example.com');
      expect(answer.moderatedAt, isNotNull);
    });

    test('rejectEvidence stores moderation comment', () async {
      final progress = await repo.startQuest(userId: 'u1', questId: 'q1');
      await repo.updateProgress(
        progress.copyWith(
          taskAnswers: {
            'task_photo': QuestTaskAnswer(
              taskId: 'task_photo',
              taskType: TaskType.photo,
              evidencePath: 'local/photo.jpg',
              evidenceStatus: EvidenceStatus.uploaded,
              evidenceRemotePath: 'quest_evidence/u1/q1/task_photo/file.jpg',
              evidenceRemoteUrl: 'https://example.com/photo.jpg',
              moderationStatus: ModerationStatus.pendingReview,
              answeredAt: DateTime(2026, 1, 1, 12, 0),
            ),
          },
        ),
      );

      final ok = await repo.rejectEvidence(
        progressId: progress.id,
        taskId: 'task_photo',
        comment: 'Фото размыто',
        moderatedBy: 'admin@example.com',
      );

      expect(ok, isTrue);

      final updated = await repo.getProgressById(progress.id);
      final answer = updated!.taskAnswers['task_photo'];
      expect(answer, isNotNull);
      expect(answer!.moderationStatus, ModerationStatus.rejected);
      expect(answer.moderationComment, 'Фото размыто');
      expect(answer.moderatedBy, 'admin@example.com');
      expect(answer.moderatedAt, isNotNull);
    });

    test('rejectEvidence throws on empty comment', () async {
      expect(
        () => repo.rejectEvidence(
          progressId: 'p',
          taskId: 't',
          comment: '   ',
          moderatedBy: 'admin@example.com',
        ),
        throwsArgumentError,
      );
    });

    test('approveEvidence returns false when status is not pendingReview',
        () async {
      final progress = await repo.startQuest(userId: 'u1', questId: 'q1');
      await repo.updateProgress(
        progress.copyWith(
          taskAnswers: {
            'task_photo': QuestTaskAnswer(
              taskId: 'task_photo',
              taskType: TaskType.photo,
              evidencePath: 'local/photo.jpg',
              evidenceStatus: EvidenceStatus.uploaded,
              evidenceRemotePath: 'quest_evidence/u1/q1/task_photo/file.jpg',
              moderationStatus: ModerationStatus.approved,
              answeredAt: DateTime(2026, 1, 1, 12, 0),
            ),
          },
        ),
      );

      final ok = await repo.approveEvidence(
        progressId: progress.id,
        taskId: 'task_photo',
        moderatedBy: 'admin@example.com',
      );

      expect(ok, isFalse);
    });

    test('completeQuest marks progress as completed', () async {
      final progress = await repo.startQuest(userId: 'u1', questId: 'q1');

      final result = await repo.completeQuest(
        progressId: progress.id,
        finalPoints: 250,
        timeBonusPoints: 20,
        correctAnswers: 4,
        totalAnswers: 5,
        completedTaskIds: ['t1', 't2', 't3', 't4'],
        finalLocationIndex: 4,
      );

      expect(result, isTrue);

      final fetched = await repo.getProgressById(progress.id);
      expect(fetched!.status, QuestStatus.completed);
      expect(fetched.earnedPoints, 250);
      expect(fetched.timeBonusPoints, 20);
      expect(fetched.correctAnswers, 4);
      expect(fetched.completedAt, isNotNull);
    });

    test('completeQuest is idempotent — second call returns false', () async {
      final progress = await repo.startQuest(userId: 'u1', questId: 'q1');

      await repo.completeQuest(
        progressId: progress.id,
        finalPoints: 250,
        timeBonusPoints: 25,
        correctAnswers: 4,
        totalAnswers: 5,
        completedTaskIds: ['t1', 't2', 't3', 't4'],
        finalLocationIndex: 4,
      );

      final secondResult = await repo.completeQuest(
        progressId: progress.id,
        finalPoints: 300,
        timeBonusPoints: 30,
        correctAnswers: 5,
        totalAnswers: 5,
        completedTaskIds: ['t1', 't2', 't3', 't4', 't5'],
        finalLocationIndex: 5,
      );

      expect(secondResult, isFalse);
    });

    test('getCompletedQuests returns only completed', () async {
      // Start two quests
      final p1 = await repo.startQuest(userId: 'u1', questId: 'q1');
      await repo.startQuest(userId: 'u1', questId: 'q2');

      // Complete only one
      await repo.completeQuest(
        progressId: p1.id,
        finalPoints: 100,
        timeBonusPoints: 10,
        correctAnswers: 2,
        totalAnswers: 3,
        completedTaskIds: ['t1', 't2'],
        finalLocationIndex: 2,
      );

      final completed = await repo.getCompletedQuests('u1');
      expect(completed.length, 1);
      expect(completed.first.questId, 'q1');
    });

    test('getUserHistory returns all progress entries', () async {
      await repo.startQuest(userId: 'u1', questId: 'q1');
      await repo.startQuest(userId: 'u1', questId: 'q2');
      await repo.startQuest(userId: 'u2', questId: 'q3'); // different user

      final history = await repo.getUserHistory('u1');
      expect(history.length, 2);
    });

    test('getProgressById returns null for nonexistent', () async {
      final result = await repo.getProgressById('nonexistent');
      expect(result, isNull);
    });

    test('watchProgress emits updates', () async {
      final progress = await repo.startQuest(userId: 'u1', questId: 'q1');

      final stream = repo.watchProgress(progress.id);
      final first = await stream.first;
      expect(first, isNotNull);
      expect(first!.userId, 'u1');
    });
  });
}
