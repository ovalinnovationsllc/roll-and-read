import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../services/firestore_service.dart';
import '../services/game_session_service.dart';
import '../services/session_service.dart';
import '../utils/firebase_utils.dart';
import '../models/user_model.dart';
import '../models/game_session_model.dart';
import '../models/player_colors.dart';
import 'multiplayer_game_page.dart';
import '../widgets/animated_dice.dart';

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
  Color? _selectedColor;
  GameSessionModel? _currentGame;
  List<GameSessionModel> _availableGames = [];
  bool _loadingGames = false;
  String? _selectedGameId;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _loadAvailableGames();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final savedUser = await SessionService.getUser();
      if (savedUser != null) {
        setState(() {
          _emailController.text = savedUser.emailAddress;
          _pinController.text = savedUser.pin ?? '';
        });
      }
    } catch (e) {
      // Ignore errors loading saved credentials
    }
  }

  Future<void> _loadAvailableGames([bool showFeedback = false]) async {
    setState(() {
      _loadingGames = true;
      _errorMessage = null; // Clear any previous errors
    });

    try {
      final games = await GameSessionService.getAvailableGames();
      setState(() {
        _availableGames = games;
        _loadingGames = false;
      });
      
      // Show feedback when manually refreshed
      if (mounted && showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(games.isEmpty 
                ? 'No games available right now'
                : 'Found ${games.length} available game${games.length == 1 ? '' : 's'}'),
            duration: const Duration(seconds: 2),
            backgroundColor: games.isEmpty ? AppColors.warning : AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _loadingGames = false;
        _errorMessage = 'Failed to load available games. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _pinController.dispose();
    _gameIdController.dispose();
    super.dispose();
  }


  void _onGameSelected(String? gameId) {
    if (gameId == null) {
      setState(() {
        _selectedGameId = null;
        _currentGame = null;
      });
      return;
    }

    final selectedGame = _availableGames.firstWhere(
      (game) => game.gameId == gameId,
      orElse: () => throw StateError('Game not found'),
    );

    setState(() {
      _selectedGameId = gameId;
      _currentGame = selectedGame;
      // Don't set a default color - let user choose
      _selectedColor = null;
    });
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
      final gameId = _selectedGameId;
      
      if (gameId == null || gameId.isEmpty) {
        setState(() {
          _errorMessage = 'Please select a game to join.';
          _isLoading = false;
        });
        return;
      }
      
      // Check if a color is selected
      if (_selectedColor == null) {
        setState(() {
          _errorMessage = 'Please select a color before joining the game.';
          _isLoading = false;
        });
        return;
      }
      
      // Wait for Firebase to be ready before attempting login
      await FirebaseUtils.waitForFirebaseReady();
      
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

      // Use the already loaded game session
      final gameSession = _currentGame;
      
      if (gameSession == null) {
        setState(() {
          _errorMessage = 'Selected game is no longer available.';
          _isLoading = false;
        });
        return;
      }

      // Verify that this student belongs to the teacher who created the game
      if (user.teacherId != gameSession.createdBy) {
        setState(() {
          _errorMessage = 'You can only join games created by your teacher.';
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
        if (e.toString().contains('Firebase initialization timeout')) {
          _errorMessage = 'Connection timeout. Please check your internet connection and try again.';
        } else {
          _errorMessage = 'An error occurred. Please try again.';
        }
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final colorSize = 60.0;
        final maxColorsPerRow = (availableWidth / (colorSize + 12)).floor();
        
        // For 8 colors, try to fit them in 2 rows of 4 if space allows, otherwise wrap
        if (availableColors.length == 8 && maxColorsPerRow >= 4) {
          // 2 rows of 4 colors each, centered
          final colors1 = availableColors.take(4).toList();
          final colors2 = availableColors.skip(4).take(4).toList();
          
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: colors1.map((playerColor) => _buildColorButton(playerColor)).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: colors2.map((playerColor) => _buildColorButton(playerColor)).toList(),
              ),
            ],
          );
        } else {
          // Fallback to centered wrap layout for other cases
          return Center(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: availableColors.map((playerColor) => _buildColorButton(playerColor)).toList(),
            ),
          );
        }
      },
    );
  }

  Widget _buildColorButton(dynamic playerColor) {
    final isSelected = _selectedColor?.value == playerColor.color.value;
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
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    
    return Scaffold(
      backgroundColor: AppColors.studentBackground,
      appBar: AppBar(
        title: const Text('Join Game'),
        backgroundColor: AppColors.gamePrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadingGames ? null : () => _loadAvailableGames(true),
            icon: _loadingGames 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.onPrimary),
                    ),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh Games',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadAvailableGames(true),
        child: Center(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                      Image.asset(
                        'assets/images/dice_blue.png',
                        width: isTablet ? 100 : 80,
                        height: isTablet ? 100 : 80,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: isTablet ? 100 : 80,
                            height: isTablet ? 100 : 80,
                            decoration: BoxDecoration(
                              color: AppColors.gamePrimary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.casino,
                              color: Colors.white,
                              size: isTablet ? 50 : 40,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Join a Game',
                        style: TextStyle(
                          fontSize: isTablet ? 28 : 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.gamePrimary,
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Game',
                            style: TextStyle(
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            constraints: const BoxConstraints(minHeight: 48),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: _loadingGames
                                ? const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                        SizedBox(width: 12),
                                        Text('Loading available games...'),
                                      ],
                                    ),
                                  )
                                : _availableGames.isEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Row(
                                          children: [
                                            Icon(Icons.info_outline, color: AppColors.warning),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text('No games available'),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Ask your teacher to create a new game',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedGameId,
                                          isExpanded: true,
                                          hint: const Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 16.0,
                                              vertical: 12.0,
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.games, color: Colors.grey, size: 20),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Choose a game to join',
                                                  style: TextStyle(fontSize: 14),
                                                ),
                                              ],
                                            ),
                                          ),
                                          onChanged: _isLoading ? null : _onGameSelected,
                                          items: _availableGames.map((game) {
                                            return DropdownMenuItem<String>(
                                              value: game.gameId,
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 16.0,
                                                  vertical: 8.0,
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.studentPrimary,
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        game.gameId,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        game.gameName,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 14,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    Text(
                                                      '${game.players.length}/${game.maxPlayers}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey.shade600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                          ),
                          if (_availableGames.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.refresh, size: 16, color: Colors.blue),
                                const SizedBox(width: 4),
                                TextButton(
                                  onPressed: _loadingGames ? null : _loadAvailableGames,
                                  child: const Text(
                                    'Refresh Games',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
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
                            backgroundColor: AppColors.gamePrimary,
                            foregroundColor: Colors.white,
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
        ), // SingleChildScrollView
      ), // Center
    ), // RefreshIndicator
    ); // Scaffold
  }
}