import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:quest_guide/data/sources/demo_quest_catalog.dart';
import 'package:quest_guide/domain/models/quest.dart';
import 'package:quest_guide/domain/models/quest_location.dart';
import 'package:quest_guide/domain/models/quest_task.dart';

/// Полный контент квеста для admin CRUD (квест + точки + задания).
class QuestContentBundle {
  final Quest quest;
  final List<QuestLocation> locations;
  final List<QuestTask> tasks;

  const QuestContentBundle({
    required this.quest,
    required this.locations,
    required this.tasks,
  });
}

/// Репозиторий для работы с квестами в Firestore
class QuestRepository {
  final FirebaseFirestore _firestore;
  final DemoQuestCatalog _demoCatalog;
  final bool _forceLocalFallback;

  static final Map<String, Quest> _localQuestStore = <String, Quest>{};
  static final Map<String, List<QuestLocation>> _localLocationsStore =
      <String, List<QuestLocation>>{};
  static final Map<String, List<QuestTask>> _localTasksStore =
      <String, List<QuestTask>>{};
  static bool _localSeeded = false;

  QuestRepository({
    FirebaseFirestore? firestore,
    @visibleForTesting bool forceLocalFallback = false,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _demoCatalog = const DemoQuestCatalog(),
        _forceLocalFallback = forceLocalFallback {
    _ensureLocalSeeded();
  }

  @visibleForTesting
  static void resetLocalCache() {
    _localQuestStore.clear();
    _localLocationsStore.clear();
    _localTasksStore.clear();
    _localSeeded = false;
  }

  CollectionReference<Map<String, dynamic>> get _questsRef =>
      _firestore.collection('quests');

  CollectionReference<Map<String, dynamic>> _locationsRef(String questId) =>
      _firestore.collection('quests').doc(questId).collection('locations');

  CollectionReference<Map<String, dynamic>> _tasksRef(String questId) =>
      _firestore.collection('quests').doc(questId).collection('tasks');

  // ========== КВЕСТЫ ==========

  /// Получить все активные квесты
  Future<List<Quest>> getQuests({String? city}) async {
    final remoteQuests = await _runWithFallback(
      remote: () async {
        Query<Map<String, dynamic>> query =
            _questsRef.where('isActive', isEqualTo: true);

        if (city != null && city.isNotEmpty) {
          query = query.where('city', isEqualTo: city);
        }

        final snapshot =
            await query.orderBy('createdAt', descending: true).get();
        final quests = snapshot.docs
            .map((doc) => Quest.fromMap(doc.data(), doc.id))
            .toList(growable: false);
        for (final quest in quests) {
          _cacheQuest(quest);
        }
        return quests;
      },
      local: () async => _getLocalQuests(city: city),
    );

    if (remoteQuests.isNotEmpty) {
      return remoteQuests;
    }

    return _getLocalQuests(city: city);
  }

  /// Получить квест по ID
  Future<Quest?> getQuestById(String id) async {
    final remoteQuest = await _runWithFallback<Quest?>(
      remote: () async {
        final doc = await _questsRef.doc(id).get();
        if (!doc.exists) return null;

        final quest = Quest.fromMap(doc.data()!, doc.id);
        _cacheQuest(quest);
        return quest;
      },
      local: () async => _getLocalQuestById(id),
    );

    return remoteQuest ?? _getLocalQuestById(id);
  }

  /// Получить список городов
  Future<List<String>> getCities() async {
    final remoteCities = await _runWithFallback(
      remote: () async {
        final snapshot =
            await _questsRef.where('isActive', isEqualTo: true).get();
        final cities = snapshot.docs
            .map((doc) => doc.data()['city'] as String? ?? '')
            .where((city) => city.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        return cities;
      },
      local: () async => _getLocalCities(activeOnly: true),
    );

    if (remoteCities.isNotEmpty) {
      return remoteCities;
    }

    return _getLocalCities(activeOnly: true);
  }

  /// Получить все квесты для админского списка (включая неактивные).
  Future<List<Quest>> getAllQuestsForAdmin() async {
    final remoteQuests = await _runWithFallback(
      remote: () async {
        final snapshot =
            await _questsRef.orderBy('createdAt', descending: true).get();
        final quests = snapshot.docs
            .map((doc) => Quest.fromMap(doc.data(), doc.id))
            .toList(growable: false);
        for (final quest in quests) {
          _cacheQuest(quest);
        }
        return quests;
      },
      local: () async => _getLocalQuests(activeOnly: false),
    );

    if (remoteQuests.isNotEmpty) {
      return remoteQuests;
    }

    return _getLocalQuests(activeOnly: false);
  }

  /// Получить полный контент квеста для admin-редактирования.
  Future<QuestContentBundle?> getQuestContentForAdmin(String questId) async {
    final remoteBundle = await _runWithFallback<QuestContentBundle?>(
      remote: () async {
        final questDoc = await _questsRef.doc(questId).get();
        if (!questDoc.exists) return null;

        final quest = Quest.fromMap(questDoc.data()!, questDoc.id);
        final locationsSnapshot =
            await _locationsRef(questId).orderBy('order').get();
        final tasksSnapshot = await _tasksRef(questId).get();

        final locations = locationsSnapshot.docs
            .map((doc) => QuestLocation.fromMap(doc.data(), doc.id))
            .toList(growable: false);
        final tasks = tasksSnapshot.docs
            .map((doc) => QuestTask.fromMap(doc.data(), doc.id))
            .toList(growable: false);

        _cacheQuest(quest);
        _cacheLocations(questId, locations);
        _cacheTasks(questId, tasks);

        return QuestContentBundle(
          quest: quest,
          locations: locations,
          tasks: tasks,
        );
      },
      local: () async => _getLocalQuestContent(questId),
    );

    return remoteBundle ?? _getLocalQuestContent(questId);
  }

  /// Создать черновой квест (isActive = false).
  Future<QuestContentBundle> createDraftQuest() async {
    return _runWithFallback(
      remote: () async {
        final doc = _questsRef.doc();
        final draft = _buildDraftQuest(doc.id);

        await doc.set(draft.toMap());

        _cacheQuest(draft);
        _cacheLocations(draft.id, const <QuestLocation>[]);
        _cacheTasks(draft.id, const <QuestTask>[]);

        return QuestContentBundle(
          quest: draft,
          locations: const <QuestLocation>[],
          tasks: const <QuestTask>[],
        );
      },
      local: () async {
        final id =
            'local_${DateTime.now().microsecondsSinceEpoch}_${_localQuestStore.length}';
        final draft = _buildDraftQuest(id);

        _cacheQuest(draft);
        _cacheLocations(draft.id, const <QuestLocation>[]);
        _cacheTasks(draft.id, const <QuestTask>[]);

        return QuestContentBundle(
          quest: draft,
          locations: const <QuestLocation>[],
          tasks: const <QuestTask>[],
        );
      },
    );
  }

  /// Сохранить изменения квеста + полностью перезаписать точки/задания.
  Future<void> saveQuestContent(QuestContentBundle content) async {
    final normalizedLocations =
        _normalizeLocations(content.quest.id, content.locations);
    final normalizedTasks = _normalizeTasks(content.tasks);
    final questToSave = content.quest.copyWith(
      locationIds: normalizedLocations
          .map((location) => location.id)
          .toList(growable: false),
    );

    await _runWithFallback<void>(
      remote: () async {
        final locationsSnapshot = await _locationsRef(questToSave.id).get();
        final tasksSnapshot = await _tasksRef(questToSave.id).get();
        final nextLocationIds =
            normalizedLocations.map((location) => location.id).toSet();
        final nextTaskIds = normalizedTasks.map((task) => task.id).toSet();

        final batch = _firestore.batch();
        final questRef = _questsRef.doc(questToSave.id);

        batch.set(questRef, questToSave.toMap());

        for (final doc in locationsSnapshot.docs) {
          if (!nextLocationIds.contains(doc.id)) {
            batch.delete(doc.reference);
          }
        }
        for (final doc in tasksSnapshot.docs) {
          if (!nextTaskIds.contains(doc.id)) {
            batch.delete(doc.reference);
          }
        }

        for (final location in normalizedLocations) {
          batch.set(
              _locationsRef(questToSave.id).doc(location.id), location.toMap());
        }

        for (final task in normalizedTasks) {
          batch.set(_tasksRef(questToSave.id).doc(task.id), task.toMap());
        }

        await batch.commit();

        _cacheQuest(questToSave);
        _cacheLocations(questToSave.id, normalizedLocations);
        _cacheTasks(questToSave.id, normalizedTasks);
      },
      local: () async {
        _cacheQuest(questToSave);
        _cacheLocations(questToSave.id, normalizedLocations);
        _cacheTasks(questToSave.id, normalizedTasks);
      },
    );
  }

  /// Удалить квест вместе с подколлекциями locations/tasks.
  Future<void> deleteQuest(String questId) async {
    await _runWithFallback<void>(
      remote: () async {
        final locationsSnapshot = await _locationsRef(questId).get();
        final tasksSnapshot = await _tasksRef(questId).get();

        final batch = _firestore.batch();

        for (final doc in locationsSnapshot.docs) {
          batch.delete(doc.reference);
        }

        for (final doc in tasksSnapshot.docs) {
          batch.delete(doc.reference);
        }

        batch.delete(_questsRef.doc(questId));
        await batch.commit();

        _removeLocalQuest(questId);
      },
      local: () async {
        _removeLocalQuest(questId);
      },
    );
  }

  // ========== ТОЧКИ МАРШРУТА ==========

  /// Получить все точки маршрута квеста
  Future<List<QuestLocation>> getLocations(String questId) async {
    final remoteLocations = await _runWithFallback(
      remote: () async {
        final snapshot = await _locationsRef(questId).orderBy('order').get();
        final locations = snapshot.docs
            .map((doc) => QuestLocation.fromMap(doc.data(), doc.id))
            .toList(growable: false);
        _cacheLocations(questId, locations);
        return locations;
      },
      local: () async => _getLocalLocations(questId),
    );

    if (remoteLocations.isNotEmpty) {
      return remoteLocations;
    }

    return _getLocalLocations(questId);
  }

  /// Получить точку по ID
  Future<QuestLocation?> getLocationById(
      String questId, String locationId) async {
    final remoteLocation = await _runWithFallback<QuestLocation?>(
      remote: () async {
        final doc = await _locationsRef(questId).doc(locationId).get();
        if (!doc.exists) return null;

        final location = QuestLocation.fromMap(doc.data()!, doc.id);
        final current = _getLocalLocations(questId)
          ..removeWhere((item) => item.id == location.id)
          ..add(location)
          ..sort((a, b) => a.order.compareTo(b.order));
        _cacheLocations(questId, current);

        return location;
      },
      local: () async => _getLocalLocationById(questId, locationId),
    );

    return remoteLocation ?? _getLocalLocationById(questId, locationId);
  }

  // ========== ЗАДАНИЯ ==========

  /// Получить все задания квеста
  Future<List<QuestTask>> getTasks(String questId) async {
    final remoteTasks = await _runWithFallback(
      remote: () async {
        final snapshot = await _tasksRef(questId).get();
        final tasks = snapshot.docs
            .map((doc) => QuestTask.fromMap(doc.data(), doc.id))
            .toList(growable: false);
        _cacheTasks(questId, tasks);
        return tasks;
      },
      local: () async => _getLocalTasks(questId),
    );

    if (remoteTasks.isNotEmpty) {
      return remoteTasks;
    }

    return _getLocalTasks(questId);
  }

  /// Получить задание точки
  Future<QuestTask?> getTaskForLocation(String questId, String taskId) async {
    final remoteTask = await _runWithFallback<QuestTask?>(
      remote: () async {
        final doc = await _tasksRef(questId).doc(taskId).get();
        if (!doc.exists) return null;

        final task = QuestTask.fromMap(doc.data()!, doc.id);
        final current = _getLocalTasks(questId)
          ..removeWhere((item) => item.id == task.id)
          ..add(task);
        _cacheTasks(questId, current);

        return task;
      },
      local: () async => _getLocalTaskForLocation(questId, taskId),
    );

    return remoteTask ?? _getLocalTaskForLocation(questId, taskId);
  }

  // ========== РЕЙТИНГ ==========

  /// Обновить рейтинг квеста
  Future<void> updateRating(String questId, double newRating) async {
    await _runWithFallback<void>(
      remote: () async {
        await _firestore.runTransaction((transaction) async {
          final doc = await transaction.get(_questsRef.doc(questId));
          final data = doc.data()!;
          final currentRating = (data['rating'] as num?)?.toDouble() ?? 0.0;
          final count = (data['ratingCount'] as int?) ?? 0;

          final updatedRating =
              ((currentRating * count) + newRating) / (count + 1);

          transaction.update(_questsRef.doc(questId), {
            'rating': updatedRating,
            'ratingCount': count + 1,
          });
        });
      },
      local: () async {
        final quest = _localQuestStore[questId];
        if (quest == null) return;

        final updatedRating = ((quest.rating * quest.ratingCount) + newRating) /
            (quest.ratingCount + 1);

        _cacheQuest(
          quest.copyWith(
            rating: updatedRating,
            ratingCount: quest.ratingCount + 1,
          ),
        );
      },
    );
  }

  List<Quest> _getLocalQuests({String? city, bool activeOnly = true}) {
    _ensureLocalSeeded();
    final normalizedCity = city?.trim();

    final result = _localQuestStore.values.where((quest) {
      if (activeOnly && !quest.isActive) return false;

      if (normalizedCity != null &&
          normalizedCity.isNotEmpty &&
          quest.city != normalizedCity) {
        return false;
      }

      return true;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return result;
  }

  Quest? _getLocalQuestById(String id) {
    _ensureLocalSeeded();
    return _localQuestStore[id];
  }

  List<String> _getLocalCities({required bool activeOnly}) {
    _ensureLocalSeeded();

    final cities = _localQuestStore.values
        .where((quest) => !activeOnly || quest.isActive)
        .map((quest) => quest.city)
        .where((city) => city.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return cities;
  }

  List<QuestLocation> _getLocalLocations(String questId) {
    _ensureLocalSeeded();

    final locations = _localLocationsStore[questId] ?? const <QuestLocation>[];
    return List<QuestLocation>.from(locations)
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  QuestLocation? _getLocalLocationById(String questId, String locationId) {
    final locations = _getLocalLocations(questId);

    for (final location in locations) {
      if (location.id == locationId) {
        return location;
      }
    }

    return null;
  }

  List<QuestTask> _getLocalTasks(String questId) {
    _ensureLocalSeeded();

    final tasks = _localTasksStore[questId] ?? const <QuestTask>[];
    return List<QuestTask>.from(tasks);
  }

  QuestTask? _getLocalTaskForLocation(String questId, String taskId) {
    final tasks = _getLocalTasks(questId);

    for (final task in tasks) {
      if (task.id == taskId) {
        return task;
      }
    }

    return null;
  }

  QuestContentBundle? _getLocalQuestContent(String questId) {
    final quest = _getLocalQuestById(questId);
    if (quest == null) return null;

    return QuestContentBundle(
      quest: quest,
      locations: _getLocalLocations(questId),
      tasks: _getLocalTasks(questId),
    );
  }

  Quest _buildDraftQuest(String id) {
    return Quest(
      id: id,
      title: 'Новый квест',
      description: '',
      city: 'Астана',
      difficulty: QuestDifficulty.easy,
      estimatedMinutes: 60,
      distanceKm: 1.0,
      totalPoints: 100,
      rating: 0,
      ratingCount: 0,
      locationIds: const <String>[],
      isActive: false,
      createdAt: DateTime.now(),
    );
  }

  List<QuestLocation> _normalizeLocations(
    String questId,
    List<QuestLocation> locations,
  ) {
    final sortedByOrder = locations.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final suffix = DateTime.now().microsecondsSinceEpoch;

    return List<QuestLocation>.generate(sortedByOrder.length, (index) {
      final source = sortedByOrder[index];
      final sourceId = source.id.trim();
      final id = sourceId.isNotEmpty ? sourceId : 'loc_${index + 1}_$suffix';

      return source.copyWith(
        id: id,
        questId: questId,
        order: index,
      );
    }, growable: false);
  }

  List<QuestTask> _normalizeTasks(List<QuestTask> tasks) {
    final suffix = DateTime.now().microsecondsSinceEpoch;

    return List<QuestTask>.generate(tasks.length, (index) {
      final source = tasks[index];
      final sourceId = source.id.trim();
      final id = sourceId.isNotEmpty ? sourceId : 'task_${index + 1}_$suffix';

      return source.copyWith(
        id: id,
        locationId: source.locationId.trim(),
      );
    }, growable: false);
  }

  void _cacheQuest(Quest quest) {
    _localQuestStore[quest.id] = quest;
  }

  void _cacheLocations(String questId, List<QuestLocation> locations) {
    _localLocationsStore[questId] = List<QuestLocation>.from(locations)
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  void _cacheTasks(String questId, List<QuestTask> tasks) {
    _localTasksStore[questId] = List<QuestTask>.from(tasks);
  }

  void _removeLocalQuest(String questId) {
    _localQuestStore.remove(questId);
    _localLocationsStore.remove(questId);
    _localTasksStore.remove(questId);
  }

  void _ensureLocalSeeded() {
    if (_localSeeded) return;

    final quests = _demoCatalog.getQuests();
    for (final quest in quests) {
      _localQuestStore[quest.id] = quest;
      _localLocationsStore[quest.id] =
          List<QuestLocation>.from(_demoCatalog.getLocations(quest.id));
      _localTasksStore[quest.id] =
          List<QuestTask>.from(_demoCatalog.getTasks(quest.id));
    }

    _localSeeded = true;
  }

  Future<T> _runWithFallback<T>({
    required Future<T> Function() remote,
    required Future<T> Function() local,
  }) async {
    if (_forceLocalFallback) {
      return local();
    }

    try {
      return await remote();
    } on FirebaseException {
      return local();
    } on Exception {
      return local();
    }
  }
}
