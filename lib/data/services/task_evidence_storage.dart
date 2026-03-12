import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:quest_guide/domain/models/quest_task.dart';
import 'package:supabase/supabase.dart';

/// Коды ошибок для сохранения/загрузки evidence.
class TaskEvidenceErrorCode {
  static const String unauthenticated = 'unauthenticated';
  static const String localFileMissing = 'local-file-missing';
  static const String cloudUnavailable = 'cloud-unavailable';
  static const String uploadFailed = 'upload-failed';
}

/// Метаданные evidence-файла для дальнейшей модерации.
class TaskEvidenceMetadata {
  final String questId;
  final String taskId;
  final String? userId;
  final DateTime timestamp;

  const TaskEvidenceMetadata({
    required this.questId,
    required this.taskId,
    required this.timestamp,
    this.userId,
  });

  Map<String, dynamic> toStorageMetadata() {
    return {
      'questId': questId,
      'taskId': taskId,
      if (userId != null && userId!.trim().isNotEmpty) 'userId': userId!.trim(),
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Результат сохранения evidence (локально + опционально облако).
class TaskEvidenceSaveResult {
  final String localPath;
  final EvidenceStatus status;
  final String? remotePath;
  final String? remoteDownloadUrl;
  final String? errorCode;
  final TaskEvidenceMetadata metadata;

  const TaskEvidenceSaveResult({
    required this.localPath,
    required this.status,
    required this.metadata,
    this.remotePath,
    this.remoteDownloadUrl,
    this.errorCode,
  });
}

/// Контракт хранилища доказательств выполнения заданий.
///
/// В v1 evidence всегда сначала сохраняется локально,
/// после чего выполняется попытка облачной загрузки.
abstract class TaskEvidenceStorage {
  Future<TaskEvidenceSaveResult> saveEvidence({
    required String questId,
    required String taskId,
    required String? userId,
    required XFile sourceFile,
  });

  Future<TaskEvidenceSaveResult> retryUpload({
    required String questId,
    required String taskId,
    required String? userId,
    required String localEvidencePath,
  });

  Future<void> deleteEvidence({
    String? localPath,
    String? remotePath,
  });

  String? resolvePreviewPath(String evidencePath);
}

/// Локальная fallback-реализация.
///
/// Сохраняет файл только на устройстве и помечает статус как pending.
class LocalTaskEvidenceStorage implements TaskEvidenceStorage {
  static const _folderName = 'task_evidence';

  @override
  Future<TaskEvidenceSaveResult> saveEvidence({
    required String questId,
    required String taskId,
    required String? userId,
    required XFile sourceFile,
  }) async {
    final now = DateTime.now();
    final localPath = await _saveLocally(
      questId: questId,
      taskId: taskId,
      sourceFilePath: sourceFile.path,
      timestamp: now,
    );

    return TaskEvidenceSaveResult(
      localPath: localPath,
      status: EvidenceStatus.pending,
      errorCode: TaskEvidenceErrorCode.cloudUnavailable,
      metadata: TaskEvidenceMetadata(
        questId: questId,
        taskId: taskId,
        userId: userId,
        timestamp: now,
      ),
    );
  }

  @override
  Future<TaskEvidenceSaveResult> retryUpload({
    required String questId,
    required String taskId,
    required String? userId,
    required String localEvidencePath,
  }) async {
    final now = DateTime.now();

    final localFile = File(localEvidencePath);
    if (!await localFile.exists()) {
      return TaskEvidenceSaveResult(
        localPath: localEvidencePath,
        status: EvidenceStatus.failed,
        errorCode: TaskEvidenceErrorCode.localFileMissing,
        metadata: TaskEvidenceMetadata(
          questId: questId,
          taskId: taskId,
          userId: userId,
          timestamp: now,
        ),
      );
    }

    return TaskEvidenceSaveResult(
      localPath: localEvidencePath,
      status: EvidenceStatus.pending,
      errorCode: TaskEvidenceErrorCode.cloudUnavailable,
      metadata: TaskEvidenceMetadata(
        questId: questId,
        taskId: taskId,
        userId: userId,
        timestamp: now,
      ),
    );
  }

  @override
  Future<void> deleteEvidence({
    String? localPath,
    String? remotePath,
  }) async {
    if (localPath == null || localPath.trim().isEmpty) return;

    final file = File(localPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  String? resolvePreviewPath(String evidencePath) {
    if (evidencePath.trim().isEmpty) return null;
    return evidencePath;
  }

  Future<String> saveFromLocalPath({
    required String questId,
    required String taskId,
    required String sourceFilePath,
    DateTime? timestamp,
  }) {
    return _saveLocally(
      questId: questId,
      taskId: taskId,
      sourceFilePath: sourceFilePath,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  Future<String> _saveLocally({
    required String questId,
    required String taskId,
    required String sourceFilePath,
    required DateTime timestamp,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(
      p.join(appDir.path, _folderName, questId, taskId),
    );
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final sourceExtension = p.extension(sourceFilePath);
    final extension = sourceExtension.isNotEmpty ? sourceExtension : '.jpg';
    final filename = '${timestamp.millisecondsSinceEpoch}$extension';
    final targetPath = p.join(targetDir.path, filename);

    await File(sourceFilePath).copy(targetPath);

    return targetPath;
  }
}

/// Runtime-конфиг для Supabase Storage evidence upload.
///
/// Значения читаются из --dart-define:
/// - SUPABASE_URL
/// - SUPABASE_ANON_KEY
/// - SUPABASE_STORAGE_BUCKET
class SupabaseEvidenceStorageConfig {
  static const String supabaseUrlDefineKey = 'SUPABASE_URL';
  static const String supabaseAnonKeyDefineKey = 'SUPABASE_ANON_KEY';
  static const String supabaseStorageBucketDefineKey =
      'SUPABASE_STORAGE_BUCKET';

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String storageBucket;

  const SupabaseEvidenceStorageConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.storageBucket,
  });

  factory SupabaseEvidenceStorageConfig.fromEnvironment() {
    return const SupabaseEvidenceStorageConfig(
      supabaseUrl: String.fromEnvironment(supabaseUrlDefineKey),
      supabaseAnonKey: String.fromEnvironment(supabaseAnonKeyDefineKey),
      storageBucket: String.fromEnvironment(supabaseStorageBucketDefineKey),
    );
  }

  bool get hasCredentials =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  bool get isConfigured => hasCredentials && storageBucket.trim().isNotEmpty;
}

/// Cloud-first реализация: локальное сохранение + попытка загрузки в Supabase.
class SupabaseTaskEvidenceStorage implements TaskEvidenceStorage {
  final SupabaseClient? _supabaseClient;
  final String _storageBucket;
  final LocalTaskEvidenceStorage _localStorage;
  final DateTime Function() _clock;

  factory SupabaseTaskEvidenceStorage({
    SupabaseEvidenceStorageConfig? config,
    SupabaseClient? supabaseClient,
    String? storageBucket,
    LocalTaskEvidenceStorage? localStorage,
    DateTime Function()? clock,
  }) {
    final resolvedConfig =
        config ?? SupabaseEvidenceStorageConfig.fromEnvironment();

    return SupabaseTaskEvidenceStorage._(
      config: resolvedConfig,
      supabaseClient: supabaseClient,
      storageBucket: storageBucket,
      localStorage: localStorage ?? LocalTaskEvidenceStorage(),
      clock: clock ?? DateTime.now,
    );
  }

  SupabaseTaskEvidenceStorage._({
    required SupabaseEvidenceStorageConfig config,
    required SupabaseClient? supabaseClient,
    required String? storageBucket,
    required LocalTaskEvidenceStorage localStorage,
    required DateTime Function() clock,
  })  : _localStorage = localStorage,
        _clock = clock,
        _storageBucket = (storageBucket ?? config.storageBucket).trim(),
        _supabaseClient = _resolveSupabaseClient(
          config: config,
          providedClient: supabaseClient,
        );

  static SupabaseClient? _resolveSupabaseClient({
    required SupabaseEvidenceStorageConfig config,
    required SupabaseClient? providedClient,
  }) {
    if (providedClient != null) {
      return providedClient;
    }

    if (!config.hasCredentials) {
      return null;
    }

    return SupabaseClient(
      config.supabaseUrl.trim(),
      config.supabaseAnonKey.trim(),
    );
  }

  bool get _isCloudConfigured =>
      _supabaseClient != null && _storageBucket.trim().isNotEmpty;

  @override
  Future<TaskEvidenceSaveResult> saveEvidence({
    required String questId,
    required String taskId,
    required String? userId,
    required XFile sourceFile,
  }) async {
    final now = _clock();
    final metadata = TaskEvidenceMetadata(
      questId: questId,
      taskId: taskId,
      userId: userId,
      timestamp: now,
    );

    final localPath = await _localStorage.saveFromLocalPath(
      questId: questId,
      taskId: taskId,
      sourceFilePath: sourceFile.path,
      timestamp: now,
    );

    return _uploadLocalFile(
      localPath: localPath,
      metadata: metadata,
    );
  }

  @override
  Future<TaskEvidenceSaveResult> retryUpload({
    required String questId,
    required String taskId,
    required String? userId,
    required String localEvidencePath,
  }) async {
    final metadata = TaskEvidenceMetadata(
      questId: questId,
      taskId: taskId,
      userId: userId,
      timestamp: _clock(),
    );

    return _uploadLocalFile(
      localPath: localEvidencePath,
      metadata: metadata,
    );
  }

  @override
  Future<void> deleteEvidence({
    String? localPath,
    String? remotePath,
  }) async {
    await _localStorage.deleteEvidence(
      localPath: localPath,
      remotePath: remotePath,
    );

    if (!_isCloudConfigured) return;
    if (remotePath == null || remotePath.trim().isEmpty) return;

    try {
      await _supabaseClient!.storage.from(_storageBucket).remove([remotePath]);
    } on StorageException {
      // Игнорируем: отсутствие файла в облаке не должно ломать поток замены.
    } on Exception {
      // Fallback-поведение: локальное удаление уже выполнено.
    }
  }

  @override
  String? resolvePreviewPath(String evidencePath) {
    return _localStorage.resolvePreviewPath(evidencePath);
  }

  Future<TaskEvidenceSaveResult> _uploadLocalFile({
    required String localPath,
    required TaskEvidenceMetadata metadata,
  }) async {
    final normalizedUserId = metadata.userId?.trim();
    if (normalizedUserId == null || normalizedUserId.isEmpty) {
      return TaskEvidenceSaveResult(
        localPath: localPath,
        status: EvidenceStatus.pending,
        errorCode: TaskEvidenceErrorCode.unauthenticated,
        metadata: metadata,
      );
    }

    final localFile = File(localPath);
    if (!await localFile.exists()) {
      return TaskEvidenceSaveResult(
        localPath: localPath,
        status: EvidenceStatus.failed,
        errorCode: TaskEvidenceErrorCode.localFileMissing,
        metadata: metadata,
      );
    }

    if (!_isCloudConfigured) {
      return TaskEvidenceSaveResult(
        localPath: localPath,
        status: EvidenceStatus.pending,
        errorCode: TaskEvidenceErrorCode.cloudUnavailable,
        metadata: metadata,
      );
    }

    final extension = p.extension(localPath);
    final safeExtension =
        extension.isNotEmpty ? extension.toLowerCase() : '.jpg';
    final filename =
        '${metadata.timestamp.millisecondsSinceEpoch}$safeExtension';
    final remotePath = p.posix.join(
      'quest_evidence',
      normalizedUserId,
      metadata.questId,
      metadata.taskId,
      filename,
    );

    try {
      final storage = _supabaseClient!.storage.from(_storageBucket);
      final uploadedPath = await storage.uploadBinary(
        remotePath,
        await localFile.readAsBytes(),
        fileOptions: FileOptions(
          contentType: _contentTypeByExtension(safeExtension),
          metadata: metadata.toStorageMetadata(),
        ),
      );

      if (uploadedPath.trim().isEmpty) {
        return TaskEvidenceSaveResult(
          localPath: localPath,
          status: EvidenceStatus.failed,
          errorCode: TaskEvidenceErrorCode.uploadFailed,
          metadata: metadata,
        );
      }

      final downloadUrl = storage.getPublicUrl(remotePath);
      return TaskEvidenceSaveResult(
        localPath: localPath,
        status: EvidenceStatus.uploaded,
        remotePath: remotePath,
        remoteDownloadUrl: downloadUrl,
        metadata: metadata,
      );
    } on StorageException catch (e) {
      return TaskEvidenceSaveResult(
        localPath: localPath,
        status: EvidenceStatus.failed,
        errorCode: _mapStorageExceptionToErrorCode(e),
        metadata: metadata,
      );
    } on Exception {
      return TaskEvidenceSaveResult(
        localPath: localPath,
        status: EvidenceStatus.failed,
        errorCode: TaskEvidenceErrorCode.uploadFailed,
        metadata: metadata,
      );
    }
  }

  String _mapStorageExceptionToErrorCode(StorageException exception) {
    final statusCode = exception.statusCode?.trim();
    if (statusCode == '401' || statusCode == '403') {
      return TaskEvidenceErrorCode.unauthenticated;
    }

    if (statusCode == '404' ||
        statusCode == '408' ||
        statusCode == '500' ||
        statusCode == '502' ||
        statusCode == '503' ||
        statusCode == '504') {
      return TaskEvidenceErrorCode.cloudUnavailable;
    }

    return TaskEvidenceErrorCode.uploadFailed;
  }

  String _contentTypeByExtension(String extension) {
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }
}
