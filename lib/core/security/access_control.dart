/// Единая точка проверки ролей и доступа к admin-функционалу.
class AccessControl {
  static const String superuserRole = 'superuser';
  static const String adminRole = 'admin';
  static const String userRole = 'user';

  static bool isSuperuserRole(String? role) {
    final normalized = role?.trim().toLowerCase();
    return normalized == superuserRole;
  }

  static bool isAdminRole(String? role) {
    final normalized = role?.trim().toLowerCase();
    return normalized == adminRole;
  }

  static bool hasAdminAccess({
    required bool isAdminFlag,
    String? role,
  }) {
    return isAdminFlag || isAdminRole(role) || isSuperuserRole(role);
  }

  static bool isAdminRoutePath(String path) {
    final normalized = path.trim();
    return normalized.startsWith('/admin');
  }
}
