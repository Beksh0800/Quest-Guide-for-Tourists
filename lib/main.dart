import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:quest_guide/core/di/app_router.dart';
import 'package:quest_guide/core/l10n/app_localizations.dart';
import 'package:quest_guide/core/l10n/locale_cubit.dart';
import 'package:quest_guide/core/theme/app_theme.dart';
import 'package:quest_guide/data/services/auth_service.dart';
import 'package:quest_guide/data/services/demo_data_seeder.dart';
import 'package:quest_guide/data/services/local_notification_service.dart';
import 'package:quest_guide/firebase_options.dart';
import 'package:quest_guide/presentation/auth/cubit/auth_cubit.dart';

void main() async {
  debugPrint('=== MAIN STARTED ===');

  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('✓ WidgetsFlutterBinding initialized');

  try {
    await dotenv.load(fileName: '.env');
    debugPrint('✓ .env loaded');
  } catch (e) {
    debugPrint('⚠ .env loading failed: $e');
  }

  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    firebaseReady = true;
    debugPrint('✓ Firebase initialized successfully');
  } catch (e) {
    debugPrint('✗ Firebase initialization failed: $e');
  }

  if (!firebaseReady) {
    runApp(const _FatalStartupApp(
      message:
          'Не удалось инициализировать Firebase. Проверьте .env и настройки Firebase.',
    ));
    return;
  }

  try {
    await LocalNotificationService.instance.initialize();
    debugPrint('✓ LocalNotificationService initialized');
  } catch (e) {
    debugPrint('✗ LocalNotificationService initialization failed: $e');
  }

  // Временно отключаем seed данных для избежания ошибок прав доступа
  if (kDebugMode) {
    try {
      await DemoDataSeeder().seed();
      debugPrint('✓ Demo data seeded successfully');
    } catch (e) {
      // Игнорируем ошибки прав доступа при seed данных
      debugPrint('⚠ Demo data seeding skipped: $e');
    }
  }

  try {
    final authService = AuthService();
    debugPrint('✓ AuthService created');

    final router = AppRouter.createRouter(authService);
    debugPrint('✓ Router created');

    debugPrint('=== STARTING APP ===');
    runApp(QuestGuideApp(authService: authService, router: router));
  } catch (e) {
    debugPrint('✗ App initialization failed: $e');
    runApp(_FatalStartupApp(message: 'Ошибка запуска приложения: $e'));
  }
}

class _FatalStartupApp extends StatelessWidget {
  final String message;

  const _FatalStartupApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              message,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class QuestGuideApp extends StatelessWidget {
  final AuthService authService;
  final RouterConfig<Object> router;

  const QuestGuideApp({
    super.key,
    required this.authService,
    required this.router,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('QuestGuideApp: Building widget...');

    try {
      return MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) {
              debugPrint('QuestGuideApp: Creating AuthCubit...');
              final cubit = AuthCubit(authService: authService)
                ..checkAuthStatus();
              debugPrint(
                  'QuestGuideApp: AuthCubit created and checkAuthStatus called');
              return cubit;
            },
          ),
          BlocProvider(create: (_) {
            debugPrint('QuestGuideApp: Creating LocaleCubit...');
            final cubit = LocaleCubit();
            debugPrint('QuestGuideApp: LocaleCubit created');
            return cubit;
          }),
        ],
        child: BlocBuilder<LocaleCubit, AppLanguage>(
          builder: (context, language) {
            debugPrint(
                'QuestGuideApp: BlocBuilder building with language: ${language.name}');

            try {
              final locale = language == AppLanguage.kz
                  ? const Locale('kk')
                  : const Locale('ru');

              debugPrint(
                  'QuestGuideApp: Creating MaterialApp.router with locale: $locale');

              return MaterialApp.router(
                title: 'Quest Guide',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                routerConfig: router,
                locale: locale,
                supportedLocales: const [
                  Locale('ru'),
                  Locale('kk'),
                ],
                localizationsDelegates: const [
                  AppLocalizationsDelegate(),
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
              );
            } catch (e) {
              debugPrint('QuestGuideApp: Error in BlocBuilder: $e');
              rethrow;
            }
          },
        ),
      );
    } catch (e) {
      debugPrint('QuestGuideApp: Critical error in build: $e');
      rethrow;
    }
  }
}
