import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/student_game_model.dart';
import '../models/user_model.dart';
import '../models/game_session_model.dart';
import '../services/student_game_service.dart';
import 'student_game_completion_wrapper.dart';

class StudentGameLobbyPage extends StatefulWidget {
  final StudentGameModel game;
  final String playerId;

  const StudentGameLobbyPage({
    super.key,
    required this.game,
    required this.playerId,
  });

  @override
  State<StudentGameLobbyPage> createState() => _StudentGameLobbyPageState();
}

class _StudentGameLobbyPageState extends State<StudentGameLobbyPage> {
  late Stream<StudentGameModel?> _gameStream;

  @override
  void initState() {
    super.initState();
    _gameStream = StudentGameService.getGameStream(widget.game.gameId);
  }

  Color _getPlayerColor(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'red': return Colors.red;
      case 'blue': return Colors.blue;
      case 'green': return Colors.green;
      case 'yellow': return Colors.orange;
      case 'purple': return Colors.purple;
      case 'orange': return Colors.deepOrange;
      default: return Colors.blue;
    }
  }

  IconData _getPlayerIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'cat': return Icons.pets;
      case 'dog': return Icons.pets;
      case 'star': return Icons.star;
      case 'heart': return Icons.favorite;
      case 'butterfly': return Icons.flutter_dash;
      case 'sun': return Icons.wb_sunny;
      default: return Icons.person;
    }
  }

  // Convert student game to regular game session format
  GameSessionModel _convertToGameSession(StudentGameModel studentGame) {
    return GameSessionModel(
      gameId: studentGame.gameId,
      createdBy: studentGame.teacherId,
      gameName: 'Student Game: ${studentGame.gameCode}',
      playerIds: studentGame.players.map((p) => p.playerId).toList(),
<<<<<<< HEAD
      players: studentGame.players.asMap().entries.map((entry) => PlayerInGame(
        userId: entry.value.playerId,
        displayName: entry.value.playerName,
        emailAddress: '${entry.value.playerId}@studentgame.local', // Fake email for student games
        joinedAt: entry.value.joinedAt,
=======
      players: studentGame.players.map((p) => PlayerInGame(
        userId: p.playerId,
        displayName: p.playerName,
        emailAddress: '${p.playerId}@studentgame.local', // Fake email for student games
        joinedAt: p.joinedAt,
>>>>>>> 8fa281c869b61ec6fc67458e87ba6748b80c6078
        isReady: true, // Student players are ready once they join
      )).toList(),
      status: studentGame.isActive 
          ? GameStatus.inProgress 
          : (studentGame.isWaiting ? GameStatus.waitingForPlayers : GameStatus.completed),
      createdAt: studentGame.createdAt,
      startedAt: studentGame.startedAt,
      maxPlayers: studentGame.maxPlayers,
    );
  }

  // Convert student player to regular user format
  UserModel _convertToUser(StudentPlayer studentPlayer) {
    return UserModel(
      id: studentPlayer.playerId,
      displayName: studentPlayer.playerName,
      emailAddress: '${studentPlayer.playerId}@studentgame.local', // Fake email for student games
      pin: '0000', // Default PIN for student games
      isAdmin: false,
      createdAt: studentPlayer.joinedAt,
    );
  }

  void _navigateToGame(StudentGameModel game) {
    // Find the current player
    final currentPlayer = game.players.firstWhere(
      (p) => p.playerId == widget.playerId,
      orElse: () => throw Exception('Current player not found in game'),
    );

    // Convert to regular game format
    final gameSession = _convertToGameSession(game);
    final user = _convertToUser(currentPlayer);

    // Navigate to the actual game with completion tracking wrapper
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => StudentGameCompletionWrapper(
          studentGame: game,
          user: user,
          gameSession: gameSession,
          gameName: 'Student Game: ${game.gameCode}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.gameBackground,
      appBar: AppBar(
        title: Text('Game: ${widget.game.gameCode}'),
        backgroundColor: AppColors.gamePrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // Students shouldn't accidentally go back
      ),
      body: StreamBuilder<StudentGameModel?>(
        stream: _gameStream,
        initialData: widget.game,
        builder: (context, snapshot) {
          final game = snapshot.data ?? widget.game;
          
          // If game started, navigate to game screen
          if (game.isActive) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                _navigateToGame(game);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error starting game: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            });
          }

          return Container(
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
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 32 : 24),
                child: Column(
                  children: [
                    // Game status header
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isTablet ? 24 : 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gamePrimary.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Fun emoji row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('🎮', style: TextStyle(fontSize: isTablet ? 36 : 28)),
                              const SizedBox(width: 8),
                              Text('✨', style: TextStyle(fontSize: isTablet ? 36 : 28)),
                              const SizedBox(width: 8),
                              Text('🎯', style: TextStyle(fontSize: isTablet ? 36 : 28)),
                            ],
                          ),
                          
                          SizedBox(height: isTablet ? 16 : 12),
                          
                          Text(
                            game.isWaiting ? 'Waiting for Players' : 'Game Starting!',
                            style: TextStyle(
                              fontSize: isTablet ? 24 : 20,
                              fontWeight: FontWeight.bold,
                              color: game.isWaiting ? AppColors.warning : AppColors.success,
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          Text(
                            'Game Code: ${game.gameCode}',
                            style: TextStyle(
                              fontSize: isTablet ? 32 : 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                              color: AppColors.gamePrimary,
                            ),
                          ),
                          
                          if (game.isWaiting) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Tell your friends to join!',
                              style: TextStyle(
                                fontSize: isTablet ? 16 : 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    SizedBox(height: isTablet ? 30 : 24),
                    
                    // Players section
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isTablet ? 24 : 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gamePrimary.withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.group,
                                  color: AppColors.gamePrimary,
                                  size: isTablet ? 28 : 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Players (${game.players.length}/${game.maxPlayers})',
                                  style: TextStyle(
                                    fontSize: isTablet ? 22 : 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.gamePrimary,
                                  ),
                                ),
                              ],
                            ),
                            
                            SizedBox(height: isTablet ? 20 : 16),
                            
                            // Players grid
                            Expanded(
                              child: GridView.builder(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: isTablet ? 3 : 2,
                                  crossAxisSpacing: isTablet ? 16 : 12,
                                  mainAxisSpacing: isTablet ? 16 : 12,
                                  childAspectRatio: 1,
                                ),
                                itemCount: game.maxPlayers,
                                itemBuilder: (context, index) {
                                  final slot = index + 1;
                                  final player = game.findPlayerBySlot(slot);
                                  final isCurrentPlayer = player?.playerId == widget.playerId;
                                  
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: player != null 
                                          ? _getPlayerColor(player.avatarColor).withOpacity(0.1)
                                          : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                        color: isCurrentPlayer
                                            ? AppColors.success
                                            : player != null
                                                ? _getPlayerColor(player.avatarColor)
                                                : Colors.grey,
                                        width: isCurrentPlayer ? 3 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (player != null) ...[
                                          // Player avatar
                                          CircleAvatar(
                                            radius: isTablet ? 28 : 24,
                                            backgroundColor: _getPlayerColor(player.avatarColor),
                                            child: Icon(
                                              _getPlayerIcon(player.avatarIcon),
                                              color: Colors.white,
                                              size: isTablet ? 28 : 24,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            player.playerName,
                                            style: TextStyle(
                                              fontSize: isTablet ? 16 : 14,
                                              fontWeight: isCurrentPlayer ? FontWeight.bold : FontWeight.w500,
                                              color: isCurrentPlayer ? AppColors.success : AppColors.textPrimary,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          if (isCurrentPlayer) ...[
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.success,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                'YOU',
                                                style: TextStyle(
                                                  fontSize: isTablet ? 12 : 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ] else ...[
                                          // Empty slot
                                          Icon(
                                            Icons.person_add,
                                            size: isTablet ? 40 : 32,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Waiting...',
                                            style: TextStyle(
                                              fontSize: isTablet ? 14 : 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: isTablet ? 24 : 20),
                    
                    // Status message
                    if (game.isWaiting)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isTablet ? 20 : 16),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.timer,
                              color: AppColors.warning,
                              size: isTablet ? 28 : 24,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your teacher will start the game when ready!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isTablet ? 16 : 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}