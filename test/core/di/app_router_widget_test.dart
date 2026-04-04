import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:quest_guide/core/di/app_router.dart';
import 'package:quest_guide/core/l10n/app_localizations.dart';
import 'package:quest_guide/data/services/auth_service.dart';
import 'package:quest_guide/presentation/auth/cubit/auth_cubit.dart';
import 'package:quest_guide/presentation/auth/login_screen.dart';

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> authStateChanges() => const Stream<User?>.empty();
}

class _FakeGoogleSignIn extends Fake implements GoogleSignIn {}

AuthService _buildLoggedOutAuthService() {
  return AuthService(
    auth: _FakeFirebaseAuth(),
    firestore: FakeFirebaseFirestore(),
    googleSignIn: _FakeGoogleSignIn(),
  );
}

Widget _buildTestApp({
  required RouterConfig<Object> router,
  required AuthService authService,
}) {
  return BlocProvider(
    create: (_) => AuthCubit(authService: authService),
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('kk')],
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppRouter widget redirects (logged out)', () {
    testWidgets('redirects from /home to login', (tester) async {
      final authService = _buildLoggedOutAuthService();
      final router = AppRouter.createRouter(
        authService,
        initialLocation: AppRoutes.home,
      );

      await tester.pumpWidget(
        _buildTestApp(router: router, authService: authService),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('redirects from quest map route to login', (tester) async {
      final authService = _buildLoggedOutAuthService();
      final router = AppRouter.createRouter(
        authService,
        initialLocation: '/quest/q1/map',
      );

      await tester.pumpWidget(
        _buildTestApp(router: router, authService: authService),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}




