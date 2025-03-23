import 'package:flutter/material.dart';

class LevelAnimation extends StatefulWidget {
  final bool isLevelUp;

  const LevelAnimation({
    super.key,
    required this.isLevelUp,
  });

  @override
  State<LevelAnimation> createState() => _LevelAnimationState();
}

class _LevelAnimationState extends State<LevelAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.2),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        weight: 20,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        weight: 20,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          color: Color.fromARGB(
            (0.5 * _opacityAnimation.value * 255).round(),
            0,
            0,
            0,
          ),
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 24.0,
                  horizontal: 32.0,
                ),
                decoration: BoxDecoration(
                  color: widget.isLevelUp
                      ? Colors.amber.shade100
                      : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: [
                    BoxShadow(
                      color: widget.isLevelUp
                          ? Color.fromARGB(
                              (0.8 * 255).round(),
                              Colors.amber.r.toInt(),
                              Colors.amber.g.toInt(),
                              Colors.amber.b.toInt(),
                            )
                          : Color.fromARGB(
                              (0.8 * 255).round(),
                              Colors.blue.r.toInt(),
                              Colors.blue.g.toInt(),
                              Colors.blue.b.toInt(),
                            ),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.isLevelUp
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 48,
                      color: widget.isLevelUp
                          ? Colors.amber.shade800
                          : Colors.blue.shade800,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.isLevelUp ? '레벨 업!' : '레벨 다운',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: widget.isLevelUp
                            ? Colors.amber.shade800
                            : Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isLevelUp
                          ? '축하합니다! 레벨이 상승했습니다.'
                          : '아쉽습니다! 레벨이 하락했습니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: widget.isLevelUp
                            ? Colors.amber.shade800
                            : Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
} 