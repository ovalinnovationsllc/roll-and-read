import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_colors.dart';
import '../models/game_session_model.dart';
import '../models/user_model.dart';
import '../models/game_state_model.dart';
import '../services/game_state_service.dart';
import '../services/game_session_service.dart';

class TeacherMonitor extends StatefulWidget {
  final UserModel user;
  final GameSessionModel gameSession;

  const TeacherMonitor({
    super.key,
    required this.user,
    required this.gameSession,
  });

  @override
  State<TeacherMonitor> createState() => _TeacherMonitorState();
}

class _TeacherMonitorState extends State<TeacherMonitor> {
  GameStateModel? _currentGameState;
  GameSessionModel? _currentGameSession;
  
  @override
  void initState() {
    super.initState();
    _currentGameSession = widget.gameSession;
    _listenToGameChanges();
  }

  void _listenToGameChanges() {
    GameStateService.getGameStateStream(widget.gameSession.gameId).listen((gameState) {
      if (mounted && gameState != null) {
        setState(() {
          _currentGameState = gameState;
        });
      }
    });

    GameSessionService.listenToGameSession(widget.gameSession.gameId).listen((gameSession) {
      if (mounted && gameSession != null) {
        setState(() {
          _currentGameSession = gameSession;
        });
      }
    });
  }

  Future<void> _endGame() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Game'),
        content: const Text('Are you sure you want to end this game?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('End Game', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
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
  }

  void _copyGameCode() {
    Clipboard.setData(ClipboardData(text: widget.gameSession.gameId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Game code copied!'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameSession = _currentGameSession ?? widget.gameSession;
    final gameState = _currentGameState;
    
    return Scaffold(
      backgroundColor: AppColors.gameBackground,
      appBar: AppBar(
        title: Text('${gameSession.gameName}'),
        backgroundColor: AppColors.gamePrimary,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Game Code - Big and prominent
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Game Code',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _copyGameCode,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          gameSession.gameId,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap to copy',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Players - Simple list
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Players',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${gameSession.players.length}/${gameSession.maxPlayers}',
                              style: TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (gameSession.players.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Text(
                              'No players yet\nShare the game code!',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: gameSession.players.length,
                            itemBuilder: (context, index) {
                              final player = gameSession.players[index];
                              final score = gameState?.getPlayerScore(player.userId) ?? 0;
                              final isCurrentTurn = gameState?.currentTurnPlayerId == player.userId;
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isCurrentTurn 
                                    ? AppColors.success.withOpacity(0.1)
                                    : AppColors.gameBackground,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCurrentTurn 
                                      ? AppColors.success 
                                      : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Avatar
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: player.playerColor != null 
                                          ? Color(player.playerColor!).withOpacity(0.2)
                                          : AppColors.gamePrimary.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: player.playerColor != null 
                                            ? Color(player.playerColor!)
                                            : AppColors.gamePrimary,
                                          width: 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          player.displayName.substring(0, 1).toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: player.playerColor != null 
                                              ? Color(player.playerColor!)
                                              : AppColors.gamePrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Name and status
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            player.displayName,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            isCurrentTurn ? '🎯 Taking turn' : '⏳ Waiting',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isCurrentTurn 
                                                ? AppColors.success 
                                                : Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Score
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.warning.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.star, color: AppColors.warning, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$score',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.warning,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
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
              
              const SizedBox(height: 24),
              
              // End Game Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _endGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.stop, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'End Game',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}