import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:quest_guide/domain/models/user_model.dart';

/// Репозиторий для работы с профилями пользователей
class UserRepository {
  final FirebaseFirestore _firestore;

  static final Map<String, UserModel> _localStore = {};
  static final Map<String, StreamController<UserModel?>> _localControllers = {};

  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @visibleForTesting
  static void resetLocalCache() {
    for (final controller in _localControllers.values) {
      unawaited(controller.close());
    }
    _localControllers.clear();
    _localStore.clear();
  }

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _leaderboardRef =>
      _firestore.collection('leaderboard');

  StreamController<UserModel?> _localController(String uid) {
    return _localControllers.putIfAbsent(
      uid,
      () => StreamController<UserModel?>.broadcast(),
    );
  }

  void _emitLocal(UserModel user) {
    _localStore[user.id] = user;
    _localController(user.id).add(user);
  }

  void _updateLocalIfExists(
    String uid,
    UserModel Function(UserModel current) updater,
  ) {
    final current = _localStore[uid];
    if (current == null) return;
    _emitLocal(updater(current));
  }

  void _updateLocalOrCreate(
    String uid,
    UserModel Function(UserModel current) updater,
  ) {
    final current = _localStore[uid] ??
        UserModel(
          id: uid,
          name: '',
          email: '',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        );
    _emitLocal(updater(current));
  }

  /// Получить пользователя по ID
  Future<UserModel?> getUserById(String uid) async {
    final remoteUser = await _runWithFallback<UserModel?>(
      remote: () async {
        final doc = await _usersRef.doc(uid).get();
        if (!doc.exists) return null;

        final user = UserModel.fromMap(doc.data()!, doc.id);
        _emitLocal(user);
        return user;
      },
      local: () async => _localStore[uid],
    );

    return remoteUser ?? _localStore[uid];
  }

  /// Создать/обновить профиль
  Future<void> saveUser(UserModel user) async {
    await _runWithFallback<void>(
      remote: () async {
        await _usersRef.doc(user.id).set(user.toMap(), SetOptions(merge: true));
        await _upsertLeaderboardSnapshot(user);
        _emitLocal(user);
      },
      local: () async {
        _emitLocal(user);
      },
    );
  }

  /// Добавить очки
  Future<void> addPoints(String uid, int points) async {
    if (points == 0) return;

    await _runWithFallback<void>(
      remote: () async {
        await _usersRef.doc(uid).update({
          'totalPoints': FieldValue.increment(points),
        });
        _updateLocalIfExists(
          uid,
          (current) =>
              current.copyWith(totalPoints: current.totalPoints + points),
        );

        final updated = await _usersRef.doc(uid).get();
        if (updated.exists) {
          await _syncLeaderboardByRawMap(uid, updated.data()!);
        }
      },
      local: () async {
        _updateLocalOrCreate(
          uid,
          (current) =>
              current.copyWith(totalPoints: current.totalPoints + points),
        );
      },
    );
  }

  /// Отметить квест пройденным
  Future<void> incrementQuestsCompleted(String uid) async {
    await _runWithFallback<void>(
      remote: () async {
        await _usersRef.doc(uid).update({
          'questsCompleted': FieldValue.increment(1),
        });
        _updateLocalIfExists(
          uid,
          (current) =>
              current.copyWith(questsCompleted: current.questsCompleted + 1),
        );

        final updated = await _usersRef.doc(uid).get();
        if (updated.exists) {
          await _syncLeaderboardByRawMap(uid, updated.data()!);
        }
      },
      local: () async {
        _updateLocalOrCreate(
          uid,
          (current) =>
              current.copyWith(questsCompleted: current.questsCompleted + 1),
        );
      },
    );
  }

  Future<void> markQuestCompleted({
    required String uid,
    required String questId,
    DateTime? completedAt,
  }) async {
    final completedAtValue = completedAt ?? DateTime.now();

    await _runWithFallback<void>(
      remote: () async {
        final userDoc = await _usersRef.doc(uid).get();
        final current = userDoc.exists
            ? UserModel.fromMap(userDoc.data()!, uid)
            : UserModel(
                id: uid,
                name: '',
                email: '',
                createdAt: completedAtValue,
              );

        final nextStreak = _resolveNextStreak(
          previousCompletedAt: current.lastCompletedQuestAt,
          currentStreakDays: current.currentQuestStreakDays,
          completedAt: completedAtValue,
        );

        await _usersRef.doc(uid).set(
          {
            'questsCompleted': FieldValue.increment(1),
            'lastCompletedQuestAt': completedAtValue.toIso8601String(),
            'currentQuestStreakDays': nextStreak,
            'completedQuestIds': FieldValue.arrayUnion([questId]),
          },
          SetOptions(merge: true),
        );

        _updateLocalOrCreate(
          uid,
          (local) => local.copyWith(
            questsCompleted: local.questsCompleted + 1,
            lastCompletedQuestAt: completedAtValue,
            currentQuestStreakDays: nextStreak,
            completedQuestIds: local.completedQuestIds.contains(questId)
                ? local.completedQuestIds
                : [...local.completedQuestIds, questId],
          ),
        );
      },
      local: () async {
        _updateLocalOrCreate(
          uid,
          (local) {
            final nextStreak = _resolveNextStreak(
              previousCompletedAt: local.lastCompletedQuestAt,
              currentStreakDays: local.currentQuestStreakDays,
              completedAt: completedAtValue,
            );
            return local.copyWith(
              questsCompleted: local.questsCompleted + 1,
              lastCompletedQuestAt: completedAtValue,
              currentQuestStreakDays: nextStreak,
              completedQuestIds: local.completedQuestIds.contains(questId)
                  ? local.completedQuestIds
                  : [...local.completedQuestIds, questId],
            );
          },
        );
      },
    );
  }

  /// Добавить бейдж
  Future<void> addBadge(String uid, String badgeId) async {
    await _runWithFallback<void>(
      remote: () async {
        await _usersRef.doc(uid).update({
          'earnedBadgeIds': FieldValue.arrayUnion([badgeId]),
        });

        _updateLocalIfExists(uid, (current) {
          if (current.earnedBadgeIds.contains(badgeId)) {
            return current;
          }
          return current.copyWith(
            earnedBadgeIds: [...current.earnedBadgeIds, badgeId],
          );
        });
      },
      local: () async {
        _updateLocalOrCreate(uid, (current) {
          if (current.earnedBadgeIds.contains(badgeId)) {
            return current;
          }
          return current.copyWith(
            earnedBadgeIds: [...current.earnedBadgeIds, badgeId],
          );
        });
      },
    );
  }

  /// Добавить посещенный город
  Future<void> addVisitedCity(String uid, String city) async {
    final cityName = city.trim();
    if (cityName.isEmpty) return;

    await _runWithFallback<void>(
      remote: () async {
        await _usersRef.doc(uid).update({
          'visitedCities': FieldValue.arrayUnion([cityName]),
        });

        _updateLocalIfExists(uid, (current) {
          if (current.visitedCities.contains(cityName)) return current;
          return current.copyWith(
            visitedCities: [...current.visitedCities, cityName],
          );
        });
      },
      local: () async {
        _updateLocalOrCreate(uid, (current) {
          if (current.visitedCities.contains(cityName)) return current;
          return current.copyWith(
            visitedCities: [...current.visitedCities, cityName],
          );
        });
      },
    );
  }

  /// Увеличить счетчик загруженных фото
  Future<void> incrementPhotosUploaded(String uid, int count) async {
    if (count <= 0) return;

    await _runWithFallback<void>(
      remote: () async {
        await _usersRef.doc(uid).update({
          'photosUploaded': FieldValue.increment(count),
        });
        _updateLocalIfExists(
          uid,
          (current) =>
              current.copyWith(photosUploaded: current.photosUploaded + count),
        );
      },
      local: () async {
        _updateLocalOrCreate(
          uid,
          (current) =>
              current.copyWith(photosUploaded: current.photosUploaded + count),
        );
      },
    );
  }

  /// Увеличить счетчик оставленных отзывов
  Future<void> incrementReviewsLeft(String uid) async {
    await _runWithFallback<void>(
      remote: () async {
        await _usersRef.doc(uid).update({
          'reviewsLeft': FieldValue.increment(1),
        });
        _updateLocalIfExists(
          uid,
          (current) => current.copyWith(reviewsLeft: current.reviewsLeft + 1),
        );
      },
      local: () async {
        _updateLocalOrCreate(
          uid,
          (current) => current.copyWith(reviewsLeft: current.reviewsLeft + 1),
        );
      },
    );
  }

  /// Обновить язык
  Future<void> updateLanguage(String uid, String language) async {
    await _runWithFallback<void>(
      remote: () async {
        await _usersRef.doc(uid).update({'language': language});
        _updateLocalIfExists(
          uid,
          (current) => current.copyWith(language: language),
        );
      },
      local: () async {
        _updateLocalOrCreate(
          uid,
          (current) => current.copyWith(language: language),
        );
      },
    );
  }

  /// Стрим профиля (для реального времени)
  Stream<UserModel?> watchUser(String uid) {
    return _usersRef.doc(uid).snapshots().map((doc) {
      if (!doc.exists) {
        return _localStore[uid];
      }

      final user = UserModel.fromMap(doc.data()!, doc.id);
      _emitLocal(user);
      return user;
    }).handleError((_) {
      _localController(uid).add(_localStore[uid]);
    });
  }

  /// Получить топ пользователей по очкам.
  ///
  /// Детерминированный tie-break:
  /// 1) totalPoints по убыванию
  /// 2) questsCompleted по убыванию
  /// 3) id по возрастанию
  Future<List<UserModel>> getTopUsers({int limit = 10}) async {
    if (limit <= 0) return const [];

    final allUsers = await _getSortedUsers();
    if (allUsers.isEmpty) return const [];

    return allUsers.take(limit).toList(growable: false);
  }

  /// Получить место текущего пользователя в общем рейтинге.
  /// Возвращает null, если пользователя нет в источнике данных.
  Future<int?> getUserRank(String uid) async {
    final allUsers = await _getSortedUsers();
    final index = allUsers.indexWhere((user) => user.id == uid);
    if (index == -1) return null;
    return index + 1;
  }

  Future<List<UserModel>> _getSortedUsers() async {
    final users = await _runWithFallback<List<UserModel>>(
      remote: () async {
        final leaderboardSnap = await _leaderboardRef
            .orderBy('totalPoints', descending: true)
            .orderBy('questsCompleted', descending: true)
            .get();

        if (leaderboardSnap.docs.isEmpty) {
          final fallbackUsersSnap = await _usersRef.get();
          final fallbackUsers = fallbackUsersSnap.docs
              .map((doc) => UserModel.fromMap(doc.data(), doc.id))
              .toList(growable: false);

          for (final user in fallbackUsers) {
            _emitLocal(user);
            await _upsertLeaderboardSnapshot(user);
          }

          return fallbackUsers;
        }

        final remoteUsers = leaderboardSnap.docs
            .map((doc) => _userFromLeaderboardDoc(doc.id, doc.data()))
            .toList(growable: false);

        for (final user in remoteUsers) {
          _emitLocal(user);
        }

        return remoteUsers;
      },
      local: () async => _localStore.values.toList(),
    );

    final result = users.toList()
      ..sort((a, b) {
        final byPoints = b.totalPoints.compareTo(a.totalPoints);
        if (byPoints != 0) return byPoints;

        final byCompleted = b.questsCompleted.compareTo(a.questsCompleted);
        if (byCompleted != 0) return byCompleted;

        return a.id.compareTo(b.id);
      });

    return result;
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

  Future<void> _syncLeaderboardByRawMap(
    String uid,
    Map<String, dynamic> rawMap,
  ) async {
    final user = UserModel.fromMap(rawMap, uid);
    await _upsertLeaderboardSnapshot(user);
  }

  Future<void> _upsertLeaderboardSnapshot(UserModel user) async {
    try {
      await _leaderboardRef.doc(user.id).set(
        {
          'name': user.name,
          'photoUrl': user.photoUrl,
          'totalPoints': user.totalPoints,
          'questsCompleted': user.questsCompleted,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        SetOptions(merge: true),
      );
    } on FirebaseException {
      // Если leaderboard недоступен, основной профиль всё равно сохраняется.
    } on Exception {
      // Непредвиденные ошибки sync не должны блокировать user flow.
    }
  }

  UserModel _userFromLeaderboardDoc(String uid, Map<String, dynamic> data) {
    final updatedAt = DateTime.tryParse(data['updatedAt'] as String? ?? '');

    return UserModel(
      id: uid,
      name: data['name'] as String? ?? '',
      email: '',
      photoUrl: data['photoUrl'] as String?,
      totalPoints: data['totalPoints'] as int? ?? 0,
      questsCompleted: data['questsCompleted'] as int? ?? 0,
      createdAt: updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  int _resolveNextStreak({
    required DateTime? previousCompletedAt,
    required int currentStreakDays,
    required DateTime completedAt,
  }) {
    if (previousCompletedAt == null) {
      return 1;
    }

    final previousDay = DateTime(
      previousCompletedAt.year,
      previousCompletedAt.month,
      previousCompletedAt.day,
    );
    final completedDay = DateTime(
      completedAt.year,
      completedAt.month,
      completedAt.day,
    );
    final deltaDays = completedDay.difference(previousDay).inDays;

    if (deltaDays <= 0) {
      return currentStreakDays <= 0 ? 1 : currentStreakDays;
    }
    if (deltaDays == 1) {
      return currentStreakDays <= 0 ? 1 : currentStreakDays + 1;
    }
    return 1;
  }
}
