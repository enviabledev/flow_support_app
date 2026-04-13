import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../config/theme.dart';

class InputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onEmojiToggle;
  final VoidCallback onAttachment;
  final VoidCallback onCamera;
  final void Function(String path) onVoiceNoteSent;
  final ValueChanged<String>? onTextChanged;
  final bool showEmojiPicker;

  const InputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onEmojiToggle,
    required this.onAttachment,
    required this.onCamera,
    required this.onVoiceNoteSent,
    this.onTextChanged,
    this.showEmojiPicker = false,
  });

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar> {
  RecorderController? _recorderController;
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _recorderController?.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) return;

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    _recorderController = RecorderController()
      ..androidEncoder = AndroidEncoder.aac
      ..androidOutputFormat = AndroidOutputFormat.mpeg4
      ..sampleRate = 44100;

    await _recorderController!.record(path: path);
    setState(() {
      _isRecording = true;
      _recordDuration = Duration.zero;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordDuration += const Duration(seconds: 1));
    });
  }

  Future<void> _stopRecording({bool send = true}) async {
    _timer?.cancel();
    final path = await _recorderController?.stop();
    setState(() => _isRecording = false);
    if (send && path != null) widget.onVoiceNoteSent(path);
    _recorderController?.dispose();
    _recorderController = null;
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: ThemeProvider.instance.colors.background,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: _isRecording ? _buildRecordingBar() : _buildNormalBar(),
      ),
    );
  }

  Widget _buildRecordingBar() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
          onPressed: () => _stopRecording(send: false),
        ),
        const SizedBox(width: 8),
        Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(_formatDuration(_recordDuration), style: TextStyle(color: ThemeProvider.instance.colors.textPrimary, fontSize: 16)),
        const Spacer(),
        GestureDetector(
          onTap: () => _stopRecording(send: true),
          child: Container(
            width: 44, height: 44,
            decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
            child: const Icon(Icons.send, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildNormalBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Attachment button (+)
        IconButton(
          icon: Icon(Icons.add, color: ThemeProvider.instance.colors.textSecondary, size: 26),
          onPressed: widget.onAttachment,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        // Text field with emoji button inside
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: ThemeProvider.instance.colors.inputBackground,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(
                    widget.showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
                    color: ThemeProvider.instance.colors.textSecondary, size: 24,
                  ),
                  onPressed: widget.onEmojiToggle,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    onChanged: widget.onTextChanged,
                    maxLines: 5,
                    minLines: 1,
                    style: TextStyle(color: ThemeProvider.instance.colors.textPrimary, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Type a message',
                      hintStyle: TextStyle(color: ThemeProvider.instance.colors.textSecondary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Camera button
        IconButton(
          icon: Icon(Icons.camera_alt, color: ThemeProvider.instance.colors.textSecondary, size: 24),
          onPressed: widget.onCamera,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        // Send or mic button
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.controller,
          builder: (context, value, child) {
            final hasText = value.text.trim().isNotEmpty;
            if (hasText) {
              return GestureDetector(
                onTap: widget.onSend,
                child: Container(
                  width: 44, height: 44,
                  decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                  child: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              );
            }
            return GestureDetector(
              onTap: _startRecording,
              child: Container(
                width: 44, height: 44,
                decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                child: const Icon(Icons.mic, color: Colors.white, size: 22),
              ),
            );
          },
        ),
      ],
    );
  }
}
