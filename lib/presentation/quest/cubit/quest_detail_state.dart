import 'package:equatable/equatable.dart';
import 'package:quest_guide/domain/models/quest_catalog_status.dart';
import 'package:quest_guide/domain/models/quest.dart';
import 'package:quest_guide/domain/models/quest_location.dart';
import 'package:quest_guide/domain/models/quest_progress.dart';
import 'package:quest_guide/domain/models/quest_task.dart';

/// Состояния детального экрана квеста
abstract class QuestDetailState extends Equatable {
  const QuestDetailState();

  @override
  List<Object?> get props => [];
}

class QuestDetailInitial extends QuestDetailState {
  const QuestDetailInitial();
}

class QuestDetailLoading extends QuestDetailState {
  const QuestDetailLoading();
}

class QuestDetailLoaded extends QuestDetailState {
  final Quest quest;
  final List<QuestLocation> locations;
  final List<QuestTask> tasks;
  final QuestCatalogStatus questStatus;
  final QuestProgress? activeProgress;

  const QuestDetailLoaded({
    required this.quest,
    required this.locations,
    required this.tasks,
    required this.questStatus,
    this.activeProgress,
  });

  @override
  List<Object?> get props =>
      [quest, locations, tasks, questStatus, activeProgress];
}

class QuestDetailError extends QuestDetailState {
  final String message;
  const QuestDetailError(this.message);

  @override
  List<Object?> get props => [message];
}
