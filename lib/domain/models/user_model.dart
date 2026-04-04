import 'package:equatable/equatable.dart';
import 'package:quest_guide/core/security/access_control.dart';

/// Модель пользователя
class UserModel extends Equatable {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final String role;
  final bool isAdmin;
  final int totalPoints;
  final int questsCompleted;
  final List<String> earnedBadgeIds;
  final String language; // 'ru' или 'kz'
  final DateTime createdAt;

  // Новые метрики для достижений
  final int photosUploaded;
  final List<String> visitedCities;
  final int reviewsLeft;
  final DateTime? lastCompletedQuestAt;
  final int currentQuestStreakDays;
  final List<String> completedQuestIds;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    this.role = AccessControl.userRole,
    this.isAdmin = false,
    this.totalPoints = 0,
    this.questsCompleted = 0,
    this.earnedBadgeIds = const [],
    this.language = 'ru',
    required this.createdAt,
    this.photosUploaded = 0,
    this.visitedCities = const [],
    this.reviewsLeft = 0,
    this.lastCompletedQuestAt,
    this.currentQuestStreakDays = 0,
    this.completedQuestIds = const [],
  });

  /// Из Firestore документа
  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    final roleRaw = map['role'] as String?;
    final role = roleRaw?.trim().toLowerCase();
    final isAdminFlag = map['isAdmin'] == true;
    final hasAdminRole =
        AccessControl.isAdminRole(role) || AccessControl.isSuperuserRole(role);

    return UserModel(
      id: id,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      role: role ??
          (isAdminFlag ? AccessControl.adminRole : AccessControl.userRole),
      isAdmin: isAdminFlag || hasAdminRole,
      totalPoints: map['totalPoints'] as int? ?? 0,
      questsCompleted: map['questsCompleted'] as int? ?? 0,
      earnedBadgeIds: List<String>.from(map['earnedBadgeIds'] ?? []),
      language: map['language'] as String? ?? 'ru',
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      photosUploaded: map['photosUploaded'] as int? ?? 0,
      visitedCities: List<String>.from(map['visitedCities'] ?? []),
      reviewsLeft: map['reviewsLeft'] as int? ?? 0,
      lastCompletedQuestAt: _parseDateTime(map['lastCompletedQuestAt']),
      currentQuestStreakDays: map['currentQuestStreakDays'] as int? ?? 0,
      completedQuestIds: List<String>.from(map['completedQuestIds'] ?? []),
    );
  }

  static DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is Map<String, dynamic>) {
      final seconds = raw['_seconds'] as int?;
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    }

    try {
      final dynamic toDate = (raw as dynamic).toDate();
      if (toDate is DateTime) return toDate;
    } catch (_) {
      // ignore and fallback below
    }

    return DateTime.tryParse(raw.toString());
  }

  /// В Firestore документ
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'role': role,
      'isAdmin': isAdmin,
      'totalPoints': totalPoints,
      'questsCompleted': questsCompleted,
      'earnedBadgeIds': earnedBadgeIds,
      'language': language,
      'createdAt': createdAt.toIso8601String(),
      'photosUploaded': photosUploaded,
      'visitedCities': visitedCities,
      'reviewsLeft': reviewsLeft,
      'lastCompletedQuestAt': lastCompletedQuestAt?.toIso8601String(),
      'currentQuestStreakDays': currentQuestStreakDays,
      'completedQuestIds': completedQuestIds,
    };
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? photoUrl,
    String? role,
    bool? isAdmin,
    int? totalPoints,
    int? questsCompleted,
    List<String>? earnedBadgeIds,
    String? language,
    int? photosUploaded,
    List<String>? visitedCities,
    int? reviewsLeft,
    DateTime? lastCompletedQuestAt,
    int? currentQuestStreakDays,
    List<String>? completedQuestIds,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      isAdmin: isAdmin ?? this.isAdmin,
      totalPoints: totalPoints ?? this.totalPoints,
      questsCompleted: questsCompleted ?? this.questsCompleted,
      earnedBadgeIds: earnedBadgeIds ?? this.earnedBadgeIds,
      language: language ?? this.language,
      createdAt: createdAt,
      photosUploaded: photosUploaded ?? this.photosUploaded,
      visitedCities: visitedCities ?? this.visitedCities,
      reviewsLeft: reviewsLeft ?? this.reviewsLeft,
      lastCompletedQuestAt: lastCompletedQuestAt ?? this.lastCompletedQuestAt,
      currentQuestStreakDays:
          currentQuestStreakDays ?? this.currentQuestStreakDays,
      completedQuestIds: completedQuestIds ?? this.completedQuestIds,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        email,
        photoUrl,
        role,
        isAdmin,
        totalPoints,
        questsCompleted,
        earnedBadgeIds,
        language,
        photosUploaded,
        visitedCities,
        reviewsLeft,
        lastCompletedQuestAt,
        currentQuestStreakDays,
        completedQuestIds,
      ];
}
