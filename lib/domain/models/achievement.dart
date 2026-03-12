import 'package:equatable/equatable.dart';

/// Достижение (бейдж) — по ТЗ раздел 4.6
class Achievement extends Equatable {
  final String id;
  final String title;
  final String description;
  final String iconName; // Material icon name
  final int colorValue; // Цвет бейджа
  final AchievementCondition condition;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    this.iconName = 'emoji_events',
    this.colorValue = 0xFF1A73E8,
    required this.condition,
  });

  factory Achievement.fromMap(Map<String, dynamic> map, String id) {
    return Achievement(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      iconName: map['iconName'] as String? ?? 'emoji_events',
      colorValue: map['colorValue'] as int? ?? 0xFF1A73E8,
      condition: AchievementCondition.fromMap(
          map['condition'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'iconName': iconName,
      'colorValue': colorValue,
      'condition': condition.toMap(),
    };
  }

  @override
  List<Object?> get props => [id, title];
}

/// Условие получения достижения
class AchievementCondition extends Equatable {
  final AchievementType type;
  final int targetValue;

  const AchievementCondition({
    required this.type,
    required this.targetValue,
  });

  factory AchievementCondition.fromMap(Map<String, dynamic> map) {
    return AchievementCondition(
      type: AchievementType.values.firstWhere(
        (e) => e.name == (map['type'] as String? ?? 'questsCompleted'),
        orElse: () => AchievementType.questsCompleted,
      ),
      targetValue: map['targetValue'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'targetValue': targetValue,
    };
  }

  @override
  List<Object?> get props => [type, targetValue];
}

enum AchievementType {
  questsCompleted, // Пройдено N квестов
  totalPoints, // Набрано N очков
  perfectScore, // Все ответы правильные
  speedRun, // За время < N минут
  citiesVisited, // Посещено N городов
  photosUploaded, // Загружено N фото
}
