import 'package:flutter/material.dart';

class AnimatedBalanceText extends StatefulWidget {
  const AnimatedBalanceText({
    super.key,
    required this.formattedAmount,
    required this.style,
  });

  final String formattedAmount;
  final TextStyle? style;

  @override
  State<AnimatedBalanceText> createState() => _AnimatedBalanceTextState();
}

class _AnimatedBalanceTextState extends State<AnimatedBalanceText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedBalanceText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.formattedAmount != widget.formattedAmount) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: 0.4 + (_animation.value * 0.6),
          child: Transform.scale(
            scale: 0.92 + (_animation.value * 0.08),
            child: Text(widget.formattedAmount, style: widget.style),
          ),
        );
      },
    );
  }
}
