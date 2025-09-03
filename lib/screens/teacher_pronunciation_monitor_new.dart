import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_colors.dart';
import '../models/game_session_model.dart';
import '../models/user_model.dart';
import '../models/game_state_model.dart';
import '../services/game_state_service.dart';
import '../services/game_session_service.dart';
import '../services/firestore_service.dart';

class TeacherPronunciationMonitorNew extends StatefulWidget {
  final UserModel user;
  final GameSessionModel gameSession;

  const TeacherPronunciationMonitorNew({
    super.key,
    required this.user,
    required this.gameSession,
  });

  @override
  State<TeacherPronunciationMonitorNew> createState() => _TeacherPronunciationMonitorNewState();
}

class _TeacherPronunciationMonitorNewState extends State<TeacherPronunciationMonitorNew> {
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

  Future<void> _approvePronunciation(String cellKey) async {
    try {
      final playerIds = _currentGameSession?.players.map((p) => p.userId).toList() ?? [];
      await GameStateService.approvePronunciation(
        gameId: widget.gameSession.gameId,
        cellKey: cellKey,
        playerIds: playerIds,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving pronunciation: $e')),
        );
      }
    }
  }

  Future<void> _rejectPronunciation(String cellKey) async {
    try {
      final playerIds = _currentGameSession?.players.map((p) => p.userId).toList() ?? [];
      await GameStateService.rejectPronunciation(
        gameId: widget.gameSession.gameId,
        cellKey: cellKey,
        playerIds: playerIds,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting pronunciation: $e')),
        );
      }
    }
  }

  String _getPlayerName(String playerId) {
    final gameSession = _currentGameSession ?? widget.gameSession;
    final player = gameSession.players.where((p) => p.userId == playerId).firstOrNull;
    return player?.displayName ?? 'Unknown';
  }

  String _formatTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  List<TextSpan> _buildLogNarrative(PronunciationLogEntry logEntry) {
    final isStealAttempt = logEntry.previousOwnerId != null;
    
    // Resolve previous owner name if needed
    String? previousOwnerName = logEntry.previousOwnerName;
    if (isStealAttempt && previousOwnerName == null && logEntry.previousOwnerId != null) {
      final gameSession = _currentGameSession ?? widget.gameSession;
      final previousOwner = gameSession.players
          .where((p) => p.userId == logEntry.previousOwnerId)
          .firstOrNull;
      previousOwnerName = previousOwner?.displayName ?? 'Player';
    }
    
    if (isStealAttempt) {
      // This was a steal attempt
      if (logEntry.approved) {
        // Successful steal
        return [
          TextSpan(
            text: logEntry.playerName,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
          ),
          const TextSpan(text: ' challenged '),
          TextSpan(
            text: previousOwnerName ?? 'opponent',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
          const TextSpan(text: ' for "'),
          TextSpan(
            text: logEntry.word,
            style: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
          ),
          const TextSpan(text: '" and '),
          const TextSpan(
            text: 'WON! 🎉',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
          ),
        ];
      } else {
        // Failed steal attempt
        return [
          TextSpan(
            text: logEntry.playerName,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          const TextSpan(text: ' challenged '),
          TextSpan(
            text: previousOwnerName ?? 'opponent',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const TextSpan(text: ' for "'),
          TextSpan(
            text: logEntry.word,
            style: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
          ),
          const TextSpan(text: '" and '),
          const TextSpan(
            text: 'LOST! ❌',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
        ];
      }
    } else {
      // Regular word attempt (not a steal)
      if (logEntry.approved) {
        return [
          TextSpan(
            text: logEntry.playerName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const TextSpan(text: ' claimed "'),
          TextSpan(
            text: logEntry.word,
            style: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
          ),
          const TextSpan(text: '" ✓'),
        ];
      } else {
        return [
          TextSpan(
            text: logEntry.playerName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const TextSpan(text: ' failed "'),
          TextSpan(
            text: logEntry.word,
            style: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
          ),
          const TextSpan(text: '" ✗'),
        ];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameSession = _currentGameSession ?? widget.gameSession;
    final gameState = _currentGameState;
    final winnerId = gameState?.checkForWinner();
    final hasWinner = winnerId != null;
    
    return Scaffold(
      backgroundColor: AppColors.gameBackground,
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: gameSession.gameId));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Game code copied!'), duration: Duration(seconds: 1)),
            );
          },
          child: Text(
            'Game Code: ${gameSession.gameId}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        backgroundColor: AppColors.gamePrimary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Pending Pronunciations
            if (gameState?.pendingPronunciations.isNotEmpty ?? false) ...[
              _buildPendingSection(gameState!),
              const SizedBox(height: 16),
            ],
            
            // Main content row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Players (left side)
                Expanded(
                  flex: 2,
                  child: _buildPlayersCard(gameSession, gameState, winnerId),
                ),
                
                const SizedBox(width: 16),
                
                // Game Log (right side)
                Expanded(
                  flex: 3,
                  child: _buildGameLogCard(gameState),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Control buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _endGame(false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                    child: const Text('End Game'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _endGame(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                    child: Text(hasWinner ? 'Complete Game' : 'End - No Winner'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingSection(GameStateModel gameState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Pronunciation Pending',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            const SizedBox(height: 16),
            ...gameState.pendingPronunciations.entries.map((entry) {
              final cellKey = entry.key;
              final attempt = entry.value;
              
              return Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        '${attempt.playerName} is pronouncing: ${attempt.word}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _rejectPronunciation(cellKey),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              child: const Text('Reject', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _approvePronunciation(cellKey),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              child: const Text('Approve', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayersCard(GameSessionModel gameSession, GameStateModel? gameState, String? winnerId) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Players',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...gameSession.players.map((player) {
              final score = gameState?.getPlayerScore(player.userId) ?? 0;
              final isWinner = winnerId == player.userId;
              final isCurrentTurn = gameState?.currentTurnPlayerId == player.userId;
              
              return Card(
                color: isWinner ? Colors.green.shade50 : (isCurrentTurn ? Colors.blue.shade50 : null),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: player.playerColor != null ? Color(player.playerColor!) : Colors.blue,
                    child: Text(player.displayName.isNotEmpty ? player.displayName[0].toUpperCase() : '?'),
                  ),
                  title: Text(player.displayName),
                  subtitle: Text(
                    isWinner ? '🏆 Winner!' : (isCurrentTurn ? '🎯 Current Turn' : '⏳ Waiting')
                  ),
                  trailing: Chip(
                    label: Text('$score'),
                    backgroundColor: Colors.orange.shade100,
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildGameLogCard(GameStateModel? gameState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Game Log (${gameState?.pronunciationLog.length ?? 0} entries)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: 300,
              child: (gameState?.pronunciationLog.isNotEmpty ?? false)
                  ? ListView.builder(
                      reverse: true,
                      itemCount: gameState!.pronunciationLog.length,
                      itemBuilder: (context, index) {
                        final logEntry = gameState.pronunciationLog.reversed.toList()[index];
                        final timeAgo = _formatTimeAgo(logEntry.resolvedTime);
                        
                        return Card(
                          color: logEntry.approved ? Colors.green.shade50 : Colors.red.shade50,
                          child: ListTile(
                            leading: Icon(
                              logEntry.approved ? Icons.check_circle : Icons.cancel,
                              color: logEntry.approved ? Colors.green : Colors.red,
                            ),
                            title: RichText(
                              text: TextSpan(
                                style: const TextStyle(color: Colors.black),
                                children: _buildLogNarrative(logEntry),
                              ),
                            ),
                            subtitle: Text(timeAgo),
                          ),
                        );
                      },
                    )
                  : const Center(
                      child: Text(
                        'No pronunciation attempts yet',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _endGame(bool markComplete) async {
    // Implementation for ending game
  }
}