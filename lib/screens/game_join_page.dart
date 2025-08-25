import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../services/firestore_service.dart';
import '../services/game_session_service.dart';
import '../services/session_service.dart';
import '../models/user_model.dart';
import '../models/game_session_model.dart';
import '../models/player_colors.dart';
import 'multiplayer_game_page.dart';

class GameJoinPage extends StatefulWidget {
  const GameJoinPage({super.key});

  @override
  State<GameJoinPage> createState() => _GameJoinPageState();
}

class _GameJoinPageState extends State<GameJoinPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  final _gameIdController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  Color _selectedColor = PlayerColors.getDefaultColor();
  GameSessionModel? _currentGame;

  @override
  void dispose() {
    _emailController.dispose();
    _pinController.dispose();
    _gameIdController.dispose();
    super.dispose();
  }

  Future<void> _checkGameAndColors() async {
    final gameId = _gameIdController.text.trim().toUpperCase();
    if (gameId.isEmpty) return;

    try {
      final game = await GameSessionService.getGameSession(gameId);
      if (game != null) {
        setState(() {
          _currentGame = game;
          // Set first available color as default
          final availableColors = PlayerColors.getAvailableColorsForGame(
            game.players.map((p) => p.toMap()).toList(),
          );
          if (availableColors.isNotEmpty) {
            _selectedColor = availableColors.first.color;
          }
        });
      }
    } catch (e) {
      // Game doesn't exist or error occurred
      setState(() {
        _currentGame = null;
      });
    }
  }

  Future<void> _handleJoinGame() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final pin = _pinController.text.trim();
      final gameId = _gameIdController.text.trim().toUpperCase();
      
      // First, authenticate the user
      final user = await FirestoreService.getUserByEmail(email);
      
      if (user == null) {
        setState(() {
          _errorMessage = 'User not found. Please contact Mrs. Elson.';
          _isLoading = false;
        });
        return;
      }

      if (user.pin != pin) {
        setState(() {
          _errorMessage = 'Incorrect PIN. Please try again.';
          _isLoading = false;
        });
        return;
      }

      // Check if game exists
      final gameSession = await GameSessionService.getGameSession(gameId);
      
      if (gameSession == null) {
        setState(() {
          _errorMessage = 'Game not found. Please check the Game ID.';
          _isLoading = false;
        });
        return;
      }

      // Try to join the game with selected color
      try {
        // Update user with selected color
        final userWithColor = user.copyWith(playerColor: _selectedColor);
        
        final updatedGame = await GameSessionService.joinGameSession(
          gameId: gameId,
          user: userWithColor,
        );

        if (mounted && updatedGame != null) {
          // Save game session and current route for session persistence
          await SessionService.saveGameSession(updatedGame);
          await SessionService.saveUser(userWithColor);
          await SessionService.saveCurrentRoute('/multiplayer-game');
          
          // Navigate to multiplayer game using named route
          Navigator.pushReplacementNamed(
            context, 
            '/multiplayer-game',
            arguments: {
              'user': userWithColor,
              'gameSession': updatedGame,
            },
          );
        }
      } catch (gameError) {
        setState(() {
          _errorMessage = gameError.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }

    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  Widget _buildColorSelection() {
    final availableColors = _currentGame != null 
        ? PlayerColors.getAvailableColorsForGame(
            _currentGame!.players.map((p) => p.toMap()).toList(),
          )
        : PlayerColors.availableColors;

    if (availableColors.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.warning.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: AppColors.warning),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('All colors are taken in this game. Please try a different game.'),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: availableColors.map((playerColor) {
        final isSelected = _selectedColor.value == playerColor.color.value;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedColor = playerColor.color;
            });
          },
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: playerColor.color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? Colors.black : Colors.grey.shade300,
                width: isSelected ? 3 : 1,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: playerColor.color.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: isSelected
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 24,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    
    return Scaffold(
      backgroundColor: AppColors.studentBackground,
      appBar: AppBar(
        title: const Text('Join Game'),
        backgroundColor: AppColors.studentPrimary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isTablet ? 500 : double.infinity,
            ),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.games,
                        size: isTablet ? 80 : 60,
                        color: AppColors.studentPrimary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Join a Game',
                        style: TextStyle(
                          fontSize: isTablet ? 28 : 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your details and game code to join',
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _gameIdController,
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        enabled: !_isLoading,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Game ID',
                          hintText: 'ABC123',
                          prefixIcon: const Icon(Icons.tag),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: AppColors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter the Game ID';
                          }
                          if (value.length != 6) {
                            return 'Game ID must be exactly 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        enabled: !_isLoading,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          hintText: 'student@school.com',
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: AppColors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        autocorrect: false,
                        enabled: !_isLoading,
                        maxLength: 4,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleJoinGame(),
                        decoration: InputDecoration(
                          labelText: '4-Digit PIN',
                          hintText: 'Enter your PIN',
                          prefixIcon: const Icon(Icons.lock),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: AppColors.white,
                          counterText: '',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your PIN';
                          }
                          if (value.length != 4) {
                            return 'PIN must be exactly 4 digits';
                          }
                          if (!RegExp(r'^\d{4}$').hasMatch(value)) {
                            return 'PIN must contain only numbers';
                          }
                          return null;
                        },
                        onChanged: (_) => _checkGameAndColors(),
                      ),
                      const SizedBox(height: 24),
                      
                      // Color Selection Section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose Your Color',
                            style: TextStyle(
                              fontSize: isTablet ? 18 : 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select a color for your squares on the game board',
                            style: TextStyle(
                              fontSize: isTablet ? 14 : 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildColorSelection(),
                        ],
                      ),
                      
                      if (_errorMessage != null) ...[ 
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppColors.warning,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: AppColors.warning,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: isTablet ? 56 : 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleJoinGame,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.studentPrimary,
                            foregroundColor: AppColors.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Text(
                                  'Join Game',
                                  style: TextStyle(
                                    fontSize: isTablet ? 18 : 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.pop(context);
                              },
                        child: Text(
                          'Back to Home',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: isTablet ? 16 : 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}