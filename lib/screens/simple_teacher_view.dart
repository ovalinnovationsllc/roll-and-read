import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/game_session_model.dart';
import '../models/user_model.dart';
import '../models/game_state_model.dart';
import '../services/game_state_service.dart';
import '../services/game_session_service.dart';

class SimpleTeacherView extends StatefulWidget {
  final UserModel user;
  final GameSessionModel gameSession;

  const SimpleTeacherView({
    super.key,
    required this.user,
    required this.gameSession,
  });

  @override
  State<SimpleTeacherView> createState() => _SimpleTeacherViewState();
}

class _SimpleTeacherViewState extends State<SimpleTeacherView> {
  GameStateModel? _currentGameState;
  GameSessionModel? _currentGameSession;
  
  @override
  void initState() {
    super.initState();
    _currentGameSession = widget.gameSession;
    _listenToGameChanges();
  }

  void _listenToGameChanges() {
    // Listen to game state changes
    GameStateService.getGameStateStream(widget.gameSession.gameId).listen((gameState) {
      if (mounted && gameState != null) {
        setState(() {
          _currentGameState = gameState;
        });
      }
    });

    // Listen to game session changes
    GameSessionService.listenToGameSession(widget.gameSession.gameId).listen((gameSession) {
      if (mounted && gameSession != null) {
        setState(() {
          _currentGameSession = gameSession;
        });
      }
    });
  }

  Future<void> _endGame() async {
    try {
      await GameSessionService.endGameSession(gameId: widget.gameSession.gameId);
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/admin-dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error ending game: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameSession = _currentGameSession ?? widget.gameSession;
    final gameState = _currentGameState;
    
    return Scaffold(
      backgroundColor: AppColors.gameBackground,
      appBar: AppBar(
        title: Text('Teacher View - ${gameSession.gameName}'),
        backgroundColor: AppColors.gamePrimary,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Code: ${gameSession.gameId}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Players
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Players', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    ...gameSession.players.map((player) {
                      final score = gameState?.getPlayerScore(player.userId) ?? 0;
                      final isCurrentTurn = gameState?.currentTurnPlayerId == player.userId;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: player.playerColor != null 
                            ? Color(player.playerColor!) 
                            : AppColors.gamePrimary,
                          child: Text(
                            player.displayName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          player.displayName,
                          style: TextStyle(
                            fontWeight: isCurrentTurn ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(isCurrentTurn ? 'Current Turn' : 'Waiting'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.amber),
                            Text('$score', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Game State
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Game Status', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: const Icon(Icons.casino),
                      title: const Text('Current Dice'),
                      trailing: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${gameState?.currentDiceValue ?? 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.gamepad),
                      title: const Text('Game Status'),
                      trailing: Text(gameSession.status.toString().split('.').last),
                    ),
                  ],
                ),
              ),
            ),
            
            const Spacer(),
            
            // End Game Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _endGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text(
                  'End Game',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}