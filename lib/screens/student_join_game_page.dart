import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/game_session_model.dart';
import '../services/game_session_service.dart';
import '../services/session_service.dart';
import 'clean_multiplayer_screen.dart';

class StudentJoinGamePage extends StatefulWidget {
  const StudentJoinGamePage({super.key});

  @override
  State<StudentJoinGamePage> createState() => _StudentJoinGamePageState();
}

class _StudentJoinGamePageState extends State<StudentJoinGamePage> {
  final TextEditingController _codeController = TextEditingController();
  bool _isJoining = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinGame() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a game code';
      });
      return;
    }

    setState(() {
      _isJoining = true;
      _errorMessage = null;
    });

    try {
      // Find the game using GameSessionService
      final game = await GameSessionService.getGameSession(code);
      if (game != null) {
        print('🎯 Game details: ${game.gameName}, Status: ${game.status}, Players: ${game.players.length}');
      }
      
      if (game == null) {
        setState(() {
          _errorMessage = 'Game not found. Make sure the teacher has created a game and check the code.';
          _isJoining = false;
        });
        return;
      }

      if (game.players.length >= game.maxPlayers) {
        setState(() {
          _errorMessage = 'This game is full. Try another code.';
          _isJoining = false;
        });
        return;
      }

      // Get the current user (student) from session
      final user = await SessionService.getUser();
      if (user == null) {
        setState(() {
          _errorMessage = 'User session not found. Please select your name again.';
          _isJoining = false;
        });
        return;
      }

      print('🎓 STUDENT JOIN: About to join game with user: ${user.displayName}');
      
      // Actually join the game (add user to the game's player list)
      final updatedGame = await GameSessionService.joinGameSession(
        gameId: code,
        user: user,
      );

      if (updatedGame == null) {
        setState(() {
          _errorMessage = 'Failed to join game. Please try again.';
          _isJoining = false;
        });
        return;
      }

      print('🎓 STUDENT JOIN: Successfully joined game. Players: ${updatedGame.players.length}/${updatedGame.maxPlayers}');

      // Save the updated game session with student added
      await SessionService.saveGameSession(updatedGame);

      // Navigate to the multiplayer game
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CleanMultiplayerScreen(
              user: user,
              gameSession: updatedGame,
              isTeacherMode: false, // Student mode
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error joining game: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Stack trace: ${StackTrace.current}');
      
      // Show the actual error to help debug
      setState(() {
        if (e.toString().contains('Exception:')) {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        } else {
          _errorMessage = 'Error: ${e.toString()}';
        }
        _isJoining = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.gameBackground,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Join Game'),
        backgroundColor: AppColors.gamePrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.gamePrimary.withOpacity(0.1),
              AppColors.gameBackground,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.all(keyboardVisible ? (isTablet ? 20 : 12) : (isTablet ? 40 : 24)),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - (keyboardVisible ? (isTablet ? 40 : 24) : (isTablet ? 80 : 48)),
                  ),
                  child: Column(
                    mainAxisAlignment: keyboardVisible ? MainAxisAlignment.start : MainAxisAlignment.center,
                    children: [
                  // Fun header with icons
                  Container(
                    padding: EdgeInsets.all(keyboardVisible ? (isTablet ? 25 : 20) : (isTablet ? 40 : 30)),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gamePrimary.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Fun emoji/icon row - smaller when keyboard visible
                        if (!keyboardVisible) Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('🎮', style: TextStyle(fontSize: isTablet ? 40 : 30)),
                            const SizedBox(width: 10),
                            Text('🎯', style: TextStyle(fontSize: isTablet ? 40 : 30)),
                            const SizedBox(width: 10),
                            Text('🌟', style: TextStyle(fontSize: isTablet ? 40 : 30)),
                          ],
                        ),
                        
                        SizedBox(height: keyboardVisible ? (isTablet ? 8 : 6) : (isTablet ? 20 : 16)),
                        
                        Text(
                          'Enter Game Code',
                          style: TextStyle(
                            fontSize: isTablet ? 28 : 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gamePrimary,
                          ),
                        ),
                        
                        SizedBox(height: isTablet ? 12 : 8),
                        
                        Text(
                          'Ask your teacher for the code',
                          style: TextStyle(
                            fontSize: isTablet ? 18 : 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        
                        SizedBox(height: keyboardVisible ? (isTablet ? 20 : 16) : (isTablet ? 30 : 24)),
                        
                        // Game code input (big and friendly)
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _errorMessage != null 
                                  ? AppColors.error 
                                  : AppColors.gamePrimary,
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(15),
                            color: AppColors.gameBackground,
                          ),
                          child: TextField(
                            controller: _codeController,
                            textAlign: TextAlign.center,
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 6,
                            style: TextStyle(
                              fontSize: isTablet ? 36 : 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                              color: AppColors.gamePrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'ABC123',
                              hintStyle: TextStyle(
                                color: AppColors.textSecondary.withOpacity(0.5),
                                letterSpacing: 4,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: isTablet ? 20 : 16,
                                horizontal: 16,
                              ),
                              counterText: '',
                            ),
                            onChanged: (value) {
                              if (_errorMessage != null) {
                                setState(() {
                                  _errorMessage = null;
                                });
                              }
                            },
                            onSubmitted: (_) => _joinGame(),
                          ),
                        ),
                        
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.error),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: AppColors.error),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        SizedBox(height: keyboardVisible ? (isTablet ? 20 : 16) : (isTablet ? 30 : 24)),
                        
                        // Join button (big and friendly)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isJoining ? null : _joinGame,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                vertical: isTablet ? 20 : 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 5,
                            ),
                            child: _isJoining
                                ? SizedBox(
                                    height: isTablet ? 24 : 20,
                                    width: isTablet ? 24 : 20,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        'assets/images/dice_blue.png',
                                        width: isTablet ? 28 : 24,
                                        height: isTablet ? 28 : 24,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Icon(
                                            Icons.casino,
                                            size: isTablet ? 28 : 24,
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'JOIN GAME!',
                                        style: TextStyle(
                                          fontSize: isTablet ? 22 : 18,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  if (!keyboardVisible) SizedBox(height: isTablet ? 40 : 30),
                  if (keyboardVisible) SizedBox(height: isTablet ? 10 : 8),
                  
                  // Help section - smaller when keyboard visible
                  if (!keyboardVisible) Container(
                    padding: EdgeInsets.all(isTablet ? 20 : 16),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.help_outline,
                          color: AppColors.warning,
                          size: isTablet ? 32 : 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Need help?',
                          style: TextStyle(
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.warning,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ask your teacher for the game code',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isTablet ? 16 : 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Compact help when keyboard is visible
                  if (keyboardVisible) Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 16 : 12, 
                      vertical: isTablet ? 8 : 6,
                    ),
                    child: Text(
                      'Ask your teacher for the game code',
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}