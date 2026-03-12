import 'package:flutter/material.dart';
import 'package:quest_guide/presentation/auth/cubit/auth_state.dart';

/// Поддерживаемые языки приложения
enum AppLanguage {
  ru, // Русский
  kz, // Қазақша
}

/// Класс локализации — содержит все строки приложения
class AppLocalizations {
  final AppLanguage language;

  const AppLocalizations({this.language = AppLanguage.ru});

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations();
  }

  String get locale => language == AppLanguage.kz ? 'kk' : 'ru';

  // ───────── Общие ─────────
  String get appTitle => _t('Quest Guide', 'Quest Guide');
  String get loading => _t('Загрузка...', 'Жүктелуде...');
  String get error => _t('Ошибка', 'Қате');
  String get retry => _t('Повторить', 'Қайталау');
  String get cancel => _t('Отмена', 'Болдырмау');
  String get save => _t('Сохранить', 'Сақтау');
  String get back => _t('Назад', 'Артқа');
  String get next => _t('Далее', 'Келесі');
  String get done => _t('Готово', 'Дайын');
  String get close => _t('Закрыть', 'Жабу');
  String get yes => _t('Да', 'Иә');
  String get no => _t('Нет', 'Жоқ');
  String get kmLabel => _t('км', 'км');
  String get hintLabel => _t('Подсказка', 'Кеңес');

  // ───────── Auth ─────────
  String get loginTitle => _t('Вход', 'Кіру');
  String get registerTitle => _t('Регистрация', 'Тіркелу');
  String get email => _t('Email', 'Email');
  String get password => _t('Пароль', 'Құпия сөз');
  String get confirmPassword =>
      _t('Подтвердите пароль', 'Құпия сөзді растаңыз');
  String get name => _t('Имя', 'Аты');
  String get loginButton => _t('Войти', 'Кіру');
  String get registerButton => _t('Зарегистрироваться', 'Тіркелу');
  String get noAccount => _t('Нет аккаунта?', 'Аккаунт жоқ па?');
  String get hasAccount => _t('Уже есть аккаунт?', 'Аккаунт бар ма?');
  String get signInWithGoogle => _t('Войти через Google', 'Google арқылы кіру');
  String get forgotPassword =>
      _t('Забыли пароль?', 'Құпия сөзді ұмыттыңыз ба?');
  String get signOut => _t('Выйти', 'Шығу');
  String get signOutConfirm =>
      _t('Вы уверены, что хотите выйти?', 'Шығуға сенімдісіз бе?');
  String get passwordHint =>
      _t('Пароль (мин. 6 символов)', 'Құпия сөз (кемінде 6 таңба)');
  String get validationEnterEmail => _t('Введите email', 'Email енгізіңіз');
  String get validationInvalidEmail =>
      _t('Некорректный email', 'Email дұрыс емес');
  String get validationEnterPassword =>
      _t('Введите пароль', 'Құпия сөзді енгізіңіз');
  String get validationPasswordMin =>
      _t('Минимум 6 символов', 'Кемінде 6 таңба');
  String get validationEnterName => _t('Введите имя', 'Атыңызды енгізіңіз');

  // ───────── Home ─────────
  String get homeTitle => _t('Квесты', 'Квесттер');
  String get allCities => _t('Все города', 'Барлық қалалар');
  String get noQuests => _t('Нет доступных квестов', 'Қолжетімді квесттер жоқ');
  String get searchQuests => _t('Поиск квестов...', 'Квесттерді іздеу...');
  String get filterByCity => _t('Фильтр по городу', 'Қала бойынша сүзу');
  String get questStatusNotStarted => _t('Не начат', 'Басталмаған');
  String get questStatusInProgress => _t('В процессе', 'Жүруде');
  String get questStatusCompleted => _t('Завершён', 'Аяқталды');

  // ───────── Quest Detail ─────────
  String get startQuest => _t('Начать квест', 'Квестті бастау');
  String get continueQuest => _t('Продолжить', 'Жалғастыру');
  String get questRoute => _t('Маршрут', 'Маршрут');
  String get questDescription => _t('Описание', 'Сипаттама');
  String get difficulty => _t('Сложность', 'Күрделілік');
  String get duration => _t('Длительность', 'Ұзақтығы');
  String get distance => _t('Расстояние', 'Қашықтық');
  String get points => _t('Очки', 'Ұпай');
  String get rating => _t('Рейтинг', 'Рейтинг');
  String get locations => _t('Точки маршрута', 'Маршрут нүктелері');
  String get difficultyEasy => _t('Лёгкий', 'Жеңіл');
  String get difficultyMedium => _t('Средний', 'Орташа');
  String get difficultyHard => _t('Сложный', 'Күрделі');

  // ───────── Task ─────────
  String pointN(int n, int total) => _t('Точка $n/$total', '$n/$total нүкте');
  String get taskLabel => _t('Задание', 'Тапсырма');
  String get taskQuestion => _t('Вопрос', 'Сұрақ');
  String get taskHint => _t('Подсказка', 'Кеңес');
  String get submitAnswer => _t('Ответить', 'Жауап беру');
  String get correct => _t('Правильно!', 'Дұрыс!');
  String get incorrect => _t('Неправильно', 'Қате');
  String get nextPoint => _t('Следующая точка →', 'Келесі нүкте →');
  String get finishQuest => _t('Завершить квест', 'Квестті аяқтау');
  String get historicalInfo => _t('Историческая справка', 'Тарихи мәлімет');
  String get takePhoto => _t('Сделать фото', 'Фото түсіру');
  String get attachPhoto => _t('Прикрепить фото', 'Фото тіркеу');
  String get replacePhoto => _t('Заменить фото', 'Фотоны ауыстыру');
  String get photoFromGallery => _t('Выбрать из галереи', 'Галереядан таңдау');
  String get photoFromCamera =>
      _t('Сделать снимок камерой', 'Камерамен түсіру');
  String get photoPreview =>
      _t('Превью фото-доказательства', 'Фото-дәлел алдын ала қарау');
  String get photoNotSelected =>
      _t('Фото ещё не выбрано', 'Фото әлі таңдалмады');
  String get photoPickFailed => _t('Не удалось выбрать или сохранить фото',
      'Фотоны таңдау не сақтау сәтсіз');
  String get photoRequiredError => _t('Добавьте фото, чтобы завершить задание',
      'Тапсырманы аяқтау үшін фото қосыңыз');
  String get photoTaskEvidenceHint => _t(
      'Для завершения задания приложите фото текущей локации.',
      'Тапсырманы аяқтау үшін ағымдағы локацияның фотосын тіркеңіз.');
  String get findObjectEvidenceHint => _t(
      'Сфотографируйте найденный объект, чтобы подтвердить результат.',
      'Нәтижені растау үшін табылған объектіні фотоға түсіріңіз.');
  String get submitPhotoEvidence =>
      _t('Подтвердить фото-задание', 'Фото тапсырмасын растау');
  String get submitFindObjectEvidence =>
      _t('Подтвердить найденный объект', 'Табылған объектіні растау');
  String get photoAccepted => _t('Фото принято', 'Фото қабылданды');
  String get findObjectButton => _t('Нашёл объект!', 'Объектіні таптым!');
  String get objectFound => _t('Объект найден!', 'Объект табылды!');
  String get evidenceStatusLabel => _t('Статус загрузки', 'Жүктеу күйі');
  String get evidenceStatusPending => _t('Ожидает загрузки', 'Жүктеуді күтуде');
  String get evidenceStatusUploaded => _t('Загружено', 'Жүктелді');
  String get evidenceStatusFailed => _t('Ошибка загрузки', 'Жүктеу қатесі');
  String get evidenceUploadedMessage => _t(
      'Фото загружено в облако. Можно подтверждать задание.',
      'Фото бұлтқа жүктелді. Тапсырманы растауға болады.');
  String get evidenceCloudUploadRequired => _t(
      'Подтверждение доступно только после загрузки фото в облако.',
      'Растау тек фото бұлтқа жүктелгеннен кейін қолжетімді.');
  String get evidenceRetryUpload =>
      _t('Повторить загрузку', 'Жүктеуді қайталау');
  String get evidenceRetryFailed =>
      _t('Не удалось повторить загрузку фото', 'Фотоны қайта жүктеу сәтсіз');
  String get evidenceErrorUnauthenticated => _t(
      'Войдите в аккаунт для облачной загрузки фото.',
      'Фотоны бұлтқа жүктеу үшін аккаунтқа кіріңіз.');
  String get evidenceErrorLocalFileMissing => _t(
      'Локальный файл фото не найден. Выберите фото заново.',
      'Жергілікті фото файлы табылмады. Фотоны қайта таңдаңыз.');
  String get evidenceErrorCloudUnavailable => _t(
      'Облако недоступно. Фото сохранено локально, попробуйте повторить позже.',
      'Бұлт қолжетімсіз. Фото жергілікті сақталды, кейінірек қайталап көріңіз.');
  String get evidenceErrorUploadFailed => _t(
      'Не удалось загрузить фото в облако.',
      'Фотоны бұлтқа жүктеу мүмкін болмады.');
  String get evidenceErrorUnknown => _t('Неизвестная ошибка загрузки evidence.',
      'Evidence жүктеу кезіндегі белгісіз қате.');
  String get moderationStatusLabel => _t('Статус модерации', 'Модерация күйі');
  String get moderationStatusPendingReview => _t('На проверке', 'Тексеруде');
  String get moderationStatusApproved => _t('Подтверждено', 'Расталды');
  String get moderationStatusRejected => _t('Отклонено', 'Қабылданбады');
  String get moderationPendingReviewMessage => _t(
      'Доказательство отправлено на проверку модератору.',
      'Дәлел модератор тексеруіне жіберілді.');
  String get moderationApprovedMessage => _t(
      'Модератор подтвердил выполнение задания.',
      'Модератор тапсырма орындалуын растады.');
  String get moderationRejectedMessage => _t(
      'Модератор отклонил доказательство. Загрузите фото повторно.',
      'Модератор дәлелді қабылдамады. Фотоны қайта жүктеңіз.');
  String get moderationCommentLabel =>
      _t('Комментарий модератора', 'Модератор пікірі');
  String get moderationRetryCta =>
      _t('Заменить фото и отправить снова', 'Фотоны ауыстырып, қайта жіберу');
  String get audioGuide => _t('Аудиогид', 'Аудиогид');
  String get restartQuest => _t('Пройти снова', 'Қайта өту');
  String get enterAnswer =>
      _t('Введите ваш ответ...', 'Жауабыңызды жазыңыз...');
  String get noTask =>
      _t('Для этой точки нет задания', 'Бұл нүктеге тапсырма жоқ');
  String correctAnswer(int p) => _t('Правильно! +$p очков', 'Дұрыс! +$p ұпай');
  String get wrongAnswer => _t('Неправильно', 'Қате');
  String get correctAnswerIs => _t('Ответ', 'Жауабы');
  String incorrectAnswer(String answer) =>
      _t('Неправильно. Ответ: $answer', 'Қате. Жауабы: $answer');

  // ───────── Quest Complete ─────────
  String get questComplete => _t('Квест завершён!', 'Квест аяқталды!');
  String get finalScore => _t('Итоговый счёт', 'Жалпы ұпай');
  String get basePointsLabel => _t('База', 'Негізгі ұпай');
  String speedBonusAwarded(int bonus) =>
      _t('Бонус за скорость: +$bonus', 'Жылдамдық бонусы: +$bonus');
  String get pointsLabel => _t('очков', 'ұпай');
  String get locationsLabel => _t('Точек', 'Нүктелер');
  String get maxPoints => _t('Макс. очки', 'Макс. ұпай');
  String get result => _t('Результат', 'Нәтиже');
  String get resultSaved => _t('Результат сохранён', 'Нәтиже сақталды');
  String get resultAlreadySaved =>
      _t('Результат уже был сохранён ранее', 'Нәтиже бұрын сақталған');
  String get savingResult =>
      _t('Сохраняем результат...', 'Нәтиже сақталуда...');
  String get toHome => _t('На главную', 'Басты бетке');
  String get playAgain => _t('Пройти снова', 'Қайта өту');
  String get saveError => _t('Ошибка сохранения', 'Сақтау қатесі');
  String get questFallbackTitle => _t('Квест', 'Квест');
  String newBadgesUnlocked(int n) =>
      _t('Открыто новых достижений: $n', 'Жаңа жетістіктер ашылды: $n');

  // ───────── Map ─────────
  String get mapTitle => _t('Маршрут', 'Маршрут');
  String get mapRoute => _t('Карта маршрута', 'Маршрут картасы');
  String get mapSelectQuestHint => _t(
      'Выберите квест и откройте его карту маршрута.',
      'Квестті таңдаңыз және маршрут картасын ашыңыз.');
  String get noLocations => _t('Нет точек маршрута', 'Маршрут нүктелері жоқ');
  String pointOf(int n, int total) =>
      _t('Точка $n из $total', '$total ішінде $n нүкте');
  String get doTask => _t('Выполнить задание', 'Тапсырманы орындау');
  String get moveCloser => _t('Подойдите ближе', 'Жақынырақ келіңіз');
  String distanceToTarget(int meters) =>
      _t('До точки: $meters м', 'Нүктеге дейін: $meters м');
  String get startRoute => _t('Начать прохождение', 'Маршрутты бастау');
  String nPoints(int n) => _t('$n точек', '$n нүкте');
  String get openRouteMap =>
      _t('Открыть карту маршрута', 'Маршрут картасын ашу');
  String get openExternalNavigation =>
      _t('Навигация во внешнем приложении', 'Сыртқы қосымшада навигация');
  String get locationPermissionDenied =>
      _t('Нет доступа к геолокации', 'Геолокацияға рұқсат жоқ');
  String get locationServiceDisabled =>
      _t('Служба геолокации отключена', 'Геолокация қызметі өшірілген');
  String get locationReachedTitle =>
      _t('Вы рядом с точкой маршрута', 'Сіз маршрут нүктесіне жақынсыз');
  String locationReachedBody(String locationName) =>
      _t('Откройте задание: $locationName', 'Тапсырманы ашыңыз: $locationName');
  String get devBypass => _t('Dev обход', 'Dev айналып өту');
  String get mapRouteLoading => _t('Строим маршрут по дорогам...',
      'Жолдар бойынша маршрут құрылып жатыр...');
  String get mapRouteUnavailable => _t(
      'Не удалось построить маршрут по дорогам. Попробуйте ещё раз или откройте внешнюю навигацию.',
      'Жолдар бойынша маршрут құру мүмкін болмады. Қайта көріңіз немесе сыртқы навигацияны ашыңыз.');
  String get mapRouteApiKeyMissing => _t(
      'Не настроен ключ Directions API. Обратись к разработчику.',
      'Directions API кілті бапталмаған. Әзірлеушіге хабарлас.');
  String get mapRouteNoRoads => _t(
      'Для этой точки не найден пешеходный маршрут по дорогам.',
      'Бұл нүктеге жаяу жол маршруты табылмады.');
  String get mapOffRouteDetected => _t(
      'Ты отклонился от маршрута. Перестраиваем путь.',
      'Сен маршруттан ауытқыдың. Жол қайта есептелуде.');
  String mapOffRouteDistance(int meters) => _t(
      'Отклонение от маршрута: $meters м. Перестраиваем путь.',
      'Маршруттан ауытқу: $meters м. Жол қайта есептелуде.');
  String get mapNextManeuver => _t('Следующий манёвр', 'Келесі маневр');
  String mapDistanceToManeuver(int meters) =>
      _t('через $meters м', '$meters м кейін');
  String get mapUpcomingSteps => _t('Ближайшие шаги', 'Жақын қадамдар');
  String get mapMetersLabel => _t('м', 'м');
  String mapEtaMinutes(int minutes) => _t('$minutes мин', '$minutes мин');
  String mapEtaHoursMinutes(int hours, int minutes) =>
      _t('$hours ч $minutes мин', '$hours сағ $minutes мин');
  String mapRemainingRoute(String distance, String eta) =>
      _t('Осталось: $distance • $eta', 'Қалды: $distance • $eta');
  String get mapVoiceHintsOn =>
      _t('Голосовые подсказки включены', 'Дауыстық кеңестер қосулы');
  String get mapVoiceHintsOff =>
      _t('Голосовые подсказки выключены', 'Дауыстық кеңестер өшірулі');
  String get mapOpenGoogleMapsFallback =>
      _t('Открыть в Google Maps (fallback)', 'Google Maps-та ашу (fallback)');
  String get mapVoiceOffRoutePrompt => _t(
      'Ты отклонился от маршрута. Перестраиваю путь.',
      'Сен маршруттан ауытқыдың. Жолды қайта есептеймін.');
  String get mapVoiceReroutingPrompt =>
      _t('Маршрут обновлён.', 'Маршрут жаңартылды.');
  String mapVoiceSoonPrompt(int meters, String instruction) => _t(
      'Через $meters метров $instruction',
      '$meters метрден кейін $instruction');
  String mapVoiceNowPrompt(String instruction) =>
      _t('Сейчас $instruction', 'Қазір $instruction');

  // ───────── Profile ─────────
  String get profileTitle => _t('Профиль', 'Профиль');
  String get tourist => _t('Турист', 'Турист');
  String get questsLabel => _t('Квестов', 'Квесттер');
  String get badgesLabel => _t('Бейджей', 'Белгілер');
  String get leaderboardTitle => _t('Рейтинг', 'Рейтинг');
  String get leaderboardTopLabel => _t('Топ игроков', 'Топ ойыншылар');
  String get leaderboardYourRank => _t('Ваше место', 'Сіздің орныңыз');
  String get leaderboardYou => _t('Вы', 'Сіз');
  String get leaderboardUnranked => _t('—', '—');
  String get leaderboardEmpty =>
      _t('Пока нет данных рейтинга', 'Рейтинг деректері әзірге жоқ');
  String get leaderboardLoadError =>
      _t('Не удалось загрузить рейтинг', 'Рейтингті жүктеу мүмкін болмады');
  String get achievements => _t('Достижения', 'Жетістіктер');
  String get history => _t('История', 'Тарих');
  String get languageLabel => _t('Язык / Тіл', 'Тіл / Язык');
  String get adminOnlyAccessLabel =>
      _t('Только для администратора', 'Тек әкімшіге арналған');
  String get adminAccessDeniedMessage => _t(
      'У тебя нет доступа к админ-разделу. Открыт профиль.',
      'Саған әкімші бөліміне рұқсат жоқ. Профиль ашылды.');
  String get russian => _t('Русский', 'Орысша');
  String get kazakh => _t('Қазақша', 'Қазақша');
  String get confirmSignOut => _t(
        'Вы уверены, что хотите выйти из аккаунта?',
        'Аккаунттан шығуға сенімдісіз бе?',
      );

  // ───────── Achievements ─────────
  String get achievementsTitle => _t('Достижения', 'Жетістіктер');
  String get noAchievements => _t('Нет достижений', 'Жетістіктер жоқ');
  String get earned => _t('Получено', 'Алынды');
  String get notEarned => _t('Не получено', 'Алынбады');
  String get achievementEarnedLabel => _t('Получено', 'Алынды');
  String get achievementLockedLabel => _t('Не получено', 'Алынбады');

  // ───────── History ─────────
  String get historyTitle => _t('История', 'Тарих');
  String get noHistory => _t('История пуста', 'Тарих бос');
  String get completed => _t('Завершён', 'Аяқталды');
  String get inProgress => _t('В процессе', 'Жүруде');
  String get abandoned => _t('Прерван', 'Тоқтатылды');
  String score(int s) => _t('Счёт: $s', 'Ұпай: $s');
  String time(String t) => _t('Время: $t', 'Уақыт: $t');
  String durationHoursMinutes(int hours, int minutes) =>
      _t('$hoursч $minutesм', '$hoursсағ $minutesмин');
  String durationMinutes(int minutes) => _t('$minutesм', '$minutesмин');
  String get pageNotFound => _t('Страница не найдена', 'Бет табылмады');

  // ───────── Admin Content ─────────
  String get adminContentTitle =>
      _t('Управление контентом', 'Контентті басқару');
  String get adminCreateQuest => _t('Создать квест', 'Квест құру');
  String get adminEditQuest => _t('Редактировать', 'Өңдеу');
  String get adminDeleteQuest => _t('Удалить', 'Жою');
  String get adminEmptyContent => _t(
        'Квестов пока нет. Создайте первый черновик.',
        'Квесттер әлі жоқ. Алғашқы черновикті жасаңыз.',
      );
  String get adminDeleteQuestConfirmTitle =>
      _t('Удалить квест?', 'Квестті жою керек пе?');
  String adminDeleteQuestConfirmBody(String title) => _t(
        'Квест "$title" будет удалён вместе с точками и заданиями.',
        '"$title" квесті нүктелерімен және тапсырмаларымен бірге жойылады.',
      );
  String get adminDeleteSuccess => _t('Квест удалён', 'Квест сәтті жойылды');
  String get adminStatusActive => _t('Активен', 'Белсенді');
  String get adminStatusDraft => _t('Черновик', 'Қаралама');
  String get adminQuestEditorTitle => _t('Редактор квеста', 'Квест редакторы');
  String get adminQuestEditorLoadError => _t(
      'Не удалось загрузить контент квеста',
      'Квест контентін жүктеу мүмкін болмады');
  String get adminSaveSuccess =>
      _t('Изменения сохранены', 'Өзгерістер сақталды');
  String get adminQuestBaseFields =>
      _t('Базовые поля квеста', 'Квесттің негізгі өрістері');
  String get adminFieldTitle => _t('Название', 'Атауы');
  String get adminFieldCity => _t('Город', 'Қала');
  String get adminFieldDescription => _t('Описание', 'Сипаттама');
  String get adminFieldEstimatedDuration => _t(
        'Длительность (мин)',
        'Ұзақтығы (мин)',
      );
  String get adminFieldDifficulty => _t('Сложность', 'Күрделілік');
  String get adminFieldDistance => _t('Дистанция (км)', 'Қашықтық (км)');
  String get adminFieldPoints => _t('Очки', 'Ұпай');
  String get adminFieldActive =>
      _t('Публиковать (active)', 'Жариялау (active)');
  String get adminLocationsJsonLabel =>
      _t('JSON точек маршрута', 'Маршрут нүктелерінің JSON-ы');
  String get adminTasksJsonLabel => _t('JSON заданий', 'Тапсырмалар JSON-ы');
  String get adminLocationsJsonHelp => _t(
        'Редактируй массив объектов локаций: id, name, description, historicalInfo, latitude, longitude, imageUrl, audioUrl, taskId, radiusMeters.',
        'Локациялар объектілер массивін өңде: id, name, description, historicalInfo, latitude, longitude, imageUrl, audioUrl, taskId, radiusMeters.',
      );
  String get adminTasksJsonHelp => _t(
        'Редактируй массив заданий: id, locationId, type, question, hint, points, options, correctOptionIndex, correctAnswer, timeLimitSeconds.',
        'Тапсырмалар массивін өңде: id, locationId, type, question, hint, points, options, correctOptionIndex, correctAnswer, timeLimitSeconds.',
      );
  String adminValidationRequired(String field) =>
      _t('Поле "$field" обязательно', '"$field" өрісі міндетті');
  String get adminValidationInvalidNumber => _t(
        'Введите корректное неотрицательное число',
        'Дұрыс теріс емес сан енгізіңіз',
      );
  String adminInvalidLocationsJson(String details) => _t(
      'Некорректный JSON локаций: $details', 'Локациялар JSON қате: $details');
  String adminInvalidTasksJson(String details) => _t(
      'Некорректный JSON заданий: $details', 'Тапсырмалар JSON қате: $details');
  String get adminLocationsMustBeArray => _t(
      'Локации должны быть JSON-массивом',
      'Локациялар JSON массив болуы керек');
  String get adminTasksMustBeArray => _t('Задания должны быть JSON-массивом',
      'Тапсырмалар JSON массив болуы керек');
  String adminLocationsItemMustBeObject(int index) => _t(
        'Локация #$index должна быть JSON-объектом',
        'Локация #$index JSON объект болуы керек',
      );
  String adminTasksItemMustBeObject(int index) => _t(
        'Задание #$index должно быть JSON-объектом',
        'Тапсырма #$index JSON объект болуы керек',
      );
  String adminLocationIdRequired(int index) => _t(
      'Локация #$index: обязательное поле id', 'Локация #$index: id міндетті');
  String adminLocationNameRequired(int index) => _t(
        'Локация #$index: обязательное поле name',
        'Локация #$index: name міндетті',
      );
  String adminLocationCoordinatesRequired(int index) => _t(
        'Локация #$index: latitude/longitude обязательны',
        'Локация #$index: latitude/longitude міндетті',
      );
  String adminTaskIdRequired(int index) => _t(
      'Задание #$index: обязательное поле id', 'Тапсырма #$index: id міндетті');
  String adminTaskLocationRequired(int index) => _t(
        'Задание #$index: обязательное поле locationId',
        'Тапсырма #$index: locationId міндетті',
      );
  String adminTaskQuestionRequired(int index) => _t(
        'Задание #$index: обязательное поле question',
        'Тапсырма #$index: question міндетті',
      );
  String adminTaskTypeInvalid(int index, String type) => _t(
        'Задание #$index: неизвестный type "$type"',
        'Тапсырма #$index: белгісіз type "$type"',
      );
  String adminTaskLocationUnknown(int index, String locationId) => _t(
        'Задание #$index: locationId "$locationId" не найден среди локаций',
        'Тапсырма #$index: locationId "$locationId" локациялардан табылмады',
      );
  String adminLocationTaskUnknown(int index, String taskId) => _t(
        'Локация #$index: taskId "$taskId" не найден среди заданий',
        'Локация #$index: taskId "$taskId" тапсырмалардан табылмады',
      );
  String get adminEvidenceModerationTitle =>
      _t('Статус evidence (модерация v1)', 'Evidence күйі (модерация v1)');
  String get adminEvidenceModerationHint => _t(
      'Только чтение: последние статусы из активного прогресса по photo/findObject.',
      'Тек оқу: photo/findObject үшін белсенді прогрестегі соңғы күйлер.');
  String get adminEvidenceNoPhotoTasks => _t(
      'В этом квесте нет photo/findObject задач.',
      'Бұл квестте photo/findObject тапсырмалары жоқ.');
  String get adminEvidenceStatusNoData => _t('Нет данных', 'Дерек жоқ');
  String adminEvidenceRecords(int count) =>
      _t('Записей: $count', 'Жазба: $count');
  String adminEvidenceUpdatedAt(String value) =>
      _t('Обновлено: $value', 'Жаңартылды: $value');
  String get adminEvidenceLoadError => _t(
      'Не удалось загрузить статусы evidence',
      'Evidence күйлерін жүктеу мүмкін болмады');
  String get adminModerationQueueTitle =>
      _t('Очередь модерации', 'Модерация кезегі');
  String get adminModerationQueueOpen =>
      _t('Очередь модерации evidence', 'Evidence модерация кезегі');
  String get adminModerationEmpty => _t(
      'В очереди нет доказательств на проверку.',
      'Тексеруге дәлелдер кезегі бос.');
  String get adminModerationLoadError => _t(
      'Не удалось загрузить очередь модерации',
      'Модерация кезегін жүктеу мүмкін болмады');
  String get adminModerationApprove => _t('Одобрить', 'Қабылдау');
  String get adminModerationReject => _t('Отклонить', 'Қайтару');
  String get adminModerationRejectDialogTitle =>
      _t('Причина отклонения', 'Қайтару себебі');
  String get adminModerationRejectReasonLabel =>
      _t('Комментарий для пользователя', 'Пайдаланушыға пікір');
  String get adminModerationRejectReasonHint => _t(
      'Например: фото размыто, объект не попал в кадр',
      'Мысалы: фото бұлыңғыр, объект кадрға түспеген');
  String get adminModerationRejectReasonRequired =>
      _t('Укажи причину отклонения', 'Қайтару себебін көрсет');
  String get adminModerationActionError => _t(
      'Не удалось выполнить действие модерации',
      'Модерация әрекетін орындау мүмкін болмады');
  String get adminModerationApprovedSuccess =>
      _t('Доказательство одобрено', 'Дәлел қабылданды');
  String get adminModerationRejectedSuccess =>
      _t('Доказательство отклонено', 'Дәлел қайтарылды');
  String get adminModerationUserLabel => _t('Пользователь', 'Пайдаланушы');
  String get adminModerationQuestTaskLabel =>
      _t('Квест / Задание', 'Квест / Тапсырма');
  String get adminModerationAnsweredAtLabel =>
      _t('Отправлено', 'Жіберілген уақыты');
  String get adminModerationEvidencePreviewLabel =>
      _t('Превью evidence', 'Evidence превью');
  String get adminModerationPreviewUnavailable =>
      _t('Превью недоступно', 'Превью қолжетімсіз');

  // ───────── Difficulty ─────────
  String difficultyLabel(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return difficultyEasy;
      case 'medium':
        return difficultyMedium;
      case 'hard':
        return difficultyHard;
      default:
        return difficulty;
    }
  }

  // ───────── Auth Errors ─────────
  String authErrorMessage(AuthErrorType type) {
    switch (type) {
      case AuthErrorType.userNotFound:
        return _t('Пользователь не найден', 'Пайдаланушы табылмады');
      case AuthErrorType.wrongPassword:
        return _t('Неверный пароль', 'Құпия сөз дұрыс емес');
      case AuthErrorType.emailAlreadyInUse:
        return _t('Email уже зарегистрирован', 'Email тіркелген');
      case AuthErrorType.weakPassword:
        return _t('Пароль слишком простой (мин. 6 символов)',
            'Құпия сөз тым қарапайым (мин. 6 таңба)');
      case AuthErrorType.invalidEmail:
        return _t('Некорректный email', 'Email дұрыс емес');
      case AuthErrorType.networkError:
        return _t('Нет подключения к интернету', 'Интернетке қосылу жоқ');
      case AuthErrorType.cancelled:
        return _t('Вход отменён', 'Кіру тоқтатылды');
      case AuthErrorType.googleConfig:
        return _t(
          'Google вход не настроен для этого Android-приложения. Проверь package name, SHA-1 и OAuth-клиент в Firebase/Google Cloud.',
          'Google кіруі осы Android қосымшасы үшін бапталмаған. Firebase/Google Cloud ішіндегі package name, SHA-1 және OAuth-клиентті тексер.',
        );
      case AuthErrorType.unknown:
        return _t('Произошла ошибка. Попробуйте снова.',
            'Қате орын алды. Қайталаңыз.');
    }
  }

  // ───────── Quest Detail Errors ─────────
  String get questNotFound => _t('Квест не найден', 'Квест табылмады');
  String get loadError => _t('Ошибка загрузки', 'Жүктеу қатесі');

  // Хелпер для выбора строки по языку
  String _t(String ru, String kz) => language == AppLanguage.kz ? kz : ru;
}

/// Delegate для локализации
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    final supported = ['ru', 'kk'].contains(locale.languageCode);
    debugPrint(
        'AppLocalizationsDelegate: isSupported(${locale.languageCode}) = $supported');
    return supported;
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    debugPrint(
        'AppLocalizationsDelegate: Loading locale: ${locale.languageCode}');
    final language =
        locale.languageCode == 'kk' ? AppLanguage.kz : AppLanguage.ru;
    debugPrint(
        'AppLocalizationsDelegate: Created AppLocalizations with language: ${language.name}');
    return AppLocalizations(language: language);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
