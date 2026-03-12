import 'package:equatable/equatable.dart';
import 'package:quest_guide/domain/models/quest_task_answer.dart';

/// Прогресс прохождения квеста
class QuestProgress extends Equatable {
  final String id;
  final String userId;
  final String questId;
  final QuestStatus status;
  final int currentLocationIndex; // Текущая точка маршрута
  final int earnedPoints;
  final int timeBonusPoints;
  final int correctAnswers;
  final int totalAnswers;
  final List<String> completedTaskIds;
  final Map<String, QuestTaskAnswer> taskAnswers;
  final DateTime startedAt;
  final DateTime lastUpdatedAt;
  final DateTime? completedAt;

  const QuestProgress({
    required this.id,
    required this.userId,
    required this.questId,
    this.status = QuestStatus.inProgress,
    this.currentLocationIndex = 0,
    this.earnedPoints = 0,
    this.timeBonusPoints = 0,
    this.correctAnswers = 0,
    this.totalAnswers = 0,
    this.completedTaskIds = const [],
    this.taskAnswers = const {},
    required this.startedAt,
    DateTime? lastUpdatedAt,
    this.completedAt,
  }) : lastUpdatedAt = lastUpdatedAt ?? startedAt;

  /// Длительность прохождения
  Duration get duration {
    final end = completedAt ?? DateTime.now();
    return end.difference(startedAt);
  }

  String get durationLabel {
    final d = duration;
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  /// Процент правильных ответов
  double get accuracy => totalAnswers > 0 ? correctAnswers / totalAnswers : 0;

  factory QuestProgress.fromMap(Map<String, dynamic> map, String id) {
    return QuestProgress(
      id: id,
      userId: map['userId'] as String? ?? '',
      questId: map['questId'] as String? ?? '',
      status: QuestStatus.values.firstWhere(
        (e) => e.name == (map['status'] as String? ?? 'inProgress'),
        orElse: () => QuestStatus.inProgress,
      ),
      currentLocationIndex: map['currentLocationIndex'] as int? ?? 0,
      earnedPoints: map['earnedPoints'] as int? ?? 0,
      timeBonusPoints: map['timeBonusPoints'] as int? ?? 0,
      correctAnswers: map['correctAnswers'] as int? ?? 0,
      totalAnswers: map['totalAnswers'] as int? ?? 0,
      completedTaskIds: List<String>.from(map['completedTaskIds'] ?? []),
      taskAnswers: _parseTaskAnswers(map['taskAnswers']),
      startedAt: DateTime.tryParse(map['startedAt'] ?? '') ?? DateTime.now(),
      lastUpdatedAt: DateTime.tryParse(map['lastUpdatedAt'] ?? '') ??
          DateTime.tryParse(map['startedAt'] ?? '') ??
          DateTime.now(),
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'questId': questId,
      'status': status.name,
      'currentLocationIndex': currentLocationIndex,
      'earnedPoints': earnedPoints,
      'timeBonusPoints': timeBonusPoints,
      'correctAnswers': correctAnswers,
      'totalAnswers': totalAnswers,
      'completedTaskIds': completedTaskIds,
      'taskAnswers': taskAnswers.map(
        (taskId, answer) => MapEntry(taskId, answer.toMap()),
      ),
      'startedAt': startedAt.toIso8601String(),
      'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  QuestProgress copyWith({
    QuestStatus? status,
    int? currentLocationIndex,
    int? earnedPoints,
    int? timeBonusPoints,
    int? correctAnswers,
    int? totalAnswers,
    List<String>? completedTaskIds,
    Map<String, QuestTaskAnswer>? taskAnswers,
    DateTime? lastUpdatedAt,
    DateTime? completedAt,
  }) {
    return QuestProgress(
      id: id,
      userId: userId,
      questId: questId,
      status: status ?? this.status,
      currentLocationIndex: currentLocationIndex ?? this.currentLocationIndex,
      earnedPoints: earnedPoints ?? this.earnedPoints,
      timeBonusPoints: timeBonusPoints ?? this.timeBonusPoints,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      totalAnswers: totalAnswers ?? this.totalAnswers,
      completedTaskIds: completedTaskIds ?? this.completedTaskIds,
      taskAnswers: taskAnswers ?? this.taskAnswers,
      startedAt: startedAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  static Map<String, QuestTaskAnswer> _parseTaskAnswers(dynamic rawMap) {
    if (rawMap == null) return const {};

    Map<String, dynamic> normalized;
    if (rawMap is Map<String, dynamic>) {
      normalized = rawMap;
    } else if (rawMap is Map) {
      normalized = Map<String, dynamic>.from(rawMap);
    } else {
      return const {};
    }

    if (normalized.isEmpty) return const {};

    final parsed = <String, QuestTaskAnswer>{};
    normalized.forEach((taskId, value) {
      if (value is Map<String, dynamic>) {
        parsed[taskId] = QuestTaskAnswer.fromMap(taskId, value);
      } else if (value is Map) {
        parsed[taskId] =
            QuestTaskAnswer.fromMap(taskId, Map<String, dynamic>.from(value));
      }
    });
    return parsed;
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        questId,
        status,
        currentLocationIndex,
        earnedPoints,
        timeBonusPoints,
        correctAnswers,
        totalAnswers,
        completedTaskIds,
        taskAnswers,
        startedAt,
        lastUpdatedAt,
        completedAt,
      ];
}

enum QuestStatus { inProgress, completed, abandoned }
