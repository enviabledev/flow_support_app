import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';

class SwipeableMessage extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;

  const SwipeableMessage({super.key, required this.child, required this.onReply});

  @override
  State<SwipeableMessage> createState() => _SwipeableMessageState();
}

class _SwipeableMessageState extends State<SwipeableMessage>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _hapticFired = false;

  double get _threshold => MediaQuery.of(context).size.width * 0.25;
  double get _maxDrag => MediaQuery.of(context).size.width * 0.30;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _animation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.addListener(() {
      setState(() => _dragOffset = _animation.value);
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx).clamp(0.0, _maxDrag);
    });

    // Haptic when crossing threshold
    if (_dragOffset >= _threshold && !_hapticFired) {
      _hapticFired = true;
      HapticFeedback.mediumImpact();
    } else if (_dragOffset < _threshold) {
      _hapticFired = false;
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragOffset >= _threshold) {
      widget.onReply();
    }
    _animation = Tween<double>(begin: _dragOffset, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward(from: 0);
    _hapticFired = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragOffset / _threshold).clamp(0.0, 1.0);

    return Stack(
      children: [
        // Reply icon behind the message
        Positioned(
          left: 12,
          top: 0,
          bottom: 0,
          child: Center(
            child: Opacity(
              opacity: progress,
              child: Transform.scale(
                scale: 0.5 + (progress * 0.5),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.reply, color: AppColors.accent, size: 20),
                ),
              ),
            ),
          ),
        ),
        // Message bubble translated right
        GestureDetector(
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          child: Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
