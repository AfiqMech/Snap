import 'package:flutter/material.dart';

class BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double scaleFactor;
  final Duration duration;
  final HitTestBehavior behavior;

  const BouncingButton({
    super.key,
    required this.child,
    this.onPressed,
    this.scaleFactor = 0.95,
    this.duration = const Duration(milliseconds: 150),
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<BouncingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _canPress = true; // Spam guard — prevents rapid multi-fire

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleFactor)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed == null || !_canPress) return;
    _canPress = false;
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onPressed == null) return;
    _controller.reverse().then((_) {
      if (mounted) {
        _canPress = true;
        widget.onPressed!();
      }
    });
  }

  void _onTapCancel() {
    _controller.reverse().then((_) {
      if (mounted) _canPress = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}
