import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quest_guide/data/services/auth_service.dart';
import 'package:quest_guide/presentation/auth/cubit/auth_state.dart';

/// Cubit авторизации
class AuthCubit extends Cubit<AuthState> {
  final AuthService _authService;

  AuthCubit({required AuthService authService})
      : _authService = authService,
        super(const AuthInitial());

  /// Проверить текущее состояние авторизации
  Future<void> checkAuthStatus() async {
    try {
      final user = await _authService.getCurrentUserModel();
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      emit(const AuthUnauthenticated());
    }
  }

  /// Войти по email
  Future<void> signInWithEmail(String email, String password) async {
    emit(const AuthLoading());
    try {
      final user = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(_parseError(e)));
    }
  }

  /// Зарегистрироваться
  Future<void> registerWithEmail(
      String name, String email, String password) async {
    emit(const AuthLoading());
    try {
      final user = await _authService.registerWithEmail(
        name: name,
        email: email,
        password: password,
      );
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(_parseError(e)));
    }
  }

  /// Войти через Google
  Future<void> signInWithGoogle() async {
    emit(const AuthLoading());
    try {
      final user = await _authService.signInWithGoogle();
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(_parseError(e)));
    }
  }

  /// Выйти
  Future<void> signOut() async {
    await _authService.signOut();
    emit(const AuthUnauthenticated());
  }

  /// Парсинг ошибок Firebase → тип ошибки (UI локализует)
  AuthErrorType _parseError(dynamic error) {
    if (error is AuthConfigurationException) {
      return AuthErrorType.googleConfig;
    }

    if (error is Exception) {
      final message = error.toString().toLowerCase();
      if (message.contains('user-not-found')) {
        return AuthErrorType.userNotFound;
      } else if (message.contains('wrong-password') ||
          message.contains('invalid-credential')) {
        return AuthErrorType.wrongPassword;
      } else if (message.contains('email-already-in-use')) {
        return AuthErrorType.emailAlreadyInUse;
      } else if (message.contains('weak-password')) {
        return AuthErrorType.weakPassword;
      } else if (message.contains('invalid-email')) {
        return AuthErrorType.invalidEmail;
      } else if (message.contains('network-request-failed')) {
        return AuthErrorType.networkError;
      } else if (message.contains('cancelled') || message.contains('отменён')) {
        return AuthErrorType.cancelled;
      } else if (message.contains('developer_error') ||
          message.contains('unknown calling package') ||
          message.contains('google-sign-in-config') ||
          message.contains('apiexception: 10')) {
        return AuthErrorType.googleConfig;
      }
    }
    return AuthErrorType.unknown;
  }
}
