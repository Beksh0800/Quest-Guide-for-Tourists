import 'package:equatable/equatable.dart';
import 'package:quest_guide/domain/models/user_model.dart';

/// Типы ошибок авторизации
enum AuthErrorType {
  userNotFound,
  wrongPassword,
  emailAlreadyInUse,
  weakPassword,
  invalidEmail,
  networkError,
  cancelled,
  googleConfig,
  unknown,
}

/// Состояния авторизации
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Начальное / проверка
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Загрузка
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Авторизован
class AuthAuthenticated extends AuthState {
  final UserModel user;
  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

/// Не авторизован
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Ошибка
class AuthError extends AuthState {
  final AuthErrorType type;
  const AuthError(this.type);

  @override
  List<Object?> get props => [type];
}
