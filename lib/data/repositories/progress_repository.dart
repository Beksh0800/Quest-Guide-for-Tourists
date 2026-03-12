import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quest_guide/domain/models/quest_progress.dart';
import 'package:quest_guide/domain/models/quest_task_answer.dart';
import 'package:quest_guide/domain/models/quest_task.dart';

/// Read-only запись по evidence для admin moderation foundation (v1).
class QuestEvidenceStatusRecord {
  final String progressId;
  final String userId;
  final String questId;
  final String taskId;
  final TaskType taskType;
  final EvidenceStatus? evidenceStatus;
  final String? evidencePath;
  final String? evidenceRemotePath;
  final String? evidenceRemoteUrl;
  final String? evidenceError;
  final ModerationStatus? moderationStatus;
  final String? moderationComment;
  final DateTime? moderatedAt;
  final String? moderatedBy;
  final DateTime answeredAt;
  final DateTime progressUpdatedAt;

  const QuestEvidenceStatusRecord({
    required this.progressId,
    required this.userId,
    required this.questId,
    required this.taskId,
    required this.taskType,
    required this.evidenceStatus,
    required this.evidencePath,
    required this.evidenceRemotePath,
    required this.evidenceRemoteUrl,
    required this.evidenceError,
    required this.moderationStatus,
    required this.moderationComment,
    required this.moderatedAt,
    required this.moderatedBy,
    required this.answeredAt,
    required this.progressUpdatedAt,
  });
}

/// Элемент очереди moderation для evidence-задач.
class QuestModerationQueueItem {
  final String progressId;
  final String userId;
  final String questId;
  final String taskId;
  final TaskType taskType;
  final EvidenceStatus? evidenceStatus;
  final ModerationStatus moderationStatus;
  final String? evidencePath;
  final String? evidenceRemotePath;
  final String? evidenceRemoteUrl;
  final DateTime answeredAt;
  final DateTime progressUpdatedAt;

  const QuestModerationQueueItem({
    required this.progressId,
    required this.userId,
    required this.questId,
    required this.taskId,
    required this.taskType,
    required this.evidenceStatus,
    required this.moderationStatus,
    required this.evidencePath,
    required this.evidenceRemotePath,
    required this.evidenceRemoteUrl,
    required this.answeredAt,
    required this.progressUpdatedAt,
  });
}

/// Репозиторий для прогресса прохождения квестов
class ProgressRepository {
  final FirebaseFirestore _firestore;

  static final Map<String, QuestProgress> _localStore = {};
  static final Map<String, StreamController<QuestProgress?>> _localControllers =
      {};

  ProgressRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _progressRef =>
      _firestore.collection('progress');

  StreamController<QuestProgress?> _localController(String progressId) {
    return _localControllers.putIfAbsent(
      progressId,
      () => StreamController<QuestProgress?>.broadcast(),
    );
  }

  void _emitLocal(QuestProgress progress) {
    _localStore[progress.id] = progress;
    _localController(progress.id).add(progress);
  }

  /// Начать квест — создать запись прогресса
  Future<QuestProgress> startQuest({
    required String userId,
    required String questId,
    int initialLocationIndex = 0,
  }) async {
    return _runWithFallback(
      remote: () async {
        final doc = _progressRef.doc();
        final now = DateTime.now();
        final progress = QuestProgress(
          id: doc.id,
          userId: userId,
          questId: questId,
          currentLocationIndex: initialLocationIndex,
          startedAt: now,
          lastUpdatedAt: now,
        );
        await doc.set(progress.toMap());
        _emitLocal(progress);
        return progress;
      },
      local: () async {
        final now = DateTime.now();
        final progress = QuestProgress(
          id: 'local_${now.microsecondsSinceEpoch}_${_localStore.length}',
          userId: userId,
          questId: questId,
          currentLocationIndex: initialLocationIndex,
          startedAt: now,
          lastUpdatedAt: now,
        );
        _emitLocal(progress);
        return progress;
      },
    );
  }

  /// Обновить прогресс
  Future<void> updateProgress(QuestProgress progress) async {
    await _runWithFallback<void>(
      remote: () async {
        final updated = progress.copyWith(lastUpdatedAt: DateTime.now());
        await _progressRef.doc(progress.id).set(
              updated.toMap(),
              SetOptions(merge: true),
            );
        _emitLocal(updated);
      },
      local: () async {
        final updated = progress.copyWith(lastUpdatedAt: DateTime.now());
        _emitLocal(updated);
      },
    );
  }

  /// Завершить квест
  Future<bool> completeQuest({
    required String progressId,
    required int finalPoints,
    required int timeBonusPoints,
    required int correctAnswers,
    required int totalAnswers,
    required List<String> completedTaskIds,
    required int finalLocationIndex,
  }) async {
    return _runWithFallback(
      remote: () async {
        final result = await _firestore.runTransaction((transaction) async {
          final ref = _progressRef.doc(progressId);
          final doc = await transaction.get(ref);
          if (!doc.exists) return false;

          final current = QuestProgress.fromMap(doc.data()!, doc.id);
          if (current.status == QuestStatus.completed) return false;

          final now = DateTime.now().toIso8601String();
          transaction.update(ref, {
            'status': QuestStatus.completed.name,
            'earnedPoints': finalPoints,
            'timeBonusPoints': timeBonusPoints,
            'correctAnswers': correctAnswers,
            'totalAnswers': totalAnswers,
            'completedTaskIds': completedTaskIds,
            'currentLocationIndex': finalLocationIndex,
            'completedAt': now,
            'lastUpdatedAt': now,
          });
          return true;
        });

        if (result) {
          final updated = await getProgressById(progressId);
          if (updated != null) {
            _emitLocal(updated);
          }
        }

        return result;
      },
      local: () async {
        final current = _localStore[progressId];
        if (current == null) return false;
        if (current.status == QuestStatus.completed) return false;

        final updated = current.copyWith(
          status: QuestStatus.completed,
          earnedPoints: finalPoints,
          timeBonusPoints: timeBonusPoints,
          correctAnswers: correctAnswers,
          totalAnswers: totalAnswers,
          completedTaskIds: completedTaskIds,
          currentLocationIndex: finalLocationIndex,
          completedAt: DateTime.now(),
          lastUpdatedAt: DateTime.now(),
        );
        _emitLocal(updated);
        return true;
      },
    );
  }

  /// Получить активный прогресс пользователя по квесту
  Future<QuestProgress?> getActiveProgress(
      String userId, String questId) async {
    return _runWithFallback(
      remote: () async {
        final snapshot = await _progressRef
            .where('userId', isEqualTo: userId)
            .where('questId', isEqualTo: questId)
            .where('status', isEqualTo: QuestStatus.inProgress.name)
            .orderBy('startedAt', descending: true)
            .limit(1)
            .get();

        if (snapshot.docs.isEmpty) return null;
        final doc = snapshot.docs.first;
        final progress = QuestProgress.fromMap(doc.data(), doc.id);
        _emitLocal(progress);
        return progress;
      },
      local: () async {
        final candidates = _localStore.values
            .where(
              (progress) =>
                  progress.userId == userId &&
                  progress.questId == questId &&
                  progress.status == QuestStatus.inProgress,
            )
            .toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
        return candidates.isEmpty ? null : candidates.first;
      },
    );
  }

  /// Получить историю завершённых квестов
  Future<List<QuestProgress>> getCompletedQuests(String userId) async {
    return _runWithFallback(
      remote: () async {
        final snapshot = await _progressRef
            .where('userId', isEqualTo: userId)
            .where('status', isEqualTo: QuestStatus.completed.name)
            .orderBy('completedAt', descending: true)
            .get();

        final result = snapshot.docs
            .map((doc) => QuestProgress.fromMap(doc.data(), doc.id))
            .toList();
        for (final progress in result) {
          _emitLocal(progress);
        }
        return result;
      },
      local: () async {
        final completed = _localStore.values
            .where(
              (progress) =>
                  progress.userId == userId &&
                  progress.status == QuestStatus.completed,
            )
            .toList()
          ..sort((a, b) {
            final completedA = a.completedAt ?? a.lastUpdatedAt;
            final completedB = b.completedAt ?? b.lastUpdatedAt;
            return completedB.compareTo(completedA);
          });
        return completed;
      },
    );
  }

  /// Получить всю историю пользователя
  Future<List<QuestProgress>> getUserHistory(String userId) async {
    return _runWithFallback(
      remote: () async {
        final snapshot = await _progressRef
            .where('userId', isEqualTo: userId)
            .orderBy('startedAt', descending: true)
            .get();

        final result = snapshot.docs
            .map((doc) => QuestProgress.fromMap(doc.data(), doc.id))
            .toList();
        for (final progress in result) {
          _emitLocal(progress);
        }
        return result;
      },
      local: () async {
        final history = _localStore.values
            .where((progress) => progress.userId == userId)
            .toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
        return history;
      },
    );
  }

  /// Получить read-only статусы evidence по активным прогрессам квеста.
  Future<List<QuestEvidenceStatusRecord>> getEvidenceStatusesForQuest({
    required String questId,
    Set<String>? taskIds,
  }) async {
    return _runWithFallback(
      remote: () async {
        final snapshot = await _progressRef
            .where('questId', isEqualTo: questId)
            .where('status', isEqualTo: QuestStatus.inProgress.name)
            .limit(200)
            .get();

        final progresses = snapshot.docs
            .map((doc) => QuestProgress.fromMap(doc.data(), doc.id))
            .toList(growable: false)
          ..sort((a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt));

        for (final progress in progresses) {
          _emitLocal(progress);
        }

        return _extractEvidenceRecords(
          progresses,
          taskIds: taskIds,
        );
      },
      local: () async {
        final progresses = _localStore.values
            .where(
              (progress) =>
                  progress.questId == questId &&
                  progress.status == QuestStatus.inProgress,
            )
            .toList(growable: false)
          ..sort((a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt));

        return _extractEvidenceRecords(
          progresses,
          taskIds: taskIds,
        );
      },
    );
  }

  /// Получить очередь moderation (`pendingReview`) для evidence-задач.
  Future<List<QuestModerationQueueItem>> getModerationQueue({
    String? questId,
  }) async {
    final normalizedQuestId = questId?.trim();

    return _runWithFallback(
      remote: () async {
        Query<Map<String, dynamic>> query = _progressRef;
        if (normalizedQuestId != null && normalizedQuestId.isNotEmpty) {
          query = query.where('questId', isEqualTo: normalizedQuestId);
        }

        final snapshot = await query.limit(500).get();
        final progresses = snapshot.docs
            .map((doc) => QuestProgress.fromMap(doc.data(), doc.id))
            .toList(growable: false);

        for (final progress in progresses) {
          _emitLocal(progress);
        }

        return _extractModerationQueueItems(progresses);
      },
      local: () async {
        final progresses = _localStore.values.where((progress) {
          if (normalizedQuestId == null || normalizedQuestId.isEmpty) {
            return true;
          }
          return progress.questId == normalizedQuestId;
        }).toList(growable: false);

        return _extractModerationQueueItems(progresses);
      },
    );
  }

  Future<bool> approveEvidence({
    required String progressId,
    required String taskId,
    required String moderatedBy,
  }) {
    return _setEvidenceModerationStatus(
      progressId: progressId,
      taskId: taskId,
      status: ModerationStatus.approved,
      moderatedBy: moderatedBy,
      moderationComment: null,
    );
  }

  Future<bool> rejectEvidence({
    required String progressId,
    required String taskId,
    required String comment,
    required String moderatedBy,
  }) {
    final normalizedComment = comment.trim();
    if (normalizedComment.isEmpty) {
      throw ArgumentError.value(
          comment, 'comment', 'Comment must not be empty');
    }

    return _setEvidenceModerationStatus(
      progressId: progressId,
      taskId: taskId,
      status: ModerationStatus.rejected,
      moderatedBy: moderatedBy,
      moderationComment: normalizedComment,
    );
  }

  /// Стрим текущего прогресса
  Stream<QuestProgress?> watchProgress(String progressId) {
    return _progressRef.doc(progressId).snapshots().map((doc) {
      if (!doc.exists) {
        return _localStore[progressId];
      }
      final progress = QuestProgress.fromMap(doc.data()!, doc.id);
      _emitLocal(progress);
      return progress;
    }).handleError((_) {
      _localController(progressId).add(_localStore[progressId]);
    });
  }

  Future<QuestProgress?> getProgressById(String progressId) async {
    return _runWithFallback(
      remote: () async {
        final doc = await _progressRef.doc(progressId).get();
        if (!doc.exists) return null;
        final progress = QuestProgress.fromMap(doc.data()!, doc.id);
        _emitLocal(progress);
        return progress;
      },
      local: () async => _localStore[progressId],
    );
  }

  List<QuestEvidenceStatusRecord> _extractEvidenceRecords(
    List<QuestProgress> progresses, {
    Set<String>? taskIds,
  }) {
    final result = <QuestEvidenceStatusRecord>[];

    for (final progress in progresses) {
      progress.taskAnswers.forEach((taskId, answer) {
        if (taskIds != null && !taskIds.contains(taskId)) {
          return;
        }

        if (answer.taskType != TaskType.photo &&
            answer.taskType != TaskType.findObject) {
          return;
        }

        result.add(
          QuestEvidenceStatusRecord(
            progressId: progress.id,
            userId: progress.userId,
            questId: progress.questId,
            taskId: taskId,
            taskType: answer.taskType,
            evidenceStatus: answer.evidenceStatus,
            evidencePath: answer.evidencePath,
            evidenceRemotePath: answer.evidenceRemotePath,
            evidenceRemoteUrl: answer.evidenceRemoteUrl,
            evidenceError: answer.evidenceError,
            moderationStatus: answer.moderationStatus,
            moderationComment: answer.moderationComment,
            moderatedAt: answer.moderatedAt,
            moderatedBy: answer.moderatedBy,
            answeredAt: answer.answeredAt,
            progressUpdatedAt: progress.lastUpdatedAt,
          ),
        );
      });
    }

    result.sort((a, b) => b.answeredAt.compareTo(a.answeredAt));
    return result;
  }

  List<QuestModerationQueueItem> _extractModerationQueueItems(
    List<QuestProgress> progresses,
  ) {
    final items = <QuestModerationQueueItem>[];

    for (final progress in progresses) {
      progress.taskAnswers.forEach((taskId, answer) {
        if (answer.taskType != TaskType.photo &&
            answer.taskType != TaskType.findObject) {
          return;
        }

        if (answer.evidenceStatus != EvidenceStatus.uploaded) {
          return;
        }

        if (answer.moderationStatus != ModerationStatus.pendingReview) {
          return;
        }

        items.add(
          QuestModerationQueueItem(
            progressId: progress.id,
            userId: progress.userId,
            questId: progress.questId,
            taskId: taskId,
            taskType: answer.taskType,
            evidenceStatus: answer.evidenceStatus,
            moderationStatus: answer.moderationStatus!,
            evidencePath: answer.evidencePath,
            evidenceRemotePath: answer.evidenceRemotePath,
            evidenceRemoteUrl: answer.evidenceRemoteUrl,
            answeredAt: answer.answeredAt,
            progressUpdatedAt: progress.lastUpdatedAt,
          ),
        );
      });
    }

    items.sort((a, b) => b.answeredAt.compareTo(a.answeredAt));
    return items;
  }

  Future<bool> _setEvidenceModerationStatus({
    required String progressId,
    required String taskId,
    required ModerationStatus status,
    required String moderatedBy,
    required String? moderationComment,
  }) async {
    final normalizedModerator =
        moderatedBy.trim().isEmpty ? 'moderator' : moderatedBy.trim();

    return _runWithFallback(
      remote: () async {
        return _firestore.runTransaction((transaction) async {
          final ref = _progressRef.doc(progressId);
          final doc = await transaction.get(ref);
          if (!doc.exists) return false;

          final current = QuestProgress.fromMap(doc.data()!, doc.id);
          final updated = _applyModerationDecision(
            progress: current,
            taskId: taskId,
            status: status,
            moderatedBy: normalizedModerator,
            moderationComment: moderationComment,
          );
          if (updated == null) return false;

          transaction.update(ref, {
            'taskAnswers': updated.taskAnswers.map(
              (answerTaskId, answer) => MapEntry(answerTaskId, answer.toMap()),
            ),
            'lastUpdatedAt': updated.lastUpdatedAt.toIso8601String(),
          });

          _emitLocal(updated);
          return true;
        });
      },
      local: () async {
        final current = _localStore[progressId];
        if (current == null) return false;

        final updated = _applyModerationDecision(
          progress: current,
          taskId: taskId,
          status: status,
          moderatedBy: normalizedModerator,
          moderationComment: moderationComment,
        );
        if (updated == null) return false;

        _emitLocal(updated);
        return true;
      },
    );
  }

  QuestProgress? _applyModerationDecision({
    required QuestProgress progress,
    required String taskId,
    required ModerationStatus status,
    required String moderatedBy,
    required String? moderationComment,
  }) {
    final answer = progress.taskAnswers[taskId];
    if (answer == null) return null;

    if (answer.taskType != TaskType.photo &&
        answer.taskType != TaskType.findObject) {
      return null;
    }

    if (answer.evidenceStatus != EvidenceStatus.uploaded) {
      return null;
    }

    if (answer.moderationStatus != ModerationStatus.pendingReview) {
      return null;
    }

    final now = DateTime.now();
    final updatedAnswers =
        Map<String, QuestTaskAnswer>.from(progress.taskAnswers)
          ..[taskId] = answer.copyWith(
            moderationStatus: status,
            moderationComment:
                status == ModerationStatus.rejected ? moderationComment : null,
            moderatedAt: now,
            moderatedBy: moderatedBy,
          );

    return progress.copyWith(
      taskAnswers: updatedAnswers,
      lastUpdatedAt: now,
    );
  }

  Future<T> _runWithFallback<T>({
    required Future<T> Function() remote,
    required Future<T> Function() local,
  }) async {
    try {
      return await remote();
    } on FirebaseException {
      return local();
    } on Exception {
      return local();
    }
  }
}
