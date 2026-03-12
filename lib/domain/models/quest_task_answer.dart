import 'package:equatable/equatable.dart';
import 'package:quest_guide/domain/models/quest_task.dart';

/// Статус модерации evidence для задач photo/findObject.
enum ModerationStatus {
  pendingReview,
  approved,
  rejected,
}

/// Ответ пользователя на конкретное задание квеста.
class QuestTaskAnswer extends Equatable {
  static const Object _unset = Object();

  final String taskId;
  final TaskType taskType;
  final int? selectedOptionIndex;
  final String? textAnswer;
  final String? evidencePath;
  final EvidenceStatus? evidenceStatus;
  final String? evidenceRemotePath;
  final String? evidenceRemoteUrl;
  final String? evidenceError;
  final ModerationStatus? moderationStatus;
  final String? moderationComment;
  final DateTime? moderatedAt;
  final String? moderatedBy;
  final DateTime answeredAt;

  const QuestTaskAnswer({
    required this.taskId,
    required this.taskType,
    this.selectedOptionIndex,
    this.textAnswer,
    this.evidencePath,
    this.evidenceStatus,
    this.evidenceRemotePath,
    this.evidenceRemoteUrl,
    this.evidenceError,
    this.moderationStatus,
    this.moderationComment,
    this.moderatedAt,
    this.moderatedBy,
    required this.answeredAt,
  });

  factory QuestTaskAnswer.fromMap(String taskId, Map<String, dynamic> map) {
    final taskType = TaskType.values.firstWhere(
      (type) => type.name == (map['taskType'] as String? ?? ''),
      orElse: () => TaskType.quiz,
    );
    final evidencePath = map['evidencePath'] as String?;
    final evidenceRemotePath = map['evidenceRemotePath'] as String?;
    final evidenceRemoteUrl = map['evidenceRemoteUrl'] as String?;

    final parsedStatus = EvidenceStatus.values.where(
      (status) => status.name == (map['evidenceStatus'] as String? ?? ''),
    );

    EvidenceStatus? evidenceStatus;
    if (parsedStatus.isNotEmpty) {
      evidenceStatus = parsedStatus.first;
    } else if (taskType == TaskType.photo || taskType == TaskType.findObject) {
      // Backward compatibility: старые записи хранили только local evidencePath.
      // Чтобы не ломать уже завершенные задания, считаем их uploaded.
      final hasLocalEvidence =
          evidencePath != null && evidencePath.trim().isNotEmpty;
      final hasRemoteEvidence =
          evidenceRemotePath != null && evidenceRemotePath.trim().isNotEmpty;
      if (hasLocalEvidence || hasRemoteEvidence) {
        evidenceStatus = EvidenceStatus.uploaded;
      }
    }

    final parsedModerationStatus = ModerationStatus.values.where(
      (status) => status.name == (map['moderationStatus'] as String? ?? ''),
    );

    ModerationStatus? moderationStatus;
    if (parsedModerationStatus.isNotEmpty) {
      moderationStatus = parsedModerationStatus.first;
    } else if ((taskType == TaskType.photo ||
            taskType == TaskType.findObject) &&
        evidenceStatus == EvidenceStatus.uploaded &&
        map['evidenceStatus'] == EvidenceStatus.uploaded.name) {
      // Backward compatibility: старые cloud evidence записи без moderation-полей
      // считаем ожидающими проверки.
      moderationStatus = ModerationStatus.pendingReview;
    }

    return QuestTaskAnswer(
      taskId: taskId,
      taskType: taskType,
      selectedOptionIndex: map['selectedOptionIndex'] as int?,
      textAnswer: map['textAnswer'] as String?,
      evidencePath: evidencePath,
      evidenceStatus: evidenceStatus,
      evidenceRemotePath: evidenceRemotePath,
      evidenceRemoteUrl: evidenceRemoteUrl,
      evidenceError: map['evidenceError'] as String?,
      moderationStatus: moderationStatus,
      moderationComment: map['moderationComment'] as String?,
      moderatedAt: map['moderatedAt'] != null
          ? DateTime.tryParse(map['moderatedAt'] as String)
          : null,
      moderatedBy: map['moderatedBy'] as String?,
      answeredAt: DateTime.tryParse(map['answeredAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'taskType': taskType.name,
      'selectedOptionIndex': selectedOptionIndex,
      'textAnswer': textAnswer,
      'evidencePath': evidencePath,
      'evidenceStatus': evidenceStatus?.name,
      'evidenceRemotePath': evidenceRemotePath,
      'evidenceRemoteUrl': evidenceRemoteUrl,
      'evidenceError': evidenceError,
      'moderationStatus': moderationStatus?.name,
      'moderationComment': moderationComment,
      'moderatedAt': moderatedAt?.toIso8601String(),
      'moderatedBy': moderatedBy,
      'answeredAt': answeredAt.toIso8601String(),
    };
  }

  QuestTaskAnswer copyWith({
    int? selectedOptionIndex,
    String? textAnswer,
    Object? evidencePath = _unset,
    Object? evidenceStatus = _unset,
    Object? evidenceRemotePath = _unset,
    Object? evidenceRemoteUrl = _unset,
    Object? evidenceError = _unset,
    Object? moderationStatus = _unset,
    Object? moderationComment = _unset,
    Object? moderatedAt = _unset,
    Object? moderatedBy = _unset,
    DateTime? answeredAt,
  }) {
    return QuestTaskAnswer(
      taskId: taskId,
      taskType: taskType,
      selectedOptionIndex: selectedOptionIndex ?? this.selectedOptionIndex,
      textAnswer: textAnswer ?? this.textAnswer,
      evidencePath: identical(evidencePath, _unset)
          ? this.evidencePath
          : evidencePath as String?,
      evidenceStatus: identical(evidenceStatus, _unset)
          ? this.evidenceStatus
          : evidenceStatus as EvidenceStatus?,
      evidenceRemotePath: identical(evidenceRemotePath, _unset)
          ? this.evidenceRemotePath
          : evidenceRemotePath as String?,
      evidenceRemoteUrl: identical(evidenceRemoteUrl, _unset)
          ? this.evidenceRemoteUrl
          : evidenceRemoteUrl as String?,
      evidenceError: identical(evidenceError, _unset)
          ? this.evidenceError
          : evidenceError as String?,
      moderationStatus: identical(moderationStatus, _unset)
          ? this.moderationStatus
          : moderationStatus as ModerationStatus?,
      moderationComment: identical(moderationComment, _unset)
          ? this.moderationComment
          : moderationComment as String?,
      moderatedAt: identical(moderatedAt, _unset)
          ? this.moderatedAt
          : moderatedAt as DateTime?,
      moderatedBy: identical(moderatedBy, _unset)
          ? this.moderatedBy
          : moderatedBy as String?,
      answeredAt: answeredAt ?? this.answeredAt,
    );
  }

  /// Обновление evidence с автоматическим reset модерации при успешной загрузке.
  ///
  /// Если [evidenceStatus] == uploaded, статус модерации переводится в
  /// pendingReview, а поля решения (комментарий/кто/когда) очищаются.
  QuestTaskAnswer withEvidenceUploadUpdate({
    required String? evidencePath,
    required EvidenceStatus? evidenceStatus,
    required String? evidenceRemotePath,
    required String? evidenceRemoteUrl,
    required String? evidenceError,
    DateTime? answeredAt,
  }) {
    final shouldResetModeration = evidenceStatus == EvidenceStatus.uploaded;

    return copyWith(
      evidencePath: evidencePath,
      evidenceStatus: evidenceStatus,
      evidenceRemotePath: evidenceRemotePath,
      evidenceRemoteUrl: evidenceRemoteUrl,
      evidenceError: evidenceError,
      moderationStatus: shouldResetModeration
          ? ModerationStatus.pendingReview
          : moderationStatus,
      moderationComment: shouldResetModeration ? null : moderationComment,
      moderatedAt: shouldResetModeration ? null : moderatedAt,
      moderatedBy: shouldResetModeration ? null : moderatedBy,
      answeredAt: answeredAt,
    );
  }

  @override
  List<Object?> get props => [
        taskId,
        taskType,
        selectedOptionIndex,
        textAnswer,
        evidencePath,
        evidenceStatus,
        evidenceRemotePath,
        evidenceRemoteUrl,
        evidenceError,
        moderationStatus,
        moderationComment,
        moderatedAt,
        moderatedBy,
        answeredAt,
      ];
}
