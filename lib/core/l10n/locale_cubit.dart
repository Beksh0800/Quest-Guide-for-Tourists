import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:quest_guide/core/l10n/app_localizations.dart';

/// Cubit для управления языком приложения
class LocaleCubit extends Cubit<AppLanguage> {
  LocaleCubit() : super(AppLanguage.ru) {
    debugPrint('LocaleCubit initialized with language: ${state.name}');
  }

  Future<void> setLanguage(AppLanguage language) async {
    debugPrint(
        'LocaleCubit: Setting language from ${state.name} to ${language.name}');
    try {
      emit(language);
      debugPrint(
          'LocaleCubit: Language successfully changed to ${language.name}');
    } catch (e) {
      debugPrint('LocaleCubit: Error changing language: $e');
    }
  }

  void toggleLanguage() {
    final newLanguage =
        state == AppLanguage.ru ? AppLanguage.kz : AppLanguage.ru;
    debugPrint('LocaleCubit: Toggling language to ${newLanguage.name}');
    setLanguage(newLanguage);
  }
}
