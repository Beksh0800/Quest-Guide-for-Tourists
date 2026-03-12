import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quest_guide/data/repositories/progress_repository.dart';
import 'package:quest_guide/data/repositories/quest_repository.dart';
import 'package:quest_guide/domain/models/quest_catalog_status.dart';
import 'package:quest_guide/domain/models/quest_progress.dart';
import 'package:quest_guide/presentation/home/cubit/quest_list_state.dart';

/// Cubit для загрузки и фильтрации квестов
class QuestListCubit extends Cubit<QuestListState> {
  final QuestRepository _questRepository;
  final ProgressRepository _progressRepository;

  QuestListCubit({
    required QuestRepository questRepository,
    ProgressRepository? progressRepository,
  })  : _questRepository = questRepository,
        _progressRepository = progressRepository ?? ProgressRepository(),
        super(const QuestListInitial());

  /// Загрузить все квесты и города
  Future<void> loadQuests() async {
    emit(const QuestListLoading());
    try {
      final quests = await _questRepository.getQuests();
      final cities = await _questRepository.getCities();
      final statuses =
          await _resolveQuestStatuses(quests.map((q) => q.id).toSet());
      emit(QuestListLoaded(
          quests: quests, cities: cities, questStatuses: statuses));
    } catch (e) {
      emit(QuestListError('Не удалось загрузить квесты: $e'));
    }
  }

  Future<Map<String, QuestCatalogStatus>> _resolveQuestStatuses(
    Set<String> questIds,
  ) async {
    final defaultStatuses = <String, QuestCatalogStatus>{
      for (final questId in questIds) questId: QuestCatalogStatus.notStarted,
    };

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return defaultStatuses;
    }

    final history = await _progressRepository.getUserHistory(userId);

    for (final progress in history) {
      if (!questIds.contains(progress.questId)) continue;

      final nextStatus = _statusFromProgress(progress);
      final currentStatus =
          defaultStatuses[progress.questId] ?? QuestCatalogStatus.notStarted;

      if (_priority(nextStatus) > _priority(currentStatus)) {
        defaultStatuses[progress.questId] = nextStatus;
      }
    }

    return defaultStatuses;
  }

  QuestCatalogStatus _statusFromProgress(QuestProgress progress) {
    switch (progress.status) {
      case QuestStatus.completed:
        return QuestCatalogStatus.completed;
      case QuestStatus.inProgress:
        return QuestCatalogStatus.inProgress;
      case QuestStatus.abandoned:
        return QuestCatalogStatus.notStarted;
    }
  }

  int _priority(QuestCatalogStatus status) {
    switch (status) {
      case QuestCatalogStatus.notStarted:
        return 0;
      case QuestCatalogStatus.completed:
        return 1;
      case QuestCatalogStatus.inProgress:
        return 2;
    }
  }

  /// Фильтровать по городу
  void selectCity(String? city) {
    final currentState = state;
    if (currentState is QuestListLoaded) {
      if (city == null || city.isEmpty) {
        emit(currentState.copyWith(clearCity: true));
      } else {
        emit(currentState.copyWith(selectedCity: city));
      }
    }
  }
}
