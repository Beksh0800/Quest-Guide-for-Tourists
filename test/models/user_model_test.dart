import 'package:flutter_test/flutter_test.dart';
import 'package:quest_guide/domain/models/user_model.dart';

void main() {
  group('UserModel.fromMap / toMap', () {
    test('roundtrip preserves all fields', () {
      final now = DateTime(2025, 6, 15, 10, 30);
      final original = UserModel(
        id: 'u1',
        name: 'Test User',
        email: 'test@example.com',
        photoUrl: 'https://example.com/photo.jpg',
        role: 'admin',
        isAdmin: true,
        totalPoints: 500,
        questsCompleted: 3,
        earnedBadgeIds: const ['badge1', 'badge2'],
        createdAt: now,
      );

      final map = original.toMap();
      final restored = UserModel.fromMap(map, 'u1');

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.email, original.email);
      expect(restored.photoUrl, original.photoUrl);
      expect(restored.role, original.role);
      expect(restored.isAdmin, isTrue);
      expect(restored.totalPoints, original.totalPoints);
      expect(restored.questsCompleted, original.questsCompleted);
      expect(restored.earnedBadgeIds, original.earnedBadgeIds);
    });

    test('fromMap handles missing optional fields', () {
      final user = UserModel.fromMap({
        'name': 'Min',
        'email': 'min@test.com',
        'createdAt': DateTime.now().toIso8601String(),
      }, 'u2');

      expect(user.id, 'u2');
      expect(user.name, 'Min');
      expect(user.photoUrl, isNull);
      expect(user.role, 'user');
      expect(user.isAdmin, isFalse);
      expect(user.totalPoints, 0);
      expect(user.questsCompleted, 0);
      expect(user.earnedBadgeIds, isEmpty);
    });

    test('fromMap marks admin when role is admin even without isAdmin flag',
        () {
      final user = UserModel.fromMap({
        'name': 'Admin',
        'email': 'admin@test.com',
        'role': 'admin',
        'createdAt': DateTime.now().toIso8601String(),
      }, 'admin-1');

      expect(user.role, 'admin');
      expect(user.isAdmin, isTrue);
    });

    test('fromMap keeps safe default isAdmin=false when role and flag absent',
        () {
      final user = UserModel.fromMap({
        'name': 'Regular',
        'email': 'user@test.com',
        'createdAt': DateTime.now().toIso8601String(),
      }, 'user-1');

      expect(user.isAdmin, isFalse);
      expect(user.role, 'user');
    });
  });

  group('UserModel.copyWith', () {
    test('copies with updated fields', () {
      final original = UserModel(
        id: 'u1',
        name: 'User',
        email: 'user@test.com',
        createdAt: DateTime(2025, 1, 1),
      );

      final updated = original.copyWith(
        name: 'Updated User',
        totalPoints: 100,
        earnedBadgeIds: ['b1'],
        role: 'admin',
        isAdmin: true,
      );

      expect(updated.name, 'Updated User');
      expect(updated.totalPoints, 100);
      expect(updated.earnedBadgeIds, ['b1']);
      expect(updated.role, 'admin');
      expect(updated.isAdmin, isTrue);
      // Unchanged
      expect(updated.id, 'u1');
      expect(updated.email, 'user@test.com');
    });

    test('copyWith preserves earnedBadgeIds when not provided', () {
      final original = UserModel(
        id: 'u1',
        name: 'User',
        email: 'user@test.com',
        earnedBadgeIds: const ['b1', 'b2'],
        createdAt: DateTime(2025, 1, 1),
      );

      final updated = original.copyWith(totalPoints: 50);
      expect(updated.earnedBadgeIds, ['b1', 'b2']);
      expect(updated.isAdmin, isFalse);
      expect(updated.role, 'user');
    });
  });
}
