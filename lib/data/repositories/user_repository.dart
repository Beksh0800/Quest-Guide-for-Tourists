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
}
