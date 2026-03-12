import 'package:equatable/equatable.dart';

/// Точка маршрута (достопримечательность)
class QuestLocation extends Equatable {
  final String id;
  final String questId;
  final int order; // Порядковый номер на маршруте
  final String name;
  final String description;
  final String historicalInfo; // Историческая справка
  final double latitude;
  final double longitude;
  final String imageUrl;
  final String? audioUrl; // Аудиогид (опционально)
  final String taskId; // Привязанное задание
  final int radiusMeters; // Радиус для определения «на месте»

  const QuestLocation({
    required this.id,
    required this.questId,
    required this.order,
    required this.name,
    this.description = '',
    this.historicalInfo = '',
    required this.latitude,
    required this.longitude,
    this.imageUrl = '',
    this.audioUrl,
    this.taskId = '',
    this.radiusMeters = 50,
  });

  QuestLocation copyWith({
    String? id,
    String? questId,
    int? order,
    String? name,
    String? description,
    String? historicalInfo,
    double? latitude,
    double? longitude,
    String? imageUrl,
    String? audioUrl,
    String? taskId,
    int? radiusMeters,
  }) {
    return QuestLocation(
      id: id ?? this.id,
      questId: questId ?? this.questId,
      order: order ?? this.order,
      name: name ?? this.name,
      description: description ?? this.description,
      historicalInfo: historicalInfo ?? this.historicalInfo,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageUrl: imageUrl ?? this.imageUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      taskId: taskId ?? this.taskId,
      radiusMeters: radiusMeters ?? this.radiusMeters,
    );
  }

  factory QuestLocation.fromMap(Map<String, dynamic> map, String id) {
    return QuestLocation(
      id: id,
      questId: map['questId'] as String? ?? '',
      order: map['order'] as int? ?? 0,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      historicalInfo: map['historicalInfo'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      imageUrl: map['imageUrl'] as String? ?? '',
      audioUrl: map['audioUrl'] as String?,
      taskId: map['taskId'] as String? ?? '',
      radiusMeters: map['radiusMeters'] as int? ?? 50,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'questId': questId,
      'order': order,
      'name': name,
      'description': description,
      'historicalInfo': historicalInfo,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'taskId': taskId,
      'radiusMeters': radiusMeters,
    };
  }

  @override
  List<Object?> get props => [id, questId, order, name, latitude, longitude];
}
