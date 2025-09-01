import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import '../config/app_colors.dart';

class WinningCelebration extends StatefulWidget {
  final String winnerName;
  final VoidCallback? onComplete;
  final bool isCurrentPlayer;

  const WinningCelebration({
    super.key,
    required this.winnerName,
    this.onComplete,
    this.isCurrentPlayer = false,
  });

  @override
  State<WinningCelebration> createState() => _WinningCelebrationState();
}

class _WinningCelebrationState extends State<WinningCelebration>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late AnimationController _bounceController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _bounceAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.bounceOut,
    ));

    _startCelebration();
  }

  void _startCelebration() async {
    // Start confetti immediately
    _confettiController.play();
    
    // Stagger the animations
    await Future.delayed(const Duration(milliseconds: 100));
    _fadeController.forward();
    
    await Future.delayed(const Duration(milliseconds: 200));
    _scaleController.forward();
    
    await Future.delayed(const Duration(milliseconds: 400));
    _bounceController.forward();
    
    // Auto-complete after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && widget.onComplete != null) {
        widget.onComplete!();
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scaleController.dispose();
    _fadeController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Background overlay
          Container(
            color: Colors.black.withOpacity(0.7),
            width: double.infinity,
            height: double.infinity,
          ),
          
          // Multiple confetti controllers for better coverage
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2, // Down
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 30,
              gravity: 0.1,
              shouldLoop: false,
              colors: const [
                AppColors.success,
                AppColors.warning,
                AppColors.gamePrimary,
                Colors.red,
                Colors.blue,
                Colors.purple,
                Colors.orange,
              ],
              createParticlePath: (size) {
                final path = Path();
                path.addOval(Rect.fromCircle(center: Offset.zero, radius: size.width / 2));
                return path;
              },
            ),
          ),
          
          // Left side confetti
          Align(
            alignment: Alignment.centerLeft,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 0, // Right
              blastDirectionality: BlastDirectionality.directional,
              particleDrag: 0.05,
              emissionFrequency: 0.03,
              numberOfParticles: 15,
              gravity: 0.05,
              shouldLoop: false,
              colors: const [
                AppColors.success,
                AppColors.warning,
                AppColors.gamePrimary,
                Colors.red,
                Colors.blue,
                Colors.purple,
              ],
            ),
          ),
          
          // Right side confetti
          Align(
            alignment: Alignment.centerRight,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi, // Left
              blastDirectionality: BlastDirectionality.directional,
              particleDrag: 0.05,
              emissionFrequency: 0.03,
              numberOfParticles: 15,
              gravity: 0.05,
              shouldLoop: false,
              colors: const [
                AppColors.success,
                AppColors.warning,
                AppColors.gamePrimary,
                Colors.red,
                Colors.blue,
                Colors.purple,
              ],
            ),
          ),
          
          // Main celebration content
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _scaleAnimation,
                _fadeAnimation,
                _bounceAnimation,
              ]),
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Transform.translate(
                      offset: Offset(0, -20 * (1 - _bounceAnimation.value)),
                      child: Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: isTablet ? 40 : 20,
                        ),
                        padding: EdgeInsets.all(isTablet ? 40 : 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Trophy/Crown Icon
                            Container(
                              padding: EdgeInsets.all(isTablet ? 20 : 16),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.emoji_events,
                                size: isTablet ? 80 : 60,
                                color: AppColors.success,
                              ),
                            ),
                            
                            SizedBox(height: isTablet ? 24 : 16),
                            
                            // Winner announcement
                            Text(
                              widget.isCurrentPlayer ? 'YOU WON!' : 'WINNER!',
                              style: TextStyle(
                                fontSize: isTablet ? 36 : 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                                letterSpacing: 2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            
                            SizedBox(height: isTablet ? 16 : 12),
                            
                            // Winner name
                            Text(
                              widget.winnerName,
                              style: TextStyle(
                                fontSize: isTablet ? 24 : 20,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            
                            SizedBox(height: isTablet ? 8 : 6),
                            
                            // Celebration message
                            Text(
                              widget.isCurrentPlayer 
                                  ? 'Congratulations on your victory!'
                                  : 'Congratulations!',
                              style: TextStyle(
                                fontSize: isTablet ? 16 : 14,
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            
                            SizedBox(height: isTablet ? 32 : 24),
                            
                            // Celebration emojis
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildAnimatedEmoji('🎉', 0),
                                _buildAnimatedEmoji('🏆', 1),
                                _buildAnimatedEmoji('⭐', 2),
                                _buildAnimatedEmoji('🎊', 3),
                                _buildAnimatedEmoji('🥇', 4),
                              ],
                            ),
                            
                            SizedBox(height: isTablet ? 24 : 16),
                            
                            // Close button
                            ElevatedButton(
                              onPressed: widget.onComplete,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: isTablet ? 32 : 24,
                                  vertical: isTablet ? 16 : 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Continue',
                                style: TextStyle(
                                  fontSize: isTablet ? 18 : 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedEmoji(String emoji, int index) {
    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        final delay = index * 0.1;
        final animationValue = (_bounceAnimation.value - delay).clamp(0.0, 1.0);
        
        return Transform.scale(
          scale: 0.8 + (0.4 * animationValue),
          child: Transform.rotate(
            angle: sin(animationValue * pi * 2) * 0.1,
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        );
      },
    );
  }
}