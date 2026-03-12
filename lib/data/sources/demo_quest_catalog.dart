import 'package:quest_guide/domain/models/quest.dart';
import 'package:quest_guide/domain/models/quest_location.dart';
import 'package:quest_guide/domain/models/quest_task.dart';

/// Локальный демо-каталог квестов для offline/fallback режима.
class DemoQuestCatalog {
  const DemoQuestCatalog();

  static final DateTime _createdAt = DateTime.utc(2025, 1, 1);

  static final List<Quest> _quests = [
    Quest(
      id: 'astana_01',
      title: 'Сердце Астаны',
      description:
          'Прогулка по главным символам столицы: от Байтерека до Хан Шатыра с историческими фактами и мини-заданиями.',
      city: 'Астана',
      difficulty: QuestDifficulty.easy,
      estimatedMinutes: 90,
      distanceKm: 3.4,
      totalPoints: 240,
      rating: 4.7,
      ratingCount: 23,
      locationIds: const ['loc_01', 'loc_02', 'loc_03', 'loc_04'],
      createdAt: _createdAt,
    ),
    Quest(
      id: 'almaty_01',
      title: 'Горный Алматы',
      description:
          'От исторического центра к предгорьям: базар, парк 28 Панфиловцев и Медеу в одном маршруте.',
      city: 'Алматы',
      difficulty: QuestDifficulty.medium,
      estimatedMinutes: 120,
      distanceKm: 5.0,
      totalPoints: 300,
      rating: 4.5,
      ratingCount: 15,
      locationIds: const ['loc_a01', 'loc_a02', 'loc_a03'],
      createdAt: _createdAt,
    ),
    Quest(
      id: 'turkestan_01',
      title: 'Тайны Туркестана',
      description:
          'Исследуй ключевые места Туркестана и проверь внимательность в заданиях про архитектуру и историю.',
      city: 'Туркестан',
      difficulty: QuestDifficulty.medium,
      estimatedMinutes: 80,
      distanceKm: 2.6,
      totalPoints: 210,
      rating: 4.8,
      ratingCount: 12,
      locationIds: const ['loc_t01', 'loc_t02', 'loc_t03'],
      createdAt: _createdAt,
    ),
  ];

  static final Map<String, List<QuestLocation>> _locationsByQuest = {
    'astana_01': const [
      QuestLocation(
        id: 'loc_01',
        questId: 'astana_01',
        order: 0,
        name: 'Монумент Байтерек',
        description: 'Символ новой столицы Казахстана.',
        historicalInfo:
            'Байтерек открыт в 2002 году. Высота смотровой площадки связана с годом переноса столицы.',
        latitude: 51.1282,
        longitude: 71.4306,
        taskId: 'task_01',
        radiusMeters: 100,
      ),
      QuestLocation(
        id: 'loc_02',
        questId: 'astana_01',
        order: 1,
        name: 'Дворец мира и согласия',
        description: 'Пирамида Нормана Фостера.',
        historicalInfo:
            'В здании проходят международные форумы и культурные мероприятия.',
        latitude: 51.1194,
        longitude: 71.4614,
        taskId: 'task_02',
        radiusMeters: 100,
      ),
      QuestLocation(
        id: 'loc_03',
        questId: 'astana_01',
        order: 2,
        name: 'Мечеть Хазрет Султан',
        description: 'Одна из крупнейших мечетей Центральной Азии.',
        historicalInfo:
            'Комплекс открылся в 2012 году и вмещает тысячи посетителей.',
        latitude: 51.1240,
        longitude: 71.4684,
        taskId: 'task_03',
        radiusMeters: 100,
      ),
      QuestLocation(
        id: 'loc_04',
        questId: 'astana_01',
        order: 3,
        name: 'Хан Шатыр',
        description: 'Крупный торгово-развлекательный центр в форме шатра.',
        historicalInfo:
            'Проект Нормана Фостера. Внутри поддерживается комфортный климат круглый год.',
        latitude: 51.1325,
        longitude: 71.4041,
        taskId: 'task_04',
        radiusMeters: 110,
      ),
    ],
    'almaty_01': const [
      QuestLocation(
        id: 'loc_a01',
        questId: 'almaty_01',
        order: 0,
        name: 'Зелёный базар',
        description: 'Исторический рынок в центре города.',
        historicalInfo: 'Один из старейших рынков Алматы, известен с XIX века.',
        latitude: 43.2567,
        longitude: 76.9453,
        taskId: 'task_a01',
        radiusMeters: 80,
      ),
      QuestLocation(
        id: 'loc_a02',
        questId: 'almaty_01',
        order: 1,
        name: 'Парк 28 Панфиловцев',
        description: 'Исторический парк и Вознесенский собор.',
        historicalInfo:
            'Парк посвящён подвигу панфиловцев, а собор известен уникальной деревянной конструкцией.',
        latitude: 43.2583,
        longitude: 76.9535,
        taskId: 'task_a02',
        radiusMeters: 100,
      ),
      QuestLocation(
        id: 'loc_a03',
        questId: 'almaty_01',
        order: 2,
        name: 'Медеу',
        description: 'Высокогорный спортивный комплекс.',
        historicalInfo: 'Расположен на высоте более 1600 м над уровнем моря.',
        latitude: 43.1581,
        longitude: 77.0584,
        taskId: 'task_a03',
        radiusMeters: 140,
      ),
    ],
    'turkestan_01': const [
      QuestLocation(
        id: 'loc_t01',
        questId: 'turkestan_01',
        order: 0,
        name: 'Мавзолей Ходжи Ахмеда Яссауи',
        description: 'Объект всемирного наследия ЮНЕСКО.',
        historicalInfo:
            'Памятник тимуридской архитектуры XIV века и важный духовный центр региона.',
        latitude: 43.2971,
        longitude: 68.2714,
        taskId: 'task_t01',
        radiusMeters: 90,
      ),
      QuestLocation(
        id: 'loc_t02',
        questId: 'turkestan_01',
        order: 1,
        name: 'Керуен-сарай',
        description: 'Современный туристический комплекс в восточном стиле.',
        historicalInfo: 'Популярная локация для прогулок и культурных событий.',
        latitude: 43.2963,
        longitude: 68.2687,
        taskId: 'task_t02',
        radiusMeters: 90,
      ),
      QuestLocation(
        id: 'loc_t03',
        questId: 'turkestan_01',
        order: 2,
        name: 'Подземная мечеть Хильвет',
        description: 'Историческое место духовного уединения.',
        historicalInfo:
            'Связана с духовной практикой и историей суфийской традиции в Туркестане.',
        latitude: 43.2983,
        longitude: 68.2699,
        taskId: 'task_t03',
        radiusMeters: 80,
      ),
    ],
  };

  static final Map<String, List<QuestTask>> _tasksByQuest = {
    'astana_01': const [
      QuestTask(
        id: 'task_01',
        locationId: 'loc_01',
        type: TaskType.quiz,
        question: 'Какой год символизирует высота Байтерека?',
        options: ['1991', '1995', '1997', '2000'],
        correctOptionIndex: 2,
        points: 50,
        hint: 'Год переноса столицы.',
      ),
      QuestTask(
        id: 'task_02',
        locationId: 'loc_02',
        type: TaskType.textInput,
        question: 'Кто архитектор Дворца мира и согласия?',
        correctAnswer: 'Фостер',
        points: 70,
        hint: 'Британский архитектор.',
      ),
      QuestTask(
        id: 'task_03',
        locationId: 'loc_03',
        type: TaskType.quiz,
        question: 'Сколько человек вмещает мечеть Хазрет Султан?',
        options: ['5 000', '10 000', '15 000', '20 000'],
        correctOptionIndex: 1,
        points: 50,
      ),
      QuestTask(
        id: 'task_04',
        locationId: 'loc_04',
        type: TaskType.photo,
        question: 'Сделай фото Хан Шатыра с открытой обзорной точки.',
        points: 70,
      ),
    ],
    'almaty_01': const [
      QuestTask(
        id: 'task_a01',
        locationId: 'loc_a01',
        type: TaskType.riddle,
        question: 'Я стою в центре и пахну специями. Что это за место?',
        correctAnswer: 'базар',
        points: 50,
        hint: 'Зелёный ...',
      ),
      QuestTask(
        id: 'task_a02',
        locationId: 'loc_a02',
        type: TaskType.quiz,
        question: 'Без чего построен Вознесенский собор?',
        options: ['Без цемента', 'Без гвоздей', 'Без дерева', 'Без стекла'],
        correctOptionIndex: 1,
        points: 75,
      ),
      QuestTask(
        id: 'task_a03',
        locationId: 'loc_a03',
        type: TaskType.quiz,
        question: 'На какой высоте расположен Медеу?',
        options: ['1200 м', '1500 м', '1691 м', '2000 м'],
        correctOptionIndex: 2,
        points: 75,
      ),
    ],
    'turkestan_01': const [
      QuestTask(
        id: 'task_t01',
        locationId: 'loc_t01',
        type: TaskType.quiz,
        question: 'Как называется главный мавзолей Туркестана?',
        options: [
          'Мавзолей Бабаджи-хатун',
          'Мавзолей Ходжи Ахмеда Яссауи',
          'Мавзолей Арыстанбаба',
          'Мавзолей Айша-биби',
        ],
        correctOptionIndex: 1,
        points: 60,
      ),
      QuestTask(
        id: 'task_t02',
        locationId: 'loc_t02',
        type: TaskType.findObject,
        question: 'Найди символ каравана на фасаде комплекса Керуен-сарай.',
        points: 70,
      ),
      QuestTask(
        id: 'task_t03',
        locationId: 'loc_t03',
        type: TaskType.textInput,
        question: 'Как одним словом называют духовный путь в суфизме?',
        correctAnswer: 'тарикат',
        points: 80,
        hint: 'Начинается на «т».',
      ),
    ],
  };

  List<Quest> getQuests({String? city}) {
    final normalizedCity = city?.trim();
    final filtered = normalizedCity == null || normalizedCity.isEmpty
        ? _quests
        : _quests.where((quest) => quest.city == normalizedCity).toList();

    return List<Quest>.from(filtered)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Quest? getQuestById(String id) {
    for (final quest in _quests) {
      if (quest.id == id) {
        return quest;
      }
    }
    return null;
  }

  List<String> getCities() {
    final cities = _quests.map((quest) => quest.city).toSet().toList()..sort();
    return cities;
  }

  List<QuestLocation> getLocations(String questId) {
    final locations = _locationsByQuest[questId] ?? const <QuestLocation>[];
    return List<QuestLocation>.from(locations)
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  QuestLocation? getLocationById(String questId, String locationId) {
    final locations = _locationsByQuest[questId];
    if (locations == null) return null;
    for (final location in locations) {
      if (location.id == locationId) {
        return location;
      }
    }
    return null;
  }

  List<QuestTask> getTasks(String questId) {
    final tasks = _tasksByQuest[questId] ?? const <QuestTask>[];
    return List<QuestTask>.from(tasks);
  }

  QuestTask? getTaskForLocation(String questId, String taskId) {
    final tasks = _tasksByQuest[questId];
    if (tasks == null) return null;
    for (final task in tasks) {
      if (task.id == taskId) {
        return task;
      }
    }
    return null;
  }
}
