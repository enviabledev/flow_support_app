import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../config/theme.dart';

class VoiceNoteBubble extends StatefulWidget {
  final String audioUrl;
  final bool isOutgoing;

  const VoiceNoteBubble({
    super.key,
    required this.audioUrl,
    required this.isOutgoing,
  });

  @override
  State<VoiceNoteBubble> createState() => _VoiceNoteBubbleState();
}

class _VoiceNoteBubbleState extends State<VoiceNoteBubble> {
  late final AudioPlayer _player;
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playerState = s);
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playerState = PlayerState.stopped;
          _position = Duration.zero;
          _hasLoaded = false;
        });
      }
    });

    // Pre-load to get duration
    _player.setSource(UrlSource(widget.audioUrl));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_playerState == PlayerState.playing) {
      await _player.pause();
    } else if (_playerState == PlayerState.paused && _hasLoaded) {
      await _player.resume();
    } else {
      _hasLoaded = true;
      await _player.play(UrlSource(widget.audioUrl));
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _playerState == PlayerState.playing;
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 20,
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    activeTrackColor: AppColors.accent,
                    inactiveTrackColor: ThemeProvider.instance.colors.textSecondary.withValues(alpha: 0.3),
                    thumbColor: AppColors.accent,
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: (v) {
                      final pos = Duration(milliseconds: (v * _duration.inMilliseconds).round());
                      _player.seek(pos);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isPlaying || _playerState == PlayerState.paused
                    ? _formatDuration(_position)
                    : _formatDuration(_duration),
                style: TextStyle(
                  color: widget.isOutgoing
                      ? ThemeProvider.instance.colors.textPrimary.withValues(alpha: 0.7)
                      : ThemeProvider.instance.colors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
