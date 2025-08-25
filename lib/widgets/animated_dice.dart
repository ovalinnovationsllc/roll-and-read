import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/sound_service.dart';

class AnimatedDice extends StatefulWidget {
  final int value;
  final bool isRolling;
  final double size;
  final VoidCallback? onTap;

  const AnimatedDice({
    super.key,
    required this.value,
    required this.isRolling,
    this.size = 100,
    this.onTap,
  });

  @override
  State<AnimatedDice> createState() => _AnimatedDiceState();
}

class _AnimatedDiceState extends State<AnimatedDice>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _bounceController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _bounceAnimation;
  int _displayValue = 1;

  @override
  void initState() {
    super.initState();
    _displayValue = widget.value;
    
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));
    
    _bounceAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void didUpdateWidget(AnimatedDice oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isRolling && !oldWidget.isRolling) {
      _startRolling();
    } else if (!widget.isRolling && oldWidget.isRolling) {
      _stopRolling();
    }
  }

  void _startRolling() {
    _rotationController.repeat();
    // Play dice rolling sound
    SoundService.playDiceRoll();
    setState(() {
      _displayValue = 0;
    });
  }

  void _stopRolling() {
    _rotationController.stop();
    _bounceController.forward(from: 0);
    setState(() {
      _displayValue = widget.value;
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_rotationAnimation, _bounceAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isRolling ? 1.0 : _bounceAnimation.value,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..rotateY(widget.isRolling ? _rotationAnimation.value : 0)
                ..rotateZ(widget.isRolling ? _rotationAnimation.value * 0.5 : 0),
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(widget.size * 0.15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: widget.isRolling
                      ? Icon(
                          Icons.casino,
                          size: widget.size * 0.4,
                          color: Colors.grey.shade400,
                        )
                      : _buildDiceFace(_displayValue),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDiceFace(int value) {
    final dotSize = widget.size * 0.15;
    final dotColor = Colors.black87;
    
    return Container(
      padding: EdgeInsets.all(widget.size * 0.15),
      child: _getDicePattern(value, dotSize, dotColor),
    );
  }

  Widget _getDicePattern(int value, double dotSize, Color dotColor) {
    Widget dot() => Container(
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(
        color: dotColor,
        shape: BoxShape.circle,
      ),
    );

    Widget empty() => SizedBox(width: dotSize, height: dotSize);

    switch (value) {
      case 1:
        return Center(child: dot());
      case 2:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [dot()],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [dot()],
            ),
          ],
        );
      case 3:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [dot()],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [dot()],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [dot()],
            ),
          ],
        );
      case 4:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [dot(), dot()],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [dot(), dot()],
            ),
          ],
        );
      case 5:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [dot(), dot()],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [dot()],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [dot(), dot()],
            ),
          ],
        );
      case 6:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [dot(), dot()],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [dot(), dot()],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [dot(), dot()],
            ),
          ],
        );
      default:
        return const SizedBox();
    }
  }
}