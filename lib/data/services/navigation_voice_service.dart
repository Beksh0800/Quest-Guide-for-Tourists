import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class NavigationVoiceService {
  final FlutterTts _tts;
  final bool _ownsTts;

  bool _enabled = true;
  bool _isAvailable = false;
  bool _initialized = false;

  String? _lastPromptKey;
  DateTime? _lastPromptAt;

  NavigationVoiceService({FlutterTts? tts})
      : _tts = tts ?? FlutterTts(),
        _ownsTts = tts == null;

  bool get isEnabled => _enabled;
  bool get isAvailable => _isAvailable;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.setLanguage('ru-RU');
      _isAvailable = true;
    } catch (_) {
      _isAvailable = false;
    }
  }

  void setEnabled(bool value) {
    _enabled = value;
  }

  Future<void> speak({
    required String text,
    required String promptKey,
    Duration dedupeWindow = const Duration(seconds: 25),
  }) async {
    if (!_enabled) return;

    await initialize();
    if (!_isAvailable) return;

    final now = DateTime.now();
    final canSkipAsDuplicate = _lastPromptKey == promptKey &&
        _lastPromptAt != null &&
        now.difference(_lastPromptAt!) < dedupeWindow;

    if (canSkipAsDuplicate) {
      return;
    }

    _lastPromptKey = promptKey;
    _lastPromptAt = now;

    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      _isAvailable = false;
      if (kDebugMode) {
        debugPrint('[NavigationVoiceService] TTS failed: $e');
      }
    }
  }

  Future<void> stop() async {
    if (!_isAvailable) return;
    try {
      await _tts.stop();
    } catch (_) {
      // safe no-op fallback
    }
  }

  Future<void> dispose() async {
    await stop();
    if (_ownsTts) {
      try {
        await _tts.stop();
      } catch (_) {
        // safe no-op fallback
      }
    }
  }
}
