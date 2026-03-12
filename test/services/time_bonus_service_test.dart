import 'package:flutter_test/flutter_test.dart';
import 'package:quest_guide/data/services/time_bonus_service.dart';

void main() {
  group('TimeBonusService.calculate', () {
    const service = TimeBonusService();

    test('returns proportional bonus for faster completion', () {
      final result = service.calculate(
        basePoints: 200,
        questEstimatedMinutes: 100,
        completionDuration: const Duration(minutes: 50),
      );

      expect(result.basePoints, 200);
      expect(result.speedRatio, 0.5);
      expect(result.bonusPoints, 25);
      expect(result.totalPoints, 225);
      expect(result.hasBonus, isTrue);
    });

    test('returns zero bonus when completed exactly in estimated time', () {
      final result = service.calculate(
        basePoints: 180,
        questEstimatedMinutes: 90,
        completionDuration: const Duration(minutes: 90),
      );

      expect(result.speedRatio, 0);
      expect(result.bonusPoints, 0);
      expect(result.totalPoints, 180);
      expect(result.hasBonus, isFalse);
    });

    test('returns zero bonus when completed slower than estimate', () {
      final result = service.calculate(
        basePoints: 150,
        questEstimatedMinutes: 60,
        completionDuration: const Duration(minutes: 95),
      );

      expect(result.speedRatio, 0);
      expect(result.bonusPoints, 0);
      expect(result.totalPoints, 150);
    });

    test('caps speed ratio and max bonus for very fast completion', () {
      final result = service.calculate(
        basePoints: 120,
        questEstimatedMinutes: 80,
        completionDuration: const Duration(seconds: 0),
      );

      expect(result.speedRatio, 1);
      expect(result.bonusPoints, 30); // 120 * 0.25
      expect(result.totalPoints, 150);
    });

    test('returns zero bonus for invalid inputs', () {
      final zeroEstimated = service.calculate(
        basePoints: 100,
        questEstimatedMinutes: 0,
        completionDuration: const Duration(minutes: 10),
      );
      final zeroBase = service.calculate(
        basePoints: 0,
        questEstimatedMinutes: 60,
        completionDuration: const Duration(minutes: 10),
      );
      final negativeBase = service.calculate(
        basePoints: -40,
        questEstimatedMinutes: 60,
        completionDuration: const Duration(minutes: 10),
      );

      expect(zeroEstimated.bonusPoints, 0);
      expect(zeroEstimated.totalPoints, 100);

      expect(zeroBase.bonusPoints, 0);
      expect(zeroBase.totalPoints, 0);

      expect(negativeBase.basePoints, 0);
      expect(negativeBase.bonusPoints, 0);
      expect(negativeBase.totalPoints, 0);
    });

    test('supports custom max bonus rate', () {
      const custom = TimeBonusService(maxBonusRate: 0.4);

      final result = custom.calculate(
        basePoints: 100,
        questEstimatedMinutes: 100,
        completionDuration: const Duration(minutes: 50),
      );

      // speedRatio = 0.5, bonus = 100 * 0.4 * 0.5
      expect(result.bonusPoints, 20);
      expect(result.totalPoints, 120);
    });
  });
}
