# PROJECT PLAN

## Сделано
- Базовая авторизация по Email/Password.
- Вход через Google.
- Базовый пользовательский профиль и хранение очков/бэйджей.
- Каталог квестов, точки маршрутов и задания (quiz/text/photo/findObject).
- Прохождение квеста с сохранением прогресса и завершением.
- История прохождений и экран достижений.
- Локализация RU/KZ.
- ТЗ 4.6: бонус за скорость прохождения (расчёт, сохранение, UI-пояснение, тесты).
- ТЗ 4.6: рейтинг пользователя (leaderboard + место текущего пользователя в профиле).
- ТЗ 4.4 (P0): реальные задания `photo` / `findObject` — выбор/съёмка фото, превью, замена, блок завершения без evidence, сохранение evidence в прогресс (с восстановлением), RU/KZ строки, тесты.
- Админ/контент MVP v1: CRUD квестов (создание черновика, сохранение, удаление), экран списка и редактор, JSON-редактирование points/tasks с parse-валидацией, роутинг из профиля, RU/KZ локализация, unit-тесты репозитория (Firestore + fallback).
- Cloud Evidence v1: расширена модель ответов (`evidenceStatus`, `evidenceRemotePath`, `evidenceError`) с backward compatibility для старых записей; добавлен cloud-first storage flow (локальное сохранение + upload + retry + metadata), backend хранения evidence переведён на Supabase Storage; в `task_screen` добавлена строгая cloud-валидация `photo/findObject` (submit только при `uploaded`) и UI статусов `pending/uploaded/failed`.
- Supabase Storage (evidence): bucket/policies применены через MCP, smoke test upload/delete прошёл успешно (HTTP 200/200).
- Moderation Workflow v1: добавлены moderation-поля в модель ответа (`moderationStatus`, `moderationComment`, `moderatedAt`, `moderatedBy`) с backward compatibility; реализованы repository-операции очереди `pendingReview` + approve/reject; добавлен отдельный admin moderation queue экран с действиями approve/reject и обновлением списка; в task UI отображается moderation status/comment и сценарий re-upload после reject с reset обратно в `pendingReview`; добавлены RU/KZ локализации и unit-тесты по сериализации и moderation workflow.
- Security rules + role-based admin access: добавлен единый role-check (`role/isAdmin`, безопасный дефолт `false`), закрыт доступ к `/admin/*` через router redirect, скрыты admin-пункты в профиле для не-админов, добавлены RU/KZ сообщения отказа, внедрены `firestore.rules` + `storage.rules`, подключение rules в `firebase.json`, вынесен публичный leaderboard в отдельную коллекцию без email/приватных полей, добавлены unit-тесты role-check и роут-ограничений.

## Частично
- Карта и навигационный поток есть, но требуется дальнейшая доработка UX/поведения в реальных сценариях.
- Админский контур контента карты работает на MVP-уровне: JSON-редактор locations/tasks функционален, но UX редактирования нужно улучшить (структурные формы, inline-валидация, меньше ручного JSON).
- RBAC закрыт на уровне `admin`, отдельная роль `superuser` поверх текущего admin пока не выделена.
- Система достижений реализована базово, но покрывает не все типы условий из ТЗ.

## Не сделано
- **Apple Sign-In отложен на финальный этап.**
- Полная продуктовая отладка offline/online сценариев и отказоустойчивости.

## План P0/P1/P2

### P0 (текущий приоритет)
1. ✅ Закрыт ТЗ 4.6: бонусы за скорость прохождения (расчёт + сохранение + отображение + тесты).
2. ✅ Закрыт ТЗ 4.6: рейтинг пользователя (репозиторий top/rank + UI-блок рейтинга в профиле + локализация + тесты).
3. ✅ Реализованы реальные `photo` / `findObject` задания (evidence-photo + проверка + восстановление прогресса + UI).
4. ✅ Повторная локальная валидация выполнена: `flutter test` и `flutter analyze`.
5. ✅ Закрыт MVP админ/контентного блока v1: базовый CRUD + JSON-редактор locations/tasks + маршрутизация + локализация + тесты.
6. ✅ Закрыт Cloud Evidence v1: cloud-валидация + storage + UI-статусы + retry + moderation foundation (read-only).
7. ✅ Закрыт Moderation Workflow v1: moderation queue + approve/reject + user-facing статусы + re-upload reset + тесты.
8. ✅ Закрыт security rules + role-based admin access для moderation/admin контуров.
9. ✅ Supabase Storage для evidence настроен через MCP; bucket/policies применены; smoke test upload/delete подтверждён (HTTP 200/200).
10. 🔜 Следующий шаг: P1 — UX карты/навигации + улучшение админского UX редактирования контента (points/tasks).

### P1
1. Доработать UX карты/навигации и стабильность сценариев прохождения (переходы между точками, предсказуемость состояния).
2. Улучшить админский UX для контента карты: структурные формы для locations/tasks, inline-валидация, снижение ручного редактирования JSON.
3. Уточнить RBAC-модель: при необходимости выделить роль `superuser` как отдельный уровень поверх `admin`.
4. Расширить систему достижений до полного покрытия условий ТЗ.
5. Улучшить экран истории прохождений (детализация статистики и метрик).

### P2
1. Реализовать Apple Sign-In (финальный этап).
2. Довести рейтинг пользователей до production-качества (опционально: пагинация, сезонность, кэширование/инкрементальный пересчёт).
3. Расширить admin-контур до прод-уровня (workflow публикации, аудит, история изменений).

## Текущий спринт
- Завершены: speed bonus + пользовательский рейтинг (leaderboard/rank) по ТЗ 4.6 + реальные `photo/findObject` задания по ТЗ 4.4 + **admin/content MVP v1** + **Cloud Evidence v1** + настройка Supabase Storage через MCP (bucket/policies + smoke test upload/delete HTTP 200/200).
- Следующий шаг: **P1 UX карты/навигации + админ UX контента карты** (редактирование points/tasks без ручного JSON как основного сценария).

## Supabase Storage (evidence) — статус
- Целевой bucket id для проекта: `quest-guide-for-tourists` (синхронизирован с `SUPABASE_STORAGE_BUCKET`).
- Подключение через Supabase MCP успешно, bucket и storage policies применены.
- Smoke test для evidence подтверждён: upload и delete отработали с HTTP 200/200.
- Текущий продуктовый компромисс безопасности: storage работает с public read + anon upload/delete в рамках path-based ограничений, т.к. приложение использует Firebase Auth и не держит Supabase user session.
- Next hardening: уйти от public read/anon write к более строгой схеме доступа (например, подписанные URL на чтение и серверный/edge-контур для записи/удаления с валидацией Firebase identity).
