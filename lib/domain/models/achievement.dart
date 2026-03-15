import 'package:equatable/equatable.dart';

class Achievement extends Equatable {
  final String id;
  final String title;
  final String description;
  final String iconName;
  final int colorValue;
  final int version;
  final AchievementCondition condition;
  final AchievementConditionV2? conditionV2;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    this.iconName = 'emoji_events',
    this.colorValue = 0xFF1A73E8,
    this.version = 1,
    required this.condition,
    this.conditionV2,
  });

  factory Achievement.fromMap(Map<String, dynamic> map, String id) {
    final rawCondition = map['condition'];
    final condition = rawCondition is Map<String, dynamic>
        ? AchievementCondition.fromMap(rawCondition)
        : rawCondition is Map
            ? AchievementCondition.fromMap(
                Map<String, dynamic>.from(rawCondition))
            : const AchievementCondition(
                type: AchievementType.questsCompleted,
                targetValue: 1,
              );

    final rawConditionV2 = map['conditionV2'];
    final conditionV2 = rawConditionV2 is Map<String, dynamic>
        ? AchievementConditionV2.fromMap(rawConditionV2)
        : rawConditionV2 is Map
            ? AchievementConditionV2.fromMap(
                Map<String, dynamic>.from(rawConditionV2),
              )
            : null;

    return Achievement(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      iconName: map['iconName'] as String? ?? 'emoji_events',
      colorValue: map['colorValue'] as int? ?? 0xFF1A73E8,
      version: map['version'] as int? ?? 1,
      condition: condition,
      conditionV2: conditionV2,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'iconName': iconName,
      'colorValue': colorValue,
      'version': version,
      'condition': condition.toMap(),
      if (conditionV2 != null) 'conditionV2': conditionV2!.toMap(),
    };
  }

  @override
  List<Object?> get props => [id, title, version, condition, conditionV2];
}

class AchievementCondition extends Equatable {
  final AchievementType type;
  final int targetValue;

  const AchievementCondition({
    required this.type,
    required this.targetValue,
  });

  factory AchievementCondition.fromMap(Map<String, dynamic> map) {
    return AchievementCondition(
      type: AchievementType.values.firstWhere(
        (e) => e.name == (map['type'] as String? ?? 'questsCompleted'),
        orElse: () => AchievementType.questsCompleted,
      ),
      targetValue: map['targetValue'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'targetValue': targetValue,
    };
  }

  @override
  List<Object?> get props => [type, targetValue];
}

class AchievementConditionV2 extends Equatable {
  final AchievementRuleOperator operatorType;
  final List<AchievementRule> rules;

  const AchievementConditionV2({
    required this.operatorType,
    required this.rules,
  });

  factory AchievementConditionV2.fromMap(Map<String, dynamic> map) {
    final operatorRaw = map['operator'] as String? ?? 'all';
    final rulesRaw = map['rules'];

    final parsedRules = <AchievementRule>[];
    if (rulesRaw is List) {
      for (final item in rulesRaw) {
        if (item is Map<String, dynamic>) {
          parsedRules.add(AchievementRule.fromMap(item));
        } else if (item is Map) {
          parsedRules
              .add(AchievementRule.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    return AchievementConditionV2(
      operatorType: operatorRaw == 'any'
          ? AchievementRuleOperator.any
          : AchievementRuleOperator.all,
      rules: parsedRules,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'operator': operatorType.name,
      'rules': rules.map((rule) => rule.toMap()).toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [operatorType, rules];
}

class AchievementRule extends Equatable {
  final AchievementRuleType type;
  final int targetValue;
  final String? questId;
  final List<String> cityIds;
  final int? startHour;
  final int? endHour;

  const AchievementRule({
    required this.type,
    this.targetValue = 0,
    this.questId,
    this.cityIds = const <String>[],
    this.startHour,
    this.endHour,
  });

  factory AchievementRule.fromMap(Map<String, dynamic> map) {
    final typeRaw = map['type'] as String? ?? 'questsCompleted';
    final parsedType = AchievementRuleType.values.firstWhere(
      (value) => value.name == typeRaw,
      orElse: () => AchievementRuleType.questsCompleted,
    );
    final cityIdsRaw = map['cityIds'];
    final cityIds = cityIdsRaw is List
        ? cityIdsRaw
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    return AchievementRule(
      type: parsedType,
      targetValue: map['targetValue'] as int? ?? 0,
      questId: (map['questId'] as String?)?.trim(),
      cityIds: cityIds,
      startHour: map['startHour'] as int?,
      endHour: map['endHour'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'targetValue': targetValue,
      if (questId != null && questId!.trim().isNotEmpty) 'questId': questId,
      if (cityIds.isNotEmpty) 'cityIds': cityIds,
      if (startHour != null) 'startHour': startHour,
      if (endHour != null) 'endHour': endHour,
    };
  }

  @override
  List<Object?> get props =>
      [type, targetValue, questId, cityIds, startHour, endHour];
}

class AchievementProgressSnapshot extends Equatable {
  final bool achieved;
  final double progressPercent;
  final String progressText;

  const AchievementProgressSnapshot({
    required this.achieved,
    required this.progressPercent,
    required this.progressText,
  });

  @override
  List<Object?> get props => [achieved, progressPercent, progressText];
}

enum AchievementType {
  questsCompleted,
  totalPoints,
  perfectScore,
  speedRun,
  citiesVisited,
  photosUploaded,
  reviewsLeft,
}

enum AchievementRuleOperator {
  all,
  any,
}

enum AchievementRuleType {
  questsCompleted,
  totalPoints,
  perfectScore,
  speedRun,
  citiesVisited,
  photosUploaded,
  reviewsLeft,
  streakDays,
  specificQuestCompleted,
  allCitiesVisited,
  timeOfDay,
}
