import 'package:equatable/equatable.dart';
import 'package:quest_guide/domain/models/quest_catalog_status.dart';
import 'package:quest_guide/domain/models/quest.dart';

/// Состояния списка квестов
abstract class QuestListState extends Equatable {
  const QuestListState();

  @override
  List<Object?> get props => [];
}

class QuestListInitial extends QuestListState {
  const QuestListInitial();
}

class QuestListLoading extends QuestListState {
  const QuestListLoading();
}

class QuestListLoaded extends QuestListState {
  final List<Quest> quests;
  final List<String> cities;
  final Map<String, QuestCatalogStatus> questStatuses;
  final String? selectedCity;

  const QuestListLoaded({
    required this.quests,
    required this.cities,
    required this.questStatuses,
    this.selectedCity,
  });

  List<Quest> get filteredQuests {
    if (selectedCity == null || selectedCity!.isEmpty) return quests;
    return quests.where((q) => q.city == selectedCity).toList();
  }

  QuestCatalogStatus statusForQuest(String questId) {
    return questStatuses[questId] ?? QuestCatalogStatus.notStarted;
  }

  QuestListLoaded copyWith({
    List<Quest>? quests,
    List<String>? cities,
    Map<String, QuestCatalogStatus>? questStatuses,
    String? selectedCity,
    bool clearCity = false,
  }) {
    return QuestListLoaded(
      quests: quests ?? this.quests,
      cities: cities ?? this.cities,
      questStatuses: questStatuses ?? this.questStatuses,
      selectedCity: clearCity ? null : (selectedCity ?? this.selectedCity),
    );
  }

  @override
  List<Object?> get props => [quests, cities, questStatuses, selectedCity];
}

class QuestListError extends QuestListState {
  final String message;
  const QuestListError(this.message);

  @override
  List<Object?> get props => [message];
}
