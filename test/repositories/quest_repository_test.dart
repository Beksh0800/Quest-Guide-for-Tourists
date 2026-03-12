import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quest_guide/data/repositories/quest_repository.dart';
import 'package:quest_guide/domain/models/quest.dart';
import 'package:quest_guide/domain/models/quest_location.dart';
import 'package:quest_guide/domain/models/quest_task.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    QuestRepository.resetLocalCache();
    fakeFirestore = FakeFirebaseFirestore();
  });

  group('QuestRepository admin CRUD', () {
    test('createDraftQuest creates inactive draft in Firestore', () async {
      final repo = QuestRepository(firestore: fakeFirestore);

      final bundle = await repo.createDraftQuest();

      expect(bundle.quest.id, isNotEmpty);
      expect(bundle.quest.isActive, isFalse);
      expect(bundle.quest.title, 'Новый квест');

      final doc =
          await fakeFirestore.collection('quests').doc(bundle.quest.id).get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['isActive'], isFalse);
    });

    test('saveQuestContent persists and replaces nested locations/tasks',
        () async {
      final repo = QuestRepository(firestore: fakeFirestore);
      final draft = await repo.createDraftQuest();

      final questId = draft.quest.id;
      final firstLocations = [
        QuestLocation(
          id: 'loc_beta',
          questId: questId,
          order: 10,
          name: 'Локация B',
          description: 'Описание B',
          historicalInfo: 'История B',
          latitude: 43.256,
          longitude: 76.944,
          taskId: 'task_beta',
          radiusMeters: 90,
        ),
        QuestLocation(
          id: 'loc_alpha',
          questId: questId,
          order: 1,
          name: 'Локация A',
          description: 'Описание A',
          historicalInfo: 'История A',
          latitude: 43.257,
          longitude: 76.945,
          taskId: 'task_alpha',
          radiusMeters: 100,
        ),
      ];

      final firstTasks = [
        const QuestTask(
          id: 'task_alpha',
          locationId: 'loc_alpha',
          type: TaskType.quiz,
          question: 'Вопрос A',
          options: ['1', '2'],
          correctOptionIndex: 0,
          points: 50,
        ),
        const QuestTask(
          id: 'task_beta',
          locationId: 'loc_beta',
          type: TaskType.textInput,
          question: 'Вопрос B',
          correctAnswer: 'ответ',
          points: 70,
        ),
      ];

      await repo.saveQuestContent(
        QuestContentBundle(
          quest: draft.quest.copyWith(
            title: 'Обновлённый квест',
            city: 'Алматы',
            description: 'Новое описание',
            estimatedMinutes: 140,
            distanceKm: 4.8,
            totalPoints: 320,
            difficulty: QuestDifficulty.hard,
            isActive: true,
          ),
          locations: firstLocations,
          tasks: firstTasks,
        ),
      );

      final savedBundle = await repo.getQuestContentForAdmin(questId);
      expect(savedBundle, isNotNull);
      expect(savedBundle!.quest.title, 'Обновлённый квест');
      expect(savedBundle.quest.isActive, isTrue);
      expect(savedBundle.locations.length, 2);
      expect(savedBundle.tasks.length, 2);
      expect(savedBundle.locations.map((l) => l.order).toList(), [0, 1]);

      final firstLocationsSnap = await fakeFirestore
          .collection('quests')
          .doc(questId)
          .collection('locations')
          .get();
      final firstTasksSnap = await fakeFirestore
          .collection('quests')
          .doc(questId)
          .collection('tasks')
          .get();
      expect(firstLocationsSnap.docs.length, 2);
      expect(firstTasksSnap.docs.length, 2);

      await repo.saveQuestContent(
        QuestContentBundle(
          quest: savedBundle.quest.copyWith(
            title: 'Квест v2',
            totalPoints: 180,
          ),
          locations: [
            firstLocations[1].copyWith(
              id: 'loc_alpha',
              order: 5,
              name: 'Локация A2',
              taskId: 'task_alpha',
            ),
          ],
          tasks: [
            firstTasks[0].copyWith(
              id: 'task_alpha',
              locationId: 'loc_alpha',
              question: 'Новый вопрос A',
            ),
          ],
        ),
      );

      final secondLocationsSnap = await fakeFirestore
          .collection('quests')
          .doc(questId)
          .collection('locations')
          .get();
      final secondTasksSnap = await fakeFirestore
          .collection('quests')
          .doc(questId)
          .collection('tasks')
          .get();

      expect(secondLocationsSnap.docs.length, 1);
      expect(secondTasksSnap.docs.length, 1);

      final finalBundle = await repo.getQuestContentForAdmin(questId);
      expect(finalBundle, isNotNull);
      expect(finalBundle!.quest.title, 'Квест v2');
      expect(finalBundle.quest.totalPoints, 180);
      expect(finalBundle.locations.single.id, 'loc_alpha');
      expect(finalBundle.locations.single.order, 0);
      expect(finalBundle.tasks.single.question, 'Новый вопрос A');
    });

    test('deleteQuest removes quest and nested docs', () async {
      final repo = QuestRepository(firestore: fakeFirestore);
      final draft = await repo.createDraftQuest();

      final questId = draft.quest.id;
      await repo.saveQuestContent(
        QuestContentBundle(
          quest: draft.quest.copyWith(title: 'Удаляемый квест'),
          locations: [
            QuestLocation(
              id: 'loc_delete',
              questId: questId,
              order: 0,
              name: 'To delete',
              latitude: 43.2,
              longitude: 76.9,
              taskId: 'task_delete',
            ),
          ],
          tasks: const [
            QuestTask(
              id: 'task_delete',
              locationId: 'loc_delete',
              type: TaskType.photo,
              question: 'Сделай фото',
              points: 40,
            ),
          ],
        ),
      );

      await repo.deleteQuest(questId);

      final questDoc =
          await fakeFirestore.collection('quests').doc(questId).get();
      expect(questDoc.exists, isFalse);

      final locationsSnap = await fakeFirestore
          .collection('quests')
          .doc(questId)
          .collection('locations')
          .get();
      final tasksSnap = await fakeFirestore
          .collection('quests')
          .doc(questId)
          .collection('tasks')
          .get();

      expect(locationsSnap.docs, isEmpty);
      expect(tasksSnap.docs, isEmpty);

      final contentAfterDelete = await repo.getQuestContentForAdmin(questId);
      expect(contentAfterDelete, isNull);
    });

    test('create/save/delete work via local fallback when forced', () async {
      final repo = QuestRepository(
        firestore: fakeFirestore,
        forceLocalFallback: true,
      );

      final draft = await repo.createDraftQuest();
      expect(draft.quest.id.startsWith('local_'), isTrue);
      expect(draft.quest.isActive, isFalse);

      final remoteDoc =
          await fakeFirestore.collection('quests').doc(draft.quest.id).get();
      expect(remoteDoc.exists, isFalse);

      await repo.saveQuestContent(
        QuestContentBundle(
          quest: draft.quest.copyWith(
            title: 'Локальный квест',
            city: 'Шымкент',
            isActive: true,
          ),
          locations: [
            QuestLocation(
              id: 'loc_local_1',
              questId: draft.quest.id,
              order: 0,
              name: 'Локальная точка',
              latitude: 42.3155,
              longitude: 69.5869,
              taskId: 'task_local_1',
            ),
          ],
          tasks: const [
            QuestTask(
              id: 'task_local_1',
              locationId: 'loc_local_1',
              type: TaskType.findObject,
              question: 'Найди объект',
              points: 60,
            ),
          ],
        ),
      );

      final saved = await repo.getQuestContentForAdmin(draft.quest.id);
      expect(saved, isNotNull);
      expect(saved!.quest.title, 'Локальный квест');
      expect(saved.quest.city, 'Шымкент');
      expect(saved.quest.isActive, isTrue);
      expect(saved.locations.length, 1);
      expect(saved.tasks.length, 1);

      await repo.deleteQuest(draft.quest.id);

      final deleted = await repo.getQuestById(draft.quest.id);
      expect(deleted, isNull);

      final allQuests = await repo.getAllQuestsForAdmin();
      expect(allQuests.any((q) => q.id == draft.quest.id), isFalse);
    });
  });
}
