import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:quest_guide/core/l10n/app_localizations.dart';
import 'package:quest_guide/core/theme/app_theme.dart';

/// Компактный аудиоплеер для аудиогида на точке маршрута
class AudioGuidePlayer extends StatefulWidget {
  final String audioUrl;
  const AudioGuidePlayer({super.key, required this.audioUrl});

  @override
  State<AudioGuidePlayer> createState() => _AudioGuidePlayerState();
}

class _AudioGuidePlayerState extends State<AudioGuidePlayer> {
  late final AudioPlayer _player;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      await _player.setUrl(widget.audioUrl);
      setState(() => _loading = false);
    } catch (_) {
      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_hasError) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.headphones_rounded,
              color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Text(l10n.audioGuide, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          if (_loading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            StreamBuilder<PlayerState>(
              stream: _player.playerStateStream,
              builder: (context, snapshot) {
                final playing = snapshot.data?.playing ?? false;
                return IconButton(
                  icon: Icon(
                    playing
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: AppColors.primary,
                    size: 32,
                  ),
                  onPressed: () {
                    if (playing) {
                      _player.pause();
                    } else {
                      _player.play();
                    }
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}
