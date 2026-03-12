import 'package:equatable/equatable.dart';

/// Сложность квеста
enum QuestDifficulty { easy, medium, hard }

/// Модель квеста (маршрута)
class Quest extends Equatable {
  final String id;
  final String title;
  final String description;
  final String city;
  final String imageUrl;
  final QuestDifficulty difficulty;
  final int estimatedMinutes; // Длительность в минутах
  final double distanceKm; // Дистанция в км
  final int totalPoints; // Максимальные очки
  final double rating;
  final int ratingCount;
  final List<String> locationIds; // ID точек маршрута
  final bool isActive;
  final DateTime createdAt;

  const Quest({
    required this.id,
    required this.title,
    required this.description,
    required this.city,
    this.imageUrl = '',
    this.difficulty = QuestDifficulty.easy,
    this.estimatedMinutes = 60,
    this.distanceKm = 1.0,
    this.totalPoints = 100,
    this.rating = 0.0,
    this.ratingCount = 0,
    this.locationIds = const [],
    this.isActive = true,
    required this.createdAt,
  });

  String get difficultyLabel => difficulty.name;

  String get durationLabel {
    if (estimatedMinutes < 60) return '$estimatedMinutes min';
    final hours = estimatedMinutes ~/ 60;
    final mins = estimatedMinutes % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }

  Quest copyWith({
    String? id,
    String? title,
    String? description,
    String? city,
    String? imageUrl,
    QuestDifficulty? difficulty,
    int? estimatedMinutes,
    double? distanceKm,
    int? totalPoints,
    double? rating,
    int? ratingCount,
    List<String>? locationIds,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Quest(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      city: city ?? this.city,
      imageUrl: imageUrl ?? this.imageUrl,
      difficulty: difficulty ?? this.difficulty,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      distanceKm: distanceKm ?? this.distanceKm,
      totalPoints: totalPoints ?? this.totalPoints,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      locationIds: locationIds ?? this.locationIds,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Quest.fromMap(Map<String, dynamic> map, String id) {
    return Quest(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      city: map['city'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      difficulty: QuestDifficulty.values.firstWhere(
        (e) => e.name == (map['difficulty'] as String? ?? 'easy'),
        orElse: () => QuestDifficulty.easy,
      ),
      estimatedMinutes: map['estimatedMinutes'] as int? ?? 60,
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 1.0,
      totalPoints: map['totalPoints'] as int? ?? 100,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: map['ratingCount'] as int? ?? 0,
      locationIds: List<String>.from(map['locationIds'] ?? []),
      isActive: map['isActive'] as bool? ?? true,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'city': city,
      'imageUrl': imageUrl,
      'difficulty': difficulty.name,
      'estimatedMinutes': estimatedMinutes,
      'distanceKm': distanceKm,
      'totalPoints': totalPoints,
      'rating': rating,
      'ratingCount': ratingCount,
      'locationIds': locationIds,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, title, city, difficulty];
}
