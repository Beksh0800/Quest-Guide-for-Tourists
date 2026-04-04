import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quest_guide/core/di/app_router.dart';
import 'package:quest_guide/core/l10n/app_localizations.dart';
import 'package:quest_guide/core/l10n/locale_cubit.dart';
import 'package:quest_guide/data/repositories/progress_repository.dart';
import 'package:quest_guide/domain/models/quest_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('cold start restores saved language', () async {
    final cubit = LocaleCubit(initialLanguage: AppLanguage.ru);
    await cubit.setLanguage(AppLanguage.kz);
    await cubit.close();

    final restoredLanguage = await LocaleCubit.loadInitialLanguage();

    expect(restoredLanguage, AppLanguage.kz);
  });

  test('cold start resumes active quest at map stage', () async {
    final repo = ProgressRepository(firestore: FakeFirebaseFirestore());

    await repo.startQuest(
      userId: 'u1',
      questId: 'q1',
      initialLocationIndex: 1,
      initialStage: QuestRunStage.navigating,
    );

    final initialLocation = await AppRouter.resolveInitialLocation(
      null,
      progressRepository: repo,
      userIdOverride: 'u1',
    );

    expect(initialLocation, '/quest/q1/map');
  });

  test('cold start resumes active quest at task stage', () async {
    final repo = ProgressRepository(firestore: FakeFirebaseFirestore());

    final progress = await repo.startQuest(
      userId: 'u1',
      questId: 'q1',
      initialLocationIndex: 2,
      initialStage: QuestRunStage.navigating,
    );

    await repo.transitionToTask(
      progressId: progress.id,
      locationIndex: 2,
    );

    final initialLocation = await AppRouter.resolveInitialLocation(
      null,
      progressRepository: repo,
      userIdOverride: 'u1',
    );

    expect(initialLocation, '/quest/q1/task/2');
  });
}

