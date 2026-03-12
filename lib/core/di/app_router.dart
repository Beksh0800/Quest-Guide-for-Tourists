import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quest_guide/core/l10n/app_localizations.dart';
import 'package:quest_guide/core/security/access_control.dart';
import 'package:quest_guide/data/services/auth_service.dart';
import 'package:quest_guide/presentation/auth/login_screen.dart';
import 'package:quest_guide/presentation/auth/register_screen.dart';
import 'package:quest_guide/presentation/home/home_screen.dart';
import 'package:quest_guide/presentation/quest/quest_detail_screen.dart';
import 'package:quest_guide/presentation/map/map_screen.dart';
import 'package:quest_guide/presentation/quest/task_screen.dart';
import 'package:quest_guide/presentation/quest/quest_complete_screen.dart';
import 'package:quest_guide/presentation/profile/profile_screen.dart';
import 'package:quest_guide/presentation/profile/achievements_screen.dart';
import 'package:quest_guide/presentation/profile/history_screen.dart';
import 'package:quest_guide/presentation/admin/content/admin_content_screen.dart';
import 'package:quest_guide/presentation/admin/content/admin_visual_quest_editor_screen.dart';
import 'package:quest_guide/presentation/admin/moderation/admin_moderation_queue_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String questDetail = '/quest/:questId';
  static const String map = '/quest/:questId/map';
  static const String task = '/quest/:questId/task/:locationIndex';
  static const String questComplete = '/quest/:questId/complete';
  static const String profile = '/profile';
  static const String achievements = '/profile/achievements';
  static const String history = '/profile/history';
  static const String adminContent = '/admin/content';
  static const String adminQuestEditor = '/admin/content/quest/:questId';
  static const String adminModerationQueue = '/admin/moderation';

  static const String adminDeniedQueryParam = 'denied';
  static const String adminDeniedQueryValue = 'admin';

  static String get profileAdminDeniedLocation =>
      '$profile?$adminDeniedQueryParam=$adminDeniedQueryValue';
}

class AppRouter {
  @visibleForTesting
  static String? resolveRedirectTarget({
    required bool loggedIn,
    required bool isAuthRoute,
    required bool isAdminRoute,
    required bool isAdmin,
  }) {
    if (!loggedIn && !isAuthRoute) return AppRoutes.login;
    if (loggedIn && isAuthRoute) return AppRoutes.home;
    if (loggedIn && isAdminRoute && !isAdmin) {
      return AppRoutes.profileAdminDeniedLocation;
    }
    return null;
  }

  static GoRouter createRouter(AuthService authService) {
    final refresh = GoRouterRefreshStream(authService.authStateChanges);

    return GoRouter(
      initialLocation: AppRoutes.home,
      refreshListenable: refresh,
      redirect: (context, state) async {
        final loggedIn = authService.currentUser != null;
        final path = state.uri.path;
        final isAuthRoute =
            path == AppRoutes.login || path == AppRoutes.register;
        final isAdminRoute = AccessControl.isAdminRoutePath(path);

        if (!loggedIn || isAuthRoute) {
          return resolveRedirectTarget(
            loggedIn: loggedIn,
            isAuthRoute: isAuthRoute,
            isAdminRoute: false,
            isAdmin: false,
          );
        }

        if (!isAdminRoute) {
          return resolveRedirectTarget(
            loggedIn: loggedIn,
            isAuthRoute: false,
            isAdminRoute: false,
            isAdmin: false,
          );
        }

        final isAdmin = await authService.isCurrentUserAdmin();
        return resolveRedirectTarget(
          loggedIn: loggedIn,
          isAuthRoute: false,
          isAdminRoute: true,
          isAdmin: isAdmin,
        );
      },
      routes: [
        GoRoute(
          path: AppRoutes.login,
          pageBuilder: (context, state) =>
              const MaterialPage(child: LoginScreen()),
        ),
        GoRoute(
          path: AppRoutes.register,
          pageBuilder: (context, state) =>
              const MaterialPage(child: RegisterScreen()),
        ),
        GoRoute(
          path: AppRoutes.home,
          pageBuilder: (context, state) =>
              const MaterialPage(child: HomeScreen()),
        ),
        GoRoute(
          path: AppRoutes.questDetail,
          pageBuilder: (context, state) {
            final questId = state.pathParameters['questId']!;
            return CustomTransitionPage(
              child: QuestDetailScreen(questId: questId),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.05),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
            );
          },
        ),
        GoRoute(
          path: AppRoutes.map,
          pageBuilder: (context, state) {
            final questId = state.pathParameters['questId']!;
            return CustomTransitionPage(
              child: MapScreen(questId: questId),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
            );
          },
        ),
        GoRoute(
          path: AppRoutes.task,
          pageBuilder: (context, state) {
            final questId = state.pathParameters['questId']!;
            final locationIndex = state.pathParameters['locationIndex']!;
            return MaterialPage(
              child: TaskScreen(questId: questId, locationIndex: locationIndex),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.questComplete,
          pageBuilder: (context, state) {
            final questId = state.pathParameters['questId']!;
            final score =
                int.tryParse(state.uri.queryParameters['score'] ?? '') ?? 0;
            final total =
                int.tryParse(state.uri.queryParameters['total'] ?? '') ?? 0;
            final progressId = state.uri.queryParameters['progressId'];
            final correctAnswers =
                int.tryParse(state.uri.queryParameters['correct'] ?? '') ?? 0;
            final totalAnswers =
                int.tryParse(state.uri.queryParameters['answers'] ?? '') ?? 0;
            return MaterialPage(
              child: QuestCompleteScreen(
                questId: questId,
                score: score,
                totalLocations: total,
                progressId: progressId,
                correctAnswers: correctAnswers,
                totalAnswers: totalAnswers,
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.profile,
          pageBuilder: (context, state) =>
              const MaterialPage(child: ProfileScreen()),
        ),
        GoRoute(
          path: AppRoutes.achievements,
          pageBuilder: (context, state) =>
              const MaterialPage(child: AchievementsScreen()),
        ),
        GoRoute(
          path: AppRoutes.history,
          pageBuilder: (context, state) =>
              const MaterialPage(child: HistoryScreen()),
        ),
        GoRoute(
          path: AppRoutes.adminContent,
          pageBuilder: (context, state) =>
              const MaterialPage(child: AdminContentScreen()),
        ),
        GoRoute(
          path: AppRoutes.adminQuestEditor,
          pageBuilder: (context, state) {
            final questId = state.pathParameters['questId']!;
            return MaterialPage(
              child: AdminVisualQuestEditorScreen(questId: questId),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.adminModerationQueue,
          pageBuilder: (context, state) =>
              const MaterialPage(child: AdminModerationQueueScreen()),
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Text(AppLocalizations.of(context).pageNotFound),
        ),
      ),
    );
  }
}

/// Converts a [Stream] into a [ChangeNotifier] so go_router can listen to it.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
