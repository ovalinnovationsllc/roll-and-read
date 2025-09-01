import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/user_model.dart';
import '../models/game_session_model.dart';
import '../services/game_session_service.dart';
import 'clean_multiplayer_screen.dart';

class MultiplayerGamePage extends StatefulWidget {
  final UserModel user;
  final GameSessionModel gameSession;

  const MultiplayerGamePage({
    super.key,
    required this.user,
    required this.gameSession,
  });

  @override
  State<MultiplayerGamePage> createState() => _MultiplayerGamePageState();
}

class _MultiplayerGamePageState extends State<MultiplayerGamePage> {
  late Stream<GameSessionModel?> _gameStream;

  @override
  void initState() {
    super.initState();
    _gameStream = GameSessionService.listenToGameSession(widget.gameSession.gameId);
  }

  Future<void> _leaveGame() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Game'),
        content: const Text('Are you sure you want to leave this game?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              
              try {
                // Leave the game session
                await GameSessionService.leaveGameSession(
                  gameId: widget.gameSession.gameId,
                  playerId: widget.user.id,
                );
                
                if (mounted) {
                  Navigator.pop(context); // Go back to main menu
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error leaving game: ${e.toString().replaceFirst('Exception: ', '')}'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  Navigator.pop(context); // Go back anyway
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GameSessionModel?>(
      stream: _gameStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          // Game was deleted - automatically go back to main menu
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Game session ended - all players have left'),
                  backgroundColor: AppColors.warning,
                ),
              );
            }
          });
          
          return Scaffold(
            appBar: AppBar(
              title: const Text('Game Ended'),
              backgroundColor: AppColors.gamePrimary,
              foregroundColor: AppColors.onPrimary,
            ),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info, size: 64, color: AppColors.mediumBlue),
                  SizedBox(height: 16),
                  Text(
                    'Game session ended.',
                    style: TextStyle(fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Returning to main menu...',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        final gameSession = snapshot.data!;

        if (gameSession.status == GameStatus.waitingForPlayers) {
          return _buildWaitingRoom(gameSession);
        } else if (gameSession.status == GameStatus.inProgress) {
          return _buildGameInProgress(gameSession);
        } else if (gameSession.status == GameStatus.completed) {
          return _buildGameCompleted(gameSession);
        } else {
          return _buildGameCancelled(gameSession);
        }
      },
    );
  }

  Widget _buildWaitingRoom(GameSessionModel gameSession) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    
    return Scaffold(
      backgroundColor: AppColors.gameBackground,
      appBar: AppBar(
        title: Text(gameSession.gameName),
        backgroundColor: AppColors.gamePrimary,
        foregroundColor: AppColors.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _leaveGame,
            tooltip: 'Leave Game',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.hourglass_empty,
                    size: isTablet ? 80 : 60,
                    color: AppColors.gamePrimary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Waiting for Players',
                    style: TextStyle(
                      fontSize: isTablet ? 28 : 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.gamePrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.gamePrimary.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.tag, color: AppColors.gamePrimary),
                            const SizedBox(width: 8),
                            Text(
                              'Game ID: ${gameSession.gameId}',
                              style: TextStyle(
                                fontSize: isTablet ? 20 : 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.gamePrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Share this ID with other players',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.gamePrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Players (${gameSession.players.length}/${gameSession.maxPlayers}):',
                    style: TextStyle(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...gameSession.players.map((player) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: player.userId == widget.user.id 
                            ? AppColors.gamePrimary.withOpacity(0.1)
                            : AppColors.lightGray.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: player.userId == widget.user.id 
                              ? AppColors.gamePrimary.withOpacity(0.3)
                              : AppColors.lightGray,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person,
                            color: player.userId == widget.user.id 
                                ? AppColors.gamePrimary
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            player.displayName,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: player.userId == widget.user.id 
                                  ? AppColors.gamePrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          if (player.userId == widget.user.id) ...[
                            const SizedBox(width: 8),
                            Text(
                              '(You)',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: AppColors.gamePrimary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )).toList(),
                  const SizedBox(height: 24),
                  if (gameSession.players.length >= 1) ...[
                    Text(
                      'Game will start automatically when ${gameSession.maxPlayers} players join...',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(),
                  ] else ...[
                    Text(
                      'Waiting for more players to join...',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameInProgress(GameSessionModel gameSession) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Flexible(
              child: Text(
                gameSession.gameName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                gameSession.gameId,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.gamePrimary,
        foregroundColor: AppColors.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _leaveGame,
            tooltip: 'Leave Game',
          ),
        ],
      ),
      body: Column(
        children: [
          // Player status bar
          // Game content
          Expanded(
            child: CleanMultiplayerScreen(
              user: widget.user,
              gameSession: gameSession,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCompleted(GameSessionModel gameSession) {
    final winner = gameSession.players
        .where((p) => p.userId == gameSession.winnerId)
        .firstOrNull;
    
    return Scaffold(
      backgroundColor: AppColors.gameBackground,
      appBar: AppBar(
        title: const Text('Game Completed'),
        backgroundColor: AppColors.gamePrimary,
        foregroundColor: AppColors.onPrimary,
      ),
      body: Center(
        child: Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.emoji_events,
                  size: 80,
                  color: AppColors.gamePrimary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Game Complete!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                if (winner != null) ...[
                  Text(
                    '🏆 Winner: ${winner.displayName}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gamePrimary,
                    ),
                  ),
                ] else ...[
                  const Text(
                    'Great game everyone!',
                    style: TextStyle(fontSize: 18),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to Main Menu'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameCancelled(GameSessionModel gameSession) {
    return Scaffold(
      backgroundColor: AppColors.gameBackground,
      appBar: AppBar(
        title: const Text('Game Cancelled'),
        backgroundColor: AppColors.gamePrimary,
        foregroundColor: AppColors.onPrimary,
      ),
      body: const Center(
        child: Card(
          elevation: 4,
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cancel, size: 80, color: AppColors.error),
                SizedBox(height: 24),
                Text(
                  'Game Cancelled',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'This game was cancelled by Mrs. Elson.',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}