import 'package:flutter_test/flutter_test.dart';
import 'package:quest_guide/core/di/app_router.dart';

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
}
