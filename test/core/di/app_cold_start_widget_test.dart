import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quest_guide/core/di/app_router.dart';
import 'package:quest_guide/core/l10n/app_localizations.dart';
import 'package:quest_guide/core/l10n/locale_cubit.dart';
import 'package:quest_guide/data/repositories/progress_repository.dart';
import 'package:quest_guide/domain/models/quest_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'cold start opens map route and applies saved kk locale',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        LocaleCubit.storageKey: AppLanguage.kz.name,
      });

      final repo = ProgressRepository(firestore: FakeFirebaseFirestore());
      await repo.startQuest(
        userId: 'u1',
        questId: 'q1',
        initialLocationIndex: 1,
        initialStage: QuestRunStage.navigating,
      );

      final initialLanguage = await LocaleCubit.loadInitialLanguage();
      final initialLocation = await AppRouter.resolveInitialLocation(
        null,
        progressRepository: repo,
        userIdOverride: 'u1',
      );

      final router = GoRouter(
        initialLocation: initialLocation,
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(body: Text('HOME_SCREEN')),
          ),
          GoRoute(
            path: '/quest/:questId/map',
            builder: (context, state) => Scaffold(
              body: Column(
                children: [
                  const Text('MAP_SCREEN'),
                  Text('route:${state.uri.path}'),
                  Text(AppLocalizations.of(context).retry),
                ],
              ),
            ),
          ),
          GoRoute(
            path: '/quest/:questId/task/:locationIndex',
            builder: (context, state) => Scaffold(
              body: Column(
                children: [
                  const Text('TASK_SCREEN'),
                  Text('route:${state.uri.path}'),
                  Text(AppLocalizations.of(context).retry),
                ],
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          locale: initialLanguage == AppLanguage.kz
              ? const Locale('kk')
              : const Locale('ru'),
          routerConfig: router,
          supportedLocales: const [Locale('ru'), Locale('kk')],
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('MAP_SCREEN'), findsOneWidget);
      expect(find.text('route:/quest/q1/map'), findsOneWidget);
      expect(find.text('Қайталау'), findsOneWidget);
    },
  );

  testWidgets(
    'cold start opens task route and applies saved kk locale',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        LocaleCubit.storageKey: AppLanguage.kz.name,
      });

      final repo = ProgressRepository(firestore: FakeFirebaseFirestore());
      final progress = await repo.startQuest(
        userId: 'u1',
        questId: 'q1',
        initialLocationIndex: 2,
        initialStage: QuestRunStage.navigating,
      );
      await repo.transitionToTask(
        progressId: progress.id,
        locationIndex: 2,
      );

      final initialLanguage = await LocaleCubit.loadInitialLanguage();
      final initialLocation = await AppRouter.resolveInitialLocation(
        null,
        progressRepository: repo,
        userIdOverride: 'u1',
      );

      final router = GoRouter(
        initialLocation: initialLocation,
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(body: Text('HOME_SCREEN')),
          ),
          GoRoute(
            path: '/quest/:questId/map',
            builder: (context, state) => Scaffold(
              body: Column(
                children: [
                  const Text('MAP_SCREEN'),
                  Text('route:${state.uri.path}'),
                  Text(AppLocalizations.of(context).retry),
                ],
              ),
            ),
          ),
          GoRoute(
            path: '/quest/:questId/task/:locationIndex',
            builder: (context, state) => Scaffold(
              body: Column(
                children: [
                  const Text('TASK_SCREEN'),
                  Text('route:${state.uri.path}'),
                  Text(AppLocalizations.of(context).retry),
                ],
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          locale: initialLanguage == AppLanguage.kz
              ? const Locale('kk')
              : const Locale('ru'),
          routerConfig: router,
          supportedLocales: const [Locale('ru'), Locale('kk')],
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('TASK_SCREEN'), findsOneWidget);
      expect(find.text('route:/quest/q1/task/2'), findsOneWidget);
      expect(find.text('Қайталау'), findsOneWidget);
    },
  );
}


