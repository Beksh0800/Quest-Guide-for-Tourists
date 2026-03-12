import 'package:flutter_test/flutter_test.dart';
import 'package:quest_guide/core/security/access_control.dart';

void main() {
  group('AccessControl.isAdminRole', () {
    test('returns true for admin role with mixed case and spaces', () {
      expect(AccessControl.isAdminRole('  AdMiN  '), isTrue);
    });

    test('returns false for null and non-admin roles', () {
      expect(AccessControl.isAdminRole(null), isFalse);
      expect(AccessControl.isAdminRole('user'), isFalse);
      expect(AccessControl.isAdminRole('moderator'), isFalse);
    });
  });

  group('AccessControl.hasAdminAccess', () {
    test('returns true when isAdmin flag is true', () {
      expect(
        AccessControl.hasAdminAccess(isAdminFlag: true, role: 'user'),
        isTrue,
      );
    });

    test('returns true when role is admin', () {
      expect(
        AccessControl.hasAdminAccess(isAdminFlag: false, role: 'admin'),
        isTrue,
      );
    });

    test('returns false when no admin signal exists', () {
      expect(
        AccessControl.hasAdminAccess(isAdminFlag: false, role: 'user'),
        isFalse,
      );
    });
  });

  group('AccessControl.isAdminRoutePath', () {
    test('detects admin prefixed routes', () {
      expect(AccessControl.isAdminRoutePath('/admin/content'), isTrue);
      expect(
        AccessControl.isAdminRoutePath('/admin/content/quest/quest-1'),
        isTrue,
      );
      expect(AccessControl.isAdminRoutePath('/admin/moderation'), isTrue);
    });

    test('returns false for non-admin routes', () {
      expect(AccessControl.isAdminRoutePath('/home'), isFalse);
      expect(AccessControl.isAdminRoutePath('/profile'), isFalse);
    });
  });
}
