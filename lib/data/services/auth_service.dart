import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:quest_guide/core/security/access_control.dart';
import 'package:quest_guide/domain/models/user_model.dart';

class AuthConfigurationException implements Exception {
  final String code;
  final String message;

  const AuthConfigurationException({required this.code, required this.message});

  @override
  String toString() =>
      'AuthConfigurationException(code=$code, message=$message)';
}

/// Сервис аутентификации Firebase
class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  /// Текущий пользователь Firebase
  User? get currentUser => _auth.currentUser;

  /// Стрим изменения состояния авторизации
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<bool> isCurrentUserAdmin() async {
    final user = currentUser;
    if (user == null) return false;

    try {
      final model = await _getUserModel(user.uid);
      return AccessControl.hasAdminAccess(
        isAdminFlag: model.isAdmin,
        role: model.role,
      );
    } on FirebaseException {
      return false;
    } on Exception {
      return false;
    }
  }

  /// Регистрация по email + пароль
  Future<UserModel> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await credential.user?.updateDisplayName(name);

    final userModel = UserModel(
      id: credential.user!.uid,
      name: name,
      email: email,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection('users')
        .doc(userModel.id)
        .set(userModel.toMap());

    await _upsertLeaderboardProfile(userModel);

    return userModel;
  }

  /// Вход по email + пароль
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    return _getUserModel(credential.user!.uid);
  }

  /// Вход через Google
  Future<UserModel> signInWithGoogle() async {
    _logAuthStep('Google sign-in started');
    try {
      // Initialize GoogleSignIn (required in v7.x)
      await _googleSignIn.initialize();
      final googleUser = await _googleSignIn.authenticate();
      _logAuthStep('Google account selected: ${googleUser.email}');

      // In GoogleSignIn 7.x, we need to get authorization separately
      const scopes = ['email'];
      final authorization =
          await googleUser.authorizationClient.authorizationForScopes(scopes);
      final accessToken = authorization?.accessToken;
      final idToken = googleUser.authentication.idToken;

      _logAuthStep(
        'Google tokens received (authorization=${authorization != null}, idToken=${idToken != null})',
      );

      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user!;
      _logAuthStep('Firebase credential sign-in success (uid=${user.uid})');

      return _loadOrCreateUserModel(user);
    } on PlatformException catch (e, st) {
      _logAuthStep(
        'PlatformException during Google sign-in: code=${e.code}, message=${e.message}, details=${e.details}',
      );
      final normalized = '${e.code} ${e.message} ${e.details}'.toLowerCase();
      if (normalized.contains('developer_error') ||
          normalized.contains('apiexception: 10') ||
          normalized.contains('unknown calling package')) {
        throw const AuthConfigurationException(
          code: 'google-sign-in-config',
          message:
              'Google Sign-In Android configuration mismatch (package name/SHA-1/OAuth client).',
        );
      }
      debugPrintStack(stackTrace: st);
      rethrow;
    } on FirebaseAuthException catch (e, st) {
      _logAuthStep(
        'FirebaseAuthException during Google sign-in: code=${e.code}, message=${e.message}',
      );
      debugPrintStack(stackTrace: st);
      rethrow;
    } on FirebaseException catch (e, st) {
      _logAuthStep(
        'FirebaseException during Google sign-in: plugin=${e.plugin}, code=${e.code}, message=${e.message}',
      );
      debugPrintStack(stackTrace: st);
      rethrow;
    } catch (e, st) {
      _logAuthStep('Unexpected error during Google sign-in: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }

  void _logAuthStep(String message) {
    if (kDebugMode) {
      debugPrint('[AuthService] $message');
    }
  }

  /// Выход
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Получить модель текущего пользователя
  Future<UserModel?> getCurrentUserModel() async {
    final user = currentUser;
    if (user == null) return null;
    return _getUserModel(user.uid);
  }

  /// Обновить профиль
  Future<void> updateUserProfile(UserModel user) async {
    await _firestore.collection('users').doc(user.id).update(user.toMap());
    await _upsertLeaderboardProfile(user);
  }

  /// Приватный метод — получить UserModel из Firestore
  Future<UserModel> _getUserModel(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) {
        final fbUser = _auth.currentUser;
        if (fbUser != null) {
          return _loadOrCreateUserModel(fbUser);
        }
        throw StateError('Пользователь Firebase Auth отсутствует для uid=$uid');
      }
      final userModel = UserModel.fromMap(doc.data()!, uid);
      await _upsertLeaderboardProfile(userModel);
      return userModel;
    } on FirebaseException catch (e) {
      final fbUser = _auth.currentUser;
      if (fbUser != null &&
          fbUser.uid == uid &&
          _isRecoverableFirestoreException(e)) {
        _logAuthStep(
          'Firestore unavailable while loading user model (code=${e.code}); using FirebaseAuth fallback',
        );
        return _buildUserModelFromFirebaseUser(fbUser);
      }
      rethrow;
    }
  }

  Future<UserModel> _loadOrCreateUserModel(User user) async {
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        final userModel = _buildUserModelFromFirebaseUser(user);
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(userModel.toMap());
        await _upsertLeaderboardProfile(userModel);
        _logAuthStep('User profile created in Firestore');
        return userModel;
      }

      _logAuthStep('User profile loaded from Firestore');
      final userModel = UserModel.fromMap(doc.data()!, user.uid);
      await _upsertLeaderboardProfile(userModel);
      return userModel;
    } on FirebaseException catch (e) {
      if (_isRecoverableFirestoreException(e)) {
        _logAuthStep(
          'Firestore unavailable while syncing profile (code=${e.code}); using FirebaseAuth fallback',
        );
        return _buildUserModelFromFirebaseUser(user);
      }
      rethrow;
    }
  }

  UserModel _buildUserModelFromFirebaseUser(User user) {
    return UserModel(
      id: user.uid,
      name: user.displayName ?? 'Tourist',
      email: user.email ?? '',
      photoUrl: user.photoURL,
      createdAt: DateTime.now(),
    );
  }

  bool _isRecoverableFirestoreException(FirebaseException e) {
    return e.plugin == 'cloud_firestore' &&
        (e.code == 'permission-denied' ||
            e.code == 'failed-precondition' ||
            e.code == 'unavailable');
  }

  Future<void> _upsertLeaderboardProfile(UserModel user) async {
    try {
      await _firestore.collection('leaderboard').doc(user.id).set(
        {
          'name': user.name,
          'photoUrl': user.photoUrl,
          'totalPoints': user.totalPoints,
          'questsCompleted': user.questsCompleted,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      _logAuthStep(
          'Leaderboard profile sync skipped (code=${e.code}, plugin=${e.plugin})');
    } on Exception {
      _logAuthStep('Leaderboard profile sync skipped due to unexpected error');
    }
  }
}
