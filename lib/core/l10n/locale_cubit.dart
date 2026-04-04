import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:quest_guide/core/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cubit для управления языком приложения
class LocaleCubit extends Cubit<AppLanguage> {
  static const String storageKey = 'app_language';

  LocaleCubit({AppLanguage initialLanguage = AppLanguage.ru})
      : super(initialLanguage) {
    debugPrint('LocaleCubit initialized with language: ${state.name}');
  }

  static Future<AppLanguage> loadInitialLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedValue = (prefs.getString(storageKey) ?? '').trim();
      return AppLanguage.values.firstWhere(
        (language) => language.name == savedValue,
        orElse: () => AppLanguage.ru,
      );
    } catch (e) {
      debugPrint('LocaleCubit: Failed to load persisted language: $e');
      return AppLanguage.ru;
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    debugPrint(
        'LocaleCubit: Setting language from ${state.name} to ${language.name}');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, language.name);
      emit(language);
      debugPrint(
          'LocaleCubit: Language successfully changed to ${language.name}');
    } catch (e) {
      debugPrint('LocaleCubit: Error changing language: $e');
    }
  }

  Future<void> toggleLanguage() async {
    final newLanguage =
        state == AppLanguage.ru ? AppLanguage.kz : AppLanguage.ru;
    debugPrint('LocaleCubit: Toggling language to ${newLanguage.name}');
    await setLanguage(newLanguage);
  }
}
