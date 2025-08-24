import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/game_session_model.dart';
import '../services/game_session_service.dart';
import 'multiplayer_roll_and_read.dart';

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
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to main menu
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
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
          return Scaffold(
            appBar: AppBar(
              title: const Text('Game Not Found'),
              backgroundColor: Colors.red.shade600,
            ),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'This game session no longer exists.',
                    style: TextStyle(fontSize: 18),
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
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: Text(gameSession.gameName),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
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
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Waiting for Players',
                    style: TextStyle(
                      fontSize: isTablet ? 28 : 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.tag, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Game ID: ${gameSession.gameId}',
                              style: TextStyle(
                                fontSize: isTablet ? 20 : 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Share this ID with other players',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue.shade600,
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
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...gameSession.players.map((player) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: player.userId == widget.user.id 
                            ? Colors.green.shade100 
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: player.userId == widget.user.id 
                              ? Colors.green.shade300 
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person,
                            color: player.userId == widget.user.id 
                                ? Colors.green.shade700 
                                : Colors.grey.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            player.displayName,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: player.userId == widget.user.id 
                                  ? Colors.green.shade700 
                                  : Colors.grey.shade700,
                            ),
                          ),
                          if (player.userId == widget.user.id) ...[
                            const SizedBox(width: 8),
                            Text(
                              '(You)',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.green.shade600,
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
                      'Waiting for teacher to start the game...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
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
                        color: Colors.grey.shade600,
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
            Text(gameSession.gameName),
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
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
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
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green.shade50,
            child: Row(
              children: gameSession.players.map((player) => Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: player.userId == widget.user.id 
                        ? Colors.green.shade200 
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        player.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Words: ${player.wordsRead}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              )).toList(),
            ),
          ),
          // Game content
          Expanded(
            child: MultiplayerRollAndRead(
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
      backgroundColor: Colors.purple.shade50,
      appBar: AppBar(
        title: const Text('Game Completed'),
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
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
                  color: Colors.purple.shade600,
                ),
                const SizedBox(height: 24),
                Text(
                  'Game Complete!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 16),
                if (winner != null) ...[
                  Text(
                    '🏆 Winner: ${winner.displayName}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
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
      backgroundColor: Colors.red.shade50,
      appBar: AppBar(
        title: const Text('Game Cancelled'),
        backgroundColor: Colors.red.shade600,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Card(
          elevation: 4,
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cancel, size: 80, color: Colors.red),
                SizedBox(height: 24),
                Text(
                  'Game Cancelled',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'This game was cancelled by the teacher.',
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