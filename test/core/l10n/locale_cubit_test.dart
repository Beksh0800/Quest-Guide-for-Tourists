import 'package:flutter_test/flutter_test.dart';
import 'package:quest_guide/core/l10n/app_localizations.dart';
import 'package:quest_guide/core/l10n/locale_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loadInitialLanguage returns saved language', () async {
    SharedPreferences.setMockInitialValues({
      LocaleCubit.storageKey: AppLanguage.kz.name,
    });

    final language = await LocaleCubit.loadInitialLanguage();

    expect(language, AppLanguage.kz);
  });

  test('loadInitialLanguage falls back to ru by default', () async {
    final language = await LocaleCubit.loadInitialLanguage();

    expect(language, AppLanguage.ru);
  });

  test('setLanguage persists selected language', () async {
    final cubit = LocaleCubit(initialLanguage: AppLanguage.ru);

    await cubit.setLanguage(AppLanguage.kz);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(LocaleCubit.storageKey), AppLanguage.kz.name);
    expect(cubit.state, AppLanguage.kz);

    await cubit.close();
  });
}

