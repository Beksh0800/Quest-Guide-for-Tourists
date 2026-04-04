import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:quest_guide/core/di/app_router.dart';
import 'package:quest_guide/core/l10n/app_localizations.dart';
import 'package:quest_guide/core/l10n/locale_cubit.dart';
import 'package:quest_guide/core/theme/app_theme.dart';
import 'package:quest_guide/data/services/auth_service.dart';
import 'package:quest_guide/data/services/demo_data_seeder.dart';
import 'package:quest_guide/data/services/local_notification_service.dart';
import 'package:quest_guide/firebase_options.dart';
import 'package:quest_guide/presentation/auth/cubit/auth_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _configureGoogleMapsPlatform();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (_) {}

  if (!firebaseReady) {
    runApp(const _FatalStartupApp(
      message: 'Firebase initialization failed. Check .env and Firebase setup.',
    ));
    return;
  }

  try {
    await LocalNotificationService.instance.initialize();
  } catch (_) {}

  if (kDebugMode) {
    try {
      await DemoDataSeeder().seed();
    } catch (_) {}
  }

  try {
    final authService = AuthService();
    final initialLanguage = await LocaleCubit.loadInitialLanguage();

    final router = AppRouter.createRouter(
      authService,
      initialLocation: AppRoutes.home,
    );

    runApp(
      QuestGuideApp(
        authService: authService,
        router: router,
        initialLanguage: initialLanguage,
      ),
    );
  } catch (e) {
    runApp(_FatalStartupApp(message: 'App startup error: $e'));
  }
}

void _configureGoogleMapsPlatform() {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  final mapsPlatform = GoogleMapsFlutterPlatform.instance;
  if (mapsPlatform is GoogleMapsFlutterAndroid) {
    mapsPlatform.useAndroidViewSurface = true;
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
  final AppLanguage initialLanguage;

  const QuestGuideApp({
    super.key,
    required this.authService,
    required this.router,
    required this.initialLanguage,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => AuthCubit(authService: authService)..checkAuthStatus(),
        ),
        BlocProvider(
          create: (_) => LocaleCubit(initialLanguage: initialLanguage),
        ),
      ],
      child: BlocBuilder<LocaleCubit, AppLanguage>(
        builder: (context, language) {
          final locale = language == AppLanguage.kz
              ? const Locale('kk')
              : const Locale('ru');

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
        },
      ),
    );
  }
}
