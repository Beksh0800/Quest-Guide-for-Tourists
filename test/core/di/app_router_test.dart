import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quest_guide/core/di/app_router.dart';
import 'package:quest_guide/data/repositories/progress_repository.dart';
import 'package:quest_guide/domain/models/quest_progress.dart';

void main() {
  group('AppRouter.resolveRedirectTarget', () {
    test('redirects guest to login for protected route', () {
      final result = AppRouter.resolveRedirectTarget(
        loggedIn: false,
        isAuthRoute: false,
        isAdminRoute: false,
        isAdmin: false,
      );

      expect(result, AppRoutes.login);
    });

    test('redirects authenticated user away from auth route', () {
      final result = AppRouter.resolveRedirectTarget(
        loggedIn: true,
        isAuthRoute: true,
        isAdminRoute: false,
        isAdmin: false,
      );

      expect(result, AppRoutes.home);
    });

    test('allows authenticated non-admin user on regular route', () {
      final result = AppRouter.resolveRedirectTarget(
        loggedIn: true,
        isAuthRoute: false,
        isAdminRoute: false,
        isAdmin: false,
      );

      expect(result, isNull);
    });

    test('redirects authenticated non-admin user from admin route', () {
      final result = AppRouter.resolveRedirectTarget(
        loggedIn: true,
        isAuthRoute: false,
        isAdminRoute: true,
        isAdmin: false,
      );

      expect(result, AppRoutes.profileAdminDeniedLocation);
    });

    test('allows authenticated admin user on admin route', () {
      final result = AppRouter.resolveRedirectTarget(
        loggedIn: true,
        isAuthRoute: false,
        isAdminRoute: true,
        isAdmin: true,
      );

      expect(result, isNull);
    });
  });

  group('AppRouter.resolveResumeLocation', () {
    test('returns null when there is no active progress', () {
      expect(AppRouter.resolveResumeLocation(null), isNull);
    });

    test('returns map route for navigating stage', () {
      final progress = QuestProgress(
        id: 'p1',
        userId: 'u1',
        questId: 'q1',
        currentStage: QuestRunStage.navigating,
        currentLocationIndex: 2,
        startedAt: DateTime(2026, 1, 1),
      );

      expect(AppRouter.resolveResumeLocation(progress), '/quest/q1/map');
    });

    test('returns task route for task stage', () {
      final progress = QuestProgress(
        id: 'p1',
        userId: 'u1',
        questId: 'q1',
        currentStage: QuestRunStage.task,
        currentLocationIndex: 3,
        startedAt: DateTime(2026, 1, 1),
      );

      expect(AppRouter.resolveResumeLocation(progress), '/quest/q1/task/3');
    });
  });

  group('AppRouter.resolveInitialLocation', () {
    test('returns home when user has no active progress', () async {
      final repo = ProgressRepository(firestore: FakeFirebaseFirestore());

      final location = await AppRouter.resolveInitialLocation(
        null,
        progressRepository: repo,
        userIdOverride: 'u1',
      );

      expect(location, AppRoutes.home);
    });

    test('returns map when latest active progress is navigating', () async {
      final repo = ProgressRepository(firestore: FakeFirebaseFirestore());
      await repo.startQuest(
        userId: 'u1',
        questId: 'q1',
        initialLocationIndex: 2,
        initialStage: QuestRunStage.navigating,
      );

      final location = await AppRouter.resolveInitialLocation(
        null,
        progressRepository: repo,
        userIdOverride: 'u1',
      );

      expect(location, '/quest/q1/map');
    });

    test('returns task when latest active progress is task', () async {
      final repo = ProgressRepository(firestore: FakeFirebaseFirestore());
      final progress = await repo.startQuest(
        userId: 'u1',
        questId: 'q1',
        initialLocationIndex: 3,
        initialStage: QuestRunStage.task,
      );

      await repo.updateProgress(
        progress.copyWith(
          currentLocationIndex: 3,
          currentStage: QuestRunStage.task,
        ),
      );

      final location = await AppRouter.resolveInitialLocation(
        null,
        progressRepository: repo,
        userIdOverride: 'u1',
      );

      expect(location, '/quest/q1/task/3');
    });
  });
}
