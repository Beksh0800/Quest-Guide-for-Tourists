class TimeBonusResult {
  final int basePoints;
  final int bonusPoints;
  final int totalPoints;
  final double speedRatio;

  const TimeBonusResult({
    required this.basePoints,
    required this.bonusPoints,
    required this.totalPoints,
    required this.speedRatio,
  });

  bool get hasBonus => bonusPoints > 0;
}

/// Расчёт бонусных очков за скорость прохождения (ТЗ 4.6).
///
/// Формула:
/// bonus = round(basePoints * maxBonusRate * speedRatio),
/// где speedRatio = clamp((estimatedMinutes - elapsedMinutes) / estimatedMinutes, 0..1).
class TimeBonusService {
  static const double defaultMaxBonusRate = 0.25;

  final double maxBonusRate;

  const TimeBonusService({this.maxBonusRate = defaultMaxBonusRate})
      : assert(maxBonusRate >= 0 && maxBonusRate <= 1);

  TimeBonusResult calculate({
    required int basePoints,
    required int questEstimatedMinutes,
    required Duration completionDuration,
  }) {
    if (basePoints <= 0 || questEstimatedMinutes <= 0) {
      return TimeBonusResult(
        basePoints: basePoints < 0 ? 0 : basePoints,
        bonusPoints: 0,
        totalPoints: basePoints < 0 ? 0 : basePoints,
        speedRatio: 0,
      );
    }

    final elapsedMinutes = completionDuration.inSeconds <= 0
        ? 0.0
        : completionDuration.inSeconds / 60.0;
    final rawSpeedRatio =
        (questEstimatedMinutes - elapsedMinutes) / questEstimatedMinutes;
    final speedRatio = rawSpeedRatio.clamp(0.0, 1.0).toDouble();

    final bonusPoints = (basePoints * maxBonusRate * speedRatio).round();

    return TimeBonusResult(
      basePoints: basePoints,
      bonusPoints: bonusPoints,
      totalPoints: basePoints + bonusPoints,
      speedRatio: speedRatio,
    );
  }
}
