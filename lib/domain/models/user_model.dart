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
  });

  /// Из Firestore документа
  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    final roleRaw = map['role'] as String?;
    final role = roleRaw?.trim().toLowerCase();
    final isAdminFlag = map['isAdmin'] == true;
    final hasAdminRole = AccessControl.isAdminRole(role);

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
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
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
      ];
}
