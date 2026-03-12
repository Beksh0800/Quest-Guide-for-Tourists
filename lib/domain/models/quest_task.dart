import 'package:equatable/equatable.dart';

/// Тип задания (по ТЗ раздел 4.4)
enum TaskType {
  quiz, // Выбор ответа (тест)
  textInput, // Ввод текста
  riddle, // Загадка
  findObject, // Поиск объекта
  photo, // Фото-задание
}

/// Статус облачной валидации/загрузки evidence для photo/findObject.
enum EvidenceStatus {
  pending,
  uploaded,
  failed,
}

/// Задание на точке маршрута
class QuestTask extends Equatable {
  final String id;
  final String locationId;
  final TaskType type;
  final String question;
  final String? hint; // Подсказка
  final String? imageUrl; // Фото
  final int points; // Очки за выполнение
  final List<String> options; // Варианты ответа (для quiz)
  final int correctOptionIndex; // Индекс правильного ответа (для quiz)
  final String? correctAnswer; // Правильный ответ (для textInput/riddle)
  final int timeLimitSeconds; // Лимит времени (0 = без лимита)

  const QuestTask({
    required this.id,
    required this.locationId,
    required this.type,
    required this.question,
    this.hint,
    this.imageUrl,
    this.points = 50,
    this.options = const [],
    this.correctOptionIndex = 0,
    this.correctAnswer,
    this.timeLimitSeconds = 0,
  });

  QuestTask copyWith({
    String? id,
    String? locationId,
    TaskType? type,
    String? question,
    String? hint,
    String? imageUrl,
    int? points,
    int? timeLimitSeconds,
    List<String>? options,
    int? correctOptionIndex,
    String? correctAnswer,
  }) {
    return QuestTask(
      id: id ?? this.id,
      locationId: locationId ?? this.locationId,
      type: type ?? this.type,
      question: question ?? this.question,
      hint: hint ?? this.hint,
      imageUrl: imageUrl ?? this.imageUrl,
      points: points ?? this.points,
      timeLimitSeconds: timeLimitSeconds ?? this.timeLimitSeconds,
      options: options ?? this.options,
      correctOptionIndex: correctOptionIndex ?? this.correctOptionIndex,
      correctAnswer: correctAnswer ?? this.correctAnswer,
    );
  }

  factory QuestTask.fromMap(Map<String, dynamic> map, String id) {
    return QuestTask(
      id: id,
      locationId: map['locationId'] as String? ?? '',
      type: TaskType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TaskType.quiz,
      ),
      question: map['question'] as String? ?? '',
      hint: map['hint'] as String?,
      imageUrl: map['imageUrl'] as String?,
      points: map['points'] as int? ?? 50,
      options: (map['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      correctOptionIndex: map['correctOptionIndex'] as int? ?? 0,
      correctAnswer: map['correctAnswer'] as String?,
      timeLimitSeconds: map['timeLimitSeconds'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'locationId': locationId,
      'type': type.name,
      'question': question,
      if (hint != null) 'hint': hint,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'points': points,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
      if (correctAnswer != null) 'correctAnswer': correctAnswer,
      'timeLimitSeconds': timeLimitSeconds,
    };
  }

  /// Проверка ответа
  bool checkAnswer({
    int? selectedIndex,
    String? textAnswer,
    String? evidencePath,
    EvidenceStatus? evidenceStatus,
  }) {
    switch (type) {
      case TaskType.quiz:
        return selectedIndex == correctOptionIndex;
      case TaskType.textInput:
      case TaskType.riddle:
        if (correctAnswer == null || textAnswer == null) return false;
        return textAnswer.trim().toLowerCase() ==
            correctAnswer!.trim().toLowerCase();
      case TaskType.findObject:
      case TaskType.photo:
        final hasEvidence =
            evidencePath != null && evidencePath.trim().isNotEmpty;
        return hasEvidence && evidenceStatus == EvidenceStatus.uploaded;
    }
  }

  @override
  List<Object?> get props => [id, locationId, type, question];
}
