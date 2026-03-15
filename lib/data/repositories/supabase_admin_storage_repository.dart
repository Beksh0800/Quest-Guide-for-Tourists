import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:quest_guide/data/services/task_evidence_storage.dart';
import 'package:supabase/supabase.dart';

class SupabaseAdminStorageRepository {
  final SupabaseClient? _supabaseClient;
  final String _bucketName;
  final Random _random = Random();

  SupabaseAdminStorageRepository({
    SupabaseClient? supabaseClient,
    String? bucketName,
  })  : _bucketName = _resolveBucketName(bucketName),
        _supabaseClient = supabaseClient ?? _initClient();

  static String _resolveBucketName(String? providedBucketName) {
    final configured =
        SupabaseEvidenceStorageConfig.fromEnvironment().storageBucket.trim();
    if (providedBucketName != null && providedBucketName.trim().isNotEmpty) {
      return providedBucketName.trim();
    }
    if (configured.isNotEmpty) {
      return configured;
    }
    return 'quest_content';
  }

  static SupabaseClient? _initClient() {
    final config = SupabaseEvidenceStorageConfig.fromEnvironment();
    if (config.hasCredentials) {
      return SupabaseClient(
        config.supabaseUrl.trim(),
        config.supabaseAnonKey.trim(),
      );
    }
    return null;
  }

  /// Picks an image from the gallery and uploads it to the given [folder] inside the bucket.
  Future<String?> pickAndUploadImage({required String folder}) async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 2048,
      maxHeight: 2048,
    );

    if (xFile == null) return null;

    final file = File(xFile.path);
    if (!await file.exists()) return null;

    return await uploadImage(file, folder: folder);
  }

  /// Uploads a given [file] to the [folder] inside the bucket and returns the public URL.
  Future<String?> uploadImage(File file, {required String folder}) async {
    if (_supabaseClient == null) {
      throw Exception(
          'Supabase client is not configured via environment variables.');
    }

    final extension = p.extension(file.path).toLowerCase();
    final safeExtension = extension.isNotEmpty ? extension : '.jpg';
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomSuffix = _random.nextInt(1 << 20).toRadixString(16);
    final filename = '${timestamp}_$randomSuffix$safeExtension';

    final remotePath = p.posix.join(folder, filename);

    try {
      final storage = _supabaseClient.storage.from(_bucketName);

      await storage.uploadBinary(
        remotePath,
        await file.readAsBytes(),
        fileOptions: FileOptions(
          contentType: _getContentType(safeExtension),
          upsert: true,
        ),
      );

      return storage.getPublicUrl(remotePath);
    } on StorageException catch (e) {
      final errorText = (e.message).toLowerCase();
      final isUnauthorized = e.statusCode == '403' ||
          errorText.contains('unauthorized') ||
          errorText.contains('forbidden');
      final isRls = errorText.contains('row-level security');
      if (isUnauthorized || isRls) {
        throw Exception(
          'Нет прав на загрузку в Supabase Storage (403). Проверьте RLS policy для bucket "$_bucketName" и папки "$folder".',
        );
      }
      throw Exception('Ошибка загрузки в Storage: ${e.message}');
    } catch (e) {
      final errorText = e.toString().toLowerCase();
      final isUnauthorized =
          errorText.contains('403') || errorText.contains('unauthorized');
      final isRls = errorText.contains('row-level security');
      if (isUnauthorized || isRls) {
        throw Exception(
          'Нет прав на загрузку в Supabase Storage (403). Проверьте RLS policy для bucket "$_bucketName" и папки "$folder".',
        );
      }
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Picks an audio file and uploads it to the given [folder] inside the bucket.
  Future<String?> pickAndUploadAudio({required String folder}) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      withData: true,
      allowedExtensions: const ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac'],
    );

    if (picked == null || picked.files.isEmpty) return null;
    final selected = picked.files.first;

    final bytes = await _resolveBytes(selected);
    if (bytes == null || bytes.isEmpty) return null;

    final originalName =
        selected.name.trim().isNotEmpty ? selected.name.trim() : 'audio.mp3';

    return uploadAudioBytes(
      bytes,
      folder: folder,
      originalFilename: originalName,
    );
  }

  /// Uploads raw audio [bytes] to [folder] and returns a public URL.
  Future<String?> uploadAudioBytes(
    Uint8List bytes, {
    required String folder,
    required String originalFilename,
  }) async {
    if (_supabaseClient == null) {
      throw Exception(
          'Supabase client is not configured via environment variables.');
    }

    final extension = p.extension(originalFilename).toLowerCase();
    final safeExtension = _normalizeAudioExtension(extension);
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomSuffix = _random.nextInt(1 << 20).toRadixString(16);
    final filename = '${timestamp}_$randomSuffix$safeExtension';
    final remotePath = p.posix.join(folder, filename);

    try {
      final storage = _supabaseClient.storage.from(_bucketName);

      await storage.uploadBinary(
        remotePath,
        bytes,
        fileOptions: FileOptions(
          contentType: _getContentType(safeExtension),
          upsert: true,
        ),
      );

      return storage.getPublicUrl(remotePath);
    } on StorageException catch (e) {
      final errorText = (e.message).toLowerCase();
      final isUnauthorized = e.statusCode == '403' ||
          errorText.contains('unauthorized') ||
          errorText.contains('forbidden');
      final isRls = errorText.contains('row-level security');
      if (isUnauthorized || isRls) {
        throw Exception(
          'Нет прав на загрузку в Supabase Storage (403). Проверьте RLS policy для bucket "$_bucketName" и папки "$folder".',
        );
      }
      throw Exception('Ошибка загрузки в Storage: ${e.message}');
    } catch (e) {
      final errorText = e.toString().toLowerCase();
      final isUnauthorized =
          errorText.contains('403') || errorText.contains('unauthorized');
      final isRls = errorText.contains('row-level security');
      if (isUnauthorized || isRls) {
        throw Exception(
          'Нет прав на загрузку в Supabase Storage (403). Проверьте RLS policy для bucket "$_bucketName" и папки "$folder".',
        );
      }
      throw Exception('Failed to upload audio: $e');
    }
  }

  Future<Uint8List?> _resolveBytes(PlatformFile file) async {
    if (file.bytes != null) {
      return file.bytes!;
    }

    final path = file.path;
    if (path == null || path.isEmpty) {
      return null;
    }

    final localFile = File(path);
    if (!await localFile.exists()) {
      return null;
    }
    return localFile.readAsBytes();
  }

  String _normalizeAudioExtension(String extension) {
    switch (extension) {
      case '.mp3':
      case '.m4a':
      case '.aac':
      case '.wav':
      case '.ogg':
      case '.flac':
        return extension;
      default:
        return '.mp3';
    }
  }

  String _getContentType(String extension) {
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.mp3':
        return 'audio/mpeg';
      case '.m4a':
        return 'audio/mp4';
      case '.aac':
        return 'audio/aac';
      case '.wav':
        return 'audio/wav';
      case '.ogg':
        return 'audio/ogg';
      case '.flac':
        return 'audio/flac';
      default:
        return 'application/octet-stream';
    }
  }
}
