import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quest_guide/data/repositories/user_repository.dart';
import 'package:quest_guide/domain/models/user_model.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late UserRepository repo;

  setUp(() {
    UserRepository.resetLocalCache();
    fakeFirestore = FakeFirebaseFirestore();
    repo = UserRepository(firestore: fakeFirestore);
  });

  group('UserRepository', () {
    test('saveUser creates a user document', () async {
      final user = UserModel(
        id: 'u1',
        name: 'Test User',
        email: 'test@test.com',
        createdAt: DateTime(2025, 1, 1),
      );

      await repo.saveUser(user);

      final doc = await fakeFirestore.collection('users').doc('u1').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['name'], 'Test User');
    });

    test('getUserById returns user', () async {
      final user = UserModel(
        id: 'u1',
        name: 'Test',
        email: 'test@test.com',
        totalPoints: 100,
        questsCompleted: 2,
        createdAt: DateTime(2025, 1, 1),
      );
      await repo.saveUser(user);

      final fetched = await repo.getUserById('u1');
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Test');
      expect(fetched.totalPoints, 100);
      expect(fetched.questsCompleted, 2);
    });

    test('getUserById returns null for nonexistent', () async {
      final result = await repo.getUserById('nonexistent');
      expect(result, isNull);
    });

    test('saveUser merges data without overwriting', () async {
      final user = UserModel(
        id: 'u1',
        name: 'Original',
        email: 'test@test.com',
        totalPoints: 100,
        createdAt: DateTime(2025, 1, 1),
      );
      await repo.saveUser(user);

      // Save with only name updated
      final updated = user.copyWith(name: 'Updated');
      await repo.saveUser(updated);

      final fetched = await repo.getUserById('u1');
      expect(fetched!.name, 'Updated');
      expect(fetched.totalPoints, 100); // preserved
    });

    test('addPoints increments total points', () async {
      final user = UserModel(
        id: 'u1',
        name: 'Test',
        email: 'test@test.com',
        totalPoints: 100,
        createdAt: DateTime(2025, 1, 1),
      );
      await repo.saveUser(user);

      await repo.addPoints('u1', 50);

      final fetched = await repo.getUserById('u1');
      expect(fetched!.totalPoints, 150);
    });

    test('incrementQuestsCompleted increments count', () async {
      final user = UserModel(
        id: 'u1',
        name: 'Test',
        email: 'test@test.com',
        questsCompleted: 2,
        createdAt: DateTime(2025, 1, 1),
      );
      await repo.saveUser(user);

      await repo.incrementQuestsCompleted('u1');

      final fetched = await repo.getUserById('u1');
      expect(fetched!.questsCompleted, 3);
    });

    test('addBadge appends badge ID without duplicates', () async {
      final user = UserModel(
        id: 'u1',
        name: 'Test',
        email: 'test@test.com',
        earnedBadgeIds: const ['b1'],
        createdAt: DateTime(2025, 1, 1),
      );
      await repo.saveUser(user);

      await repo.addBadge('u1', 'b2');

      final fetched = await repo.getUserById('u1');
      expect(fetched!.earnedBadgeIds, containsAll(['b1', 'b2']));
    });

    test('addBadge does not duplicate existing badge', () async {
      final user = UserModel(
        id: 'u1',
        name: 'Test',
        email: 'test@test.com',
        earnedBadgeIds: const ['b1'],
        createdAt: DateTime(2025, 1, 1),
      );
      await repo.saveUser(user);

      await repo.addBadge('u1', 'b1'); // duplicate

      final fetched = await repo.getUserById('u1');
      expect(fetched!.earnedBadgeIds.length, 1);
    });

    test('updateLanguage saves language preference', () async {
      final user = UserModel(
        id: 'u1',
        name: 'Test',
        email: 'test@test.com',
        createdAt: DateTime(2025, 1, 1),
      );
      await repo.saveUser(user);

      await repo.updateLanguage('u1', 'kk');

      final doc = await fakeFirestore.collection('users').doc('u1').get();
      expect(doc.data()!['language'], 'kk');
    });

    test('watchUser emits updates', () async {
      final user = UserModel(
        id: 'u1',
        name: 'Test',
        email: 'test@test.com',
        createdAt: DateTime(2025, 1, 1),
      );
      await repo.saveUser(user);

      final stream = repo.watchUser('u1');
      final first = await stream.first;
      expect(first, isNotNull);
      expect(first!.name, 'Test');
    });

    test('getTopUsers sorts by points, then questsCompleted, then id',
        () async {
      final users = [
        UserModel(
          id: 'u3',
          name: 'User 3',
          email: 'u3@test.com',
          totalPoints: 300,
          questsCompleted: 1,
          createdAt: DateTime(2025, 1, 1),
        ),
        UserModel(
          id: 'u2',
          name: 'User 2',
          email: 'u2@test.com',
          totalPoints: 300,
          questsCompleted: 4,
          createdAt: DateTime(2025, 1, 1),
        ),
        UserModel(
          id: 'u1',
          name: 'User 1',
          email: 'u1@test.com',
          totalPoints: 300,
          questsCompleted: 4,
          createdAt: DateTime(2025, 1, 1),
        ),
        UserModel(
          id: 'u4',
          name: 'User 4',
          email: 'u4@test.com',
          totalPoints: 150,
          questsCompleted: 10,
          createdAt: DateTime(2025, 1, 1),
        ),
      ];

      for (final user in users) {
        await repo.saveUser(user);
      }

      final top = await repo.getTopUsers(limit: 4);
      expect(top.map((u) => u.id).toList(), ['u1', 'u2', 'u3', 'u4']);
    });

    test('getTopUsers respects limit', () async {
      await repo.saveUser(
        UserModel(
          id: 'u1',
          name: 'User 1',
          email: 'u1@test.com',
          totalPoints: 10,
          createdAt: DateTime(2025, 1, 1),
        ),
      );
      await repo.saveUser(
        UserModel(
          id: 'u2',
          name: 'User 2',
          email: 'u2@test.com',
          totalPoints: 20,
          createdAt: DateTime(2025, 1, 1),
        ),
      );

      final top = await repo.getTopUsers(limit: 1);
      expect(top.length, 1);
      expect(top.first.id, 'u2');
    });

    test('getUserRank returns one-based rank', () async {
      await repo.saveUser(
        UserModel(
          id: 'u1',
          name: 'User 1',
          email: 'u1@test.com',
          totalPoints: 100,
          createdAt: DateTime(2025, 1, 1),
        ),
      );
      await repo.saveUser(
        UserModel(
          id: 'u2',
          name: 'User 2',
          email: 'u2@test.com',
          totalPoints: 250,
          createdAt: DateTime(2025, 1, 1),
        ),
      );
      await repo.saveUser(
        UserModel(
          id: 'u3',
          name: 'User 3',
          email: 'u3@test.com',
          totalPoints: 50,
          createdAt: DateTime(2025, 1, 1),
        ),
      );

      final rank = await repo.getUserRank('u1');
      expect(rank, 2);
    });

    test('getUserRank returns null for unknown user', () async {
      await repo.saveUser(
        UserModel(
          id: 'u1',
          name: 'User 1',
          email: 'u1@test.com',
          totalPoints: 100,
          createdAt: DateTime(2025, 1, 1),
        ),
      );

      final rank = await repo.getUserRank('unknown');
      expect(rank, isNull);
    });
  });
}
