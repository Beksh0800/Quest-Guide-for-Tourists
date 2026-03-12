import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quest_guide/domain/models/achievement.dart';
import 'package:quest_guide/domain/models/quest.dart';
import 'package:quest_guide/domain/models/quest_location.dart';
import 'package:quest_guide/domain/models/quest_task.dart';

/// Загрузка демо-данных в Firestore (вызвать 1 раз)
class DemoDataSeeder {
  final FirebaseFirestore _firestore;

  DemoDataSeeder({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Проверить есть ли уже данные
  Future<bool> hasData() async {
    try {
      final snapshot = await _firestore.collection('quests').limit(1).get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      // Если нет прав доступа или другая ошибка, считаем что данных нет
      return false;
    }
  }

  /// Загрузить демо-данные
  Future<void> seed() async {
    if (await hasData()) return;

    await _seedQuests();
    await _seedAchievements();
  }

  Future<void> _seedQuests() async {
    // ====== КВЕСТ 1: Астана ======
    final quest1Ref = _firestore.collection('quests').doc('astana_01');
    final quest1 = Quest(
      id: 'astana_01',
      title: 'Сердце Астаны',
      description: 'Откройте главные достопримечательности столицы Казахстана. '
          'Пройдите маршрут от Байтерека до Хан Шатыра и узнайте историю '
          'современной Астаны.',
      city: 'Астана',
      imageUrl:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b3/Bayterek_tower.jpg/800px-Bayterek_tower.jpg',
      difficulty: QuestDifficulty.easy,
      estimatedMinutes: 90,
      distanceKm: 3.5,
      totalPoints: 250,
      rating: 4.7,
      ratingCount: 23,
      locationIds: const ['loc_01', 'loc_02', 'loc_03', 'loc_04'],
      createdAt: DateTime.now(),
    );
    await quest1Ref.set(quest1.toMap());

    // Точки маршрута квеста 1
    final locations1 = [
      const QuestLocation(
        id: 'loc_01',
        questId: 'astana_01',
        order: 0,
        name: 'Монумент Байтерек',
        description: 'Символ столицы — 97-метровая башня с золотым шаром.',
        historicalInfo:
            'Байтерек был открыт в 2002 году. Высота символизирует 1997 год — '
            'год переноса столицы. Внутри золотого шара находится оттиск руки '
            'Первого Президента.',
        latitude: 51.1282,
        longitude: 71.4306,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b3/Bayterek_tower.jpg/400px-Bayterek_tower.jpg',
        taskId: 'task_01',
        radiusMeters: 100,
      ),
      const QuestLocation(
        id: 'loc_02',
        questId: 'astana_01',
        order: 1,
        name: 'Дворец мира и согласия',
        description: 'Пирамида, где проводятся мировые конгрессы.',
        historicalInfo:
            'Спроектирована Норманом Фостером. Открыта в 2006 году. '
            'Высота — 62 метра. Внутри — оперный зал, конференц-залы и зимний сад.',
        latitude: 51.1194,
        longitude: 71.4614,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/5/57/Palace_of_Peace_and_Reconciliation%2C_Astana%2C_Kazakhstan.jpg/400px-Palace_of_Peace_and_Reconciliation%2C_Astana%2C_Kazakhstan.jpg',
        taskId: 'task_02',
        radiusMeters: 100,
      ),
      const QuestLocation(
        id: 'loc_03',
        questId: 'astana_01',
        order: 2,
        name: 'Мечеть Хазрет Султан',
        description: 'Крупнейшая мечеть Центральной Азии.',
        historicalInfo: 'Открыта в 2012 году. Вмещает 10 000 человек. '
            'Площадь — 11 гектаров. Высота минаретов — 77 метров.',
        latitude: 51.1240,
        longitude: 71.4684,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a6/Khazret_Sultan_Mosque_2.jpg/400px-Khazret_Sultan_Mosque_2.jpg',
        taskId: 'task_03',
        radiusMeters: 100,
      ),
      const QuestLocation(
        id: 'loc_04',
        questId: 'astana_01',
        order: 3,
        name: 'Хан Шатыр',
        description: 'Самый большой шатёр в мире — торговый центр.',
        historicalInfo: 'Открыт в 2010 году. Автор проекта — Норман Фостер. '
            'Высота — 150 метров. Внутри — пляжный курорт с песком с Мальдив.',
        latitude: 51.1325,
        longitude: 71.4041,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c4/Khan_Shatyr_Entertainment_Center_3.jpg/400px-Khan_Shatyr_Entertainment_Center_3.jpg',
        taskId: 'task_04',
        radiusMeters: 100,
      ),
    ];

    for (final loc in locations1) {
      await quest1Ref.collection('locations').doc(loc.id).set(loc.toMap());
    }

    // Задания квеста 1
    final tasks1 = [
      const QuestTask(
        id: 'task_01',
        locationId: 'loc_01',
        type: TaskType.quiz,
        question: 'Какой год символизирует высота Байтерека?',
        options: ['1991', '1995', '1997', '2000'],
        correctOptionIndex: 2,
        points: 50,
        hint: 'Год переноса столицы',
      ),
      const QuestTask(
        id: 'task_02',
        locationId: 'loc_02',
        type: TaskType.textInput,
        question: 'Кто архитектор Дворца мира и согласия?',
        correctAnswer: 'Фостер',
        points: 75,
        hint: 'Британский архитектор',
      ),
      const QuestTask(
        id: 'task_03',
        locationId: 'loc_03',
        type: TaskType.quiz,
        question: 'Сколько человек вмещает мечеть Хазрет Султан?',
        options: ['5 000', '10 000', '15 000', '20 000'],
        correctOptionIndex: 1,
        points: 50,
      ),
      const QuestTask(
        id: 'task_04',
        locationId: 'loc_04',
        type: TaskType.photo,
        question: 'Сфотографируйте Хан Шатыр с площадки напротив!',
        points: 75,
      ),
    ];

    for (final task in tasks1) {
      await quest1Ref.collection('tasks').doc(task.id).set(task.toMap());
    }

    // ====== КВЕСТ 2: Алматы ======
    final quest2Ref = _firestore.collection('quests').doc('almaty_01');
    final quest2 = Quest(
      id: 'almaty_01',
      title: 'Горный Алматы',
      description:
          'Прогулка по знаковым местам южной столицы — от Зелёного базара до Медеу.',
      city: 'Алматы',
      imageUrl:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Medeu_ice_rink.jpg/800px-Medeu_ice_rink.jpg',
      difficulty: QuestDifficulty.medium,
      estimatedMinutes: 120,
      distanceKm: 5.0,
      totalPoints: 300,
      rating: 4.5,
      ratingCount: 15,
      locationIds: const ['loc_a01', 'loc_a02', 'loc_a03'],
      createdAt: DateTime.now(),
    );
    await quest2Ref.set(quest2.toMap());

    final locations2 = [
      const QuestLocation(
        id: 'loc_a01',
        questId: 'almaty_01',
        order: 0,
        name: 'Зелёный базар',
        description: 'Легендарный рынок Алматы с 1875 года.',
        historicalInfo: 'Зелёный базар — один из старейших рынков Казахстана. '
            'Здесь можно найти всё: от казахских деликатесов до сувениров.',
        latitude: 43.2567,
        longitude: 76.9453,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/Green_Bazaar_Almaty.jpg/400px-Green_Bazaar_Almaty.jpg',
        taskId: 'task_a01',
        radiusMeters: 80,
      ),
      const QuestLocation(
        id: 'loc_a02',
        questId: 'almaty_01',
        order: 1,
        name: 'Парк 28 Панфиловцев',
        description: 'Исторический парк с Вознесенским собором.',
        historicalInfo: 'Парк назван в честь героев-панфиловцев. '
            'Вознесенский собор — один из самых высоких деревянных зданий в мире, '
            'построен в 1907 году без единого гвоздя.',
        latitude: 43.2583,
        longitude: 76.9535,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c3/Ascension_Cathedral_Almaty.jpg/400px-Ascension_Cathedral_Almaty.jpg',
        taskId: 'task_a02',
        radiusMeters: 100,
      ),
      const QuestLocation(
        id: 'loc_a03',
        questId: 'almaty_01',
        order: 2,
        name: 'Медеу',
        description: 'Высокогорный ледовый каток.',
        historicalInfo:
            'Медеу — расположен на высоте 1691 м. Каток открыт в 1972 году. '
            'Здесь было установлено более 200 мировых рекордов.',
        latitude: 43.1581,
        longitude: 77.0584,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Medeu_ice_rink.jpg/400px-Medeu_ice_rink.jpg',
        taskId: 'task_a03',
        radiusMeters: 150,
      ),
    ];

    for (final loc in locations2) {
      await quest2Ref.collection('locations').doc(loc.id).set(loc.toMap());
    }

    final tasks2 = [
      const QuestTask(
        id: 'task_a01',
        locationId: 'loc_a01',
        type: TaskType.riddle,
        question: 'Я стою с 1875 года, торгую всем на свете. Что я?',
        correctAnswer: 'базар',
        points: 50,
        hint: 'Зелёный...',
      ),
      const QuestTask(
        id: 'task_a02',
        locationId: 'loc_a02',
        type: TaskType.quiz,
        question: 'Без чего построен Вознесенский собор?',
        options: ['Без цемента', 'Без гвоздей', 'Без дерева', 'Без стекла'],
        correctOptionIndex: 1,
        points: 75,
      ),
      const QuestTask(
        id: 'task_a03',
        locationId: 'loc_a03',
        type: TaskType.quiz,
        question: 'На какой высоте расположен Медеу?',
        options: ['1200 м', '1500 м', '1691 м', '2000 м'],
        correctOptionIndex: 2,
        points: 75,
      ),
      const QuestTask(
        id: 'task_a04',
        locationId: 'loc_a02',
        type: TaskType.findObject,
        question: 'Найдите мемориальную доску на стене Вознесенского собора.',
        hint: 'Она расположена у главного входа',
        points: 60,
      ),
    ];

    for (final task in tasks2) {
      await quest2Ref.collection('tasks').doc(task.id).set(task.toMap());
    }
  }

  Future<void> _seedAchievements() async {
    final achievements = [
      const Achievement(
        id: 'first_quest',
        title: 'Первый квест',
        description: 'Пройдите свой первый квест',
        iconName: 'flag',
        colorValue: 0xFF4CAF50,
        condition: AchievementCondition(
          type: AchievementType.questsCompleted,
          targetValue: 1,
        ),
      ),
      const Achievement(
        id: 'explorer',
        title: 'Исследователь',
        description: 'Пройдите 5 квестов',
        iconName: 'explore',
        colorValue: 0xFF2196F3,
        condition: AchievementCondition(
          type: AchievementType.questsCompleted,
          targetValue: 5,
        ),
      ),
      const Achievement(
        id: 'points_100',
        title: 'Сотня',
        description: 'Наберите 100 очков',
        iconName: 'stars',
        colorValue: 0xFFFF9800,
        condition: AchievementCondition(
          type: AchievementType.totalPoints,
          targetValue: 100,
        ),
      ),
      const Achievement(
        id: 'points_500',
        title: 'Мастер',
        description: 'Наберите 500 очков',
        iconName: 'emoji_events',
        colorValue: 0xFFF44336,
        condition: AchievementCondition(
          type: AchievementType.totalPoints,
          targetValue: 500,
        ),
      ),
      const Achievement(
        id: 'perfect',
        title: 'Безупречный',
        description: 'Ответьте правильно на все вопросы квеста',
        iconName: 'verified',
        colorValue: 0xFF9C27B0,
        condition: AchievementCondition(
          type: AchievementType.perfectScore,
          targetValue: 1,
        ),
      ),
      const Achievement(
        id: 'speedster',
        title: 'Скоростной',
        description: 'Пройдите квест менее чем за 30 минут',
        iconName: 'speed',
        colorValue: 0xFFE91E63,
        condition: AchievementCondition(
          type: AchievementType.speedRun,
          targetValue: 30,
        ),
      ),
    ];

    final batch = _firestore.batch();
    for (final a in achievements) {
      batch.set(
        _firestore.collection('achievements').doc(a.id),
        a.toMap(),
      );
    }
    await batch.commit();
  }
}
