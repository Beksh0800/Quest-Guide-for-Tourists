import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quest_guide/data/repositories/progress_repository.dart';
import 'package:quest_guide/data/repositories/quest_repository.dart';
import 'package:quest_guide/domain/models/quest_catalog_status.dart';
import 'package:quest_guide/domain/models/quest_progress.dart';
import 'package:quest_guide/presentation/quest/cubit/quest_detail_state.dart';

/// Cubit для детального просмотра квеста
class QuestDetailCubit extends Cubit<QuestDetailState> {
  final QuestRepository _questRepository;
  final ProgressRepository _progressRepository;

  QuestDetailCubit({
    required QuestRepository questRepository,
    ProgressRepository? progressRepository,
  })  : _questRepository = questRepository,
        _progressRepository = progressRepository ?? ProgressRepository(),
        super(const QuestDetailInitial());

  /// Загрузить квест с точками и заданиями
  Future<void> loadQuest(String questId) async {
    emit(const QuestDetailLoading());
    try {
      final quest = await _questRepository.getQuestById(questId);
      if (quest == null) {
        emit(const QuestDetailError('quest_not_found'));
        return;
      }

      final locations = await _questRepository.getLocations(questId);
      final tasks = await _questRepository.getTasks(questId);
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final activeProgress = userId == null
          ? null
          : await _progressRepository.getActiveProgress(userId, questId);
      final userHistory = userId == null
          ? const <QuestProgress>[]
          : await _progressRepository.getUserHistory(userId);

      final status = _resolveQuestStatus(
        activeProgress: activeProgress,
        history: userHistory,
        questId: questId,
      );

      emit(QuestDetailLoaded(
        quest: quest,
        locations: locations,
        tasks: tasks,
        questStatus: status,
        activeProgress: activeProgress,
      ));
    } catch (e) {
      emit(QuestDetailError('load_error:$e'));
    }
  }

  QuestCatalogStatus _resolveQuestStatus({
    required QuestProgress? activeProgress,
    required List<QuestProgress> history,
    required String questId,
  }) {
    if (activeProgress != null &&
        activeProgress.status == QuestStatus.inProgress) {
      return QuestCatalogStatus.inProgress;
    }

    final completed = history.any(
      (progress) =>
          progress.questId == questId &&
          progress.status == QuestStatus.completed,
    );
    if (completed) {
      return QuestCatalogStatus.completed;
    }

    return QuestCatalogStatus.notStarted;
  }
}
