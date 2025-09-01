import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_colors.dart';
import '../models/game_session_model.dart';
import '../models/user_model.dart';
import '../models/game_state_model.dart';
import '../services/game_state_service.dart';
import '../services/game_session_service.dart';
import '../services/firestore_service.dart';

class TeacherPronunciationMonitor extends StatefulWidget {
  final UserModel user;
  final GameSessionModel gameSession;

  const TeacherPronunciationMonitor({
    super.key,
    required this.user,
    required this.gameSession,
  });

  @override
  State<TeacherPronunciationMonitor> createState() => _TeacherPronunciationMonitorState();
}

class _TeacherPronunciationMonitorState extends State<TeacherPronunciationMonitor> {
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
        print('DEBUG: TeacherPronunciationMonitor - game state update:');
        print('  gameId: ${widget.gameSession.gameId}');
        print('  pendingPronunciations: ${gameState.pendingPronunciations.keys.toList()}');
        print('  pendingCount: ${gameState.pendingPronunciations.length}');
        
        // Debug player scores for live updates
        if (_currentGameSession != null) {
          for (final player in _currentGameSession!.players) {
            final score = gameState.getPlayerScore(player.userId);
            print('  ${player.displayName} score: $score');
          }
        }
        
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
      // Get player IDs from current game session
      final playerIds = _currentGameSession?.players.map((p) => p.userId).toList() ?? [];
      
      await GameStateService.approvePronunciation(
        gameId: widget.gameSession.gameId,
        cellKey: cellKey,
        playerIds: playerIds,
      );
      print('✅ Approved pronunciation for cell: $cellKey');
    } catch (e) {
      print('❌ Error approving pronunciation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving pronunciation: $e')),
        );
      }
    }
  }

  Future<void> _rejectPronunciation(String cellKey) async {
    try {
      // Get player IDs from current game session
      final playerIds = _currentGameSession?.players.map((p) => p.userId).toList() ?? [];
      
      await GameStateService.rejectPronunciation(
        gameId: widget.gameSession.gameId,
        cellKey: cellKey,
        playerIds: playerIds,
      );
      print('❌ Rejected pronunciation for cell: $cellKey');
    } catch (e) {
      print('❌ Error rejecting pronunciation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting pronunciation: $e')),
        );
      }
    }
  }

  Future<void> _endGameEarly() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Game Early'),
        content: const Text('Are you sure you want to end this game early? No winner will be declared and no stats will be updated.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('End Early', style: TextStyle(color: Colors.white)),
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

  Future<void> _completeGame() async {
    final winnerId = _currentGameState?.checkForWinner();
    if (winnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No winner yet. Continue playing or end early.')),
      );
      return;
    }

    final winner = _currentGameSession?.players.firstWhere((p) => p.userId == winnerId);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Game'),
        content: Text('Declare ${winner?.displayName ?? 'Unknown'} as the winner and update all player stats?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Complete Game', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Update all player stats
        await _updatePlayerStats(winnerId);
        
        // End the game session
        await GameSessionService.endGameSession(
          gameId: widget.gameSession.gameId,
          winnerId: winnerId,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Game completed! ${winner?.displayName} wins. Stats updated.'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pushReplacementNamed('/admin-dashboard');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error completing game: $e')),
          );
        }
      }
    }
  }

  Future<void> _endGameWithoutWinner() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Game - No Winner'),
        content: const Text('Complete this game without declaring a winner? All player stats will be updated based on words read, but no one will be marked as the winner.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Complete - No Winner', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Update all player stats without a winner (normal game completion)
        await _updatePlayerStatsWithoutWinner();
        
        // End the game session without winner
        await GameSessionService.endGameSession(
          gameId: widget.gameSession.gameId,
          winnerId: null, // No winner
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Game completed without winner. All player stats updated.'),
              backgroundColor: AppColors.warning,
            ),
          );
          Navigator.of(context).pushReplacementNamed('/admin-dashboard');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error completing game: $e')),
          );
        }
      }
    }
  }

  Future<void> _updatePlayerStats(String winnerId) async {
    if (_currentGameState == null || _currentGameSession == null) return;

    try {
      for (final player in _currentGameSession!.players) {
        final score = _currentGameState!.getPlayerScore(player.userId);
        final isWinner = player.userId == winnerId;
        
        // Update player stats in Firestore using StudentModel approach
        await FirestoreService.updateStudentStats(
          studentId: player.userId,
          wordsRead: score,
          won: isWinner,
        );
      }
      
      print('✅ All player stats updated successfully');
    } catch (e) {
      print('❌ Error updating player stats: $e');
      rethrow;
    }
  }

  Future<void> _updatePlayerStatsWithoutWinner() async {
    if (_currentGameState == null || _currentGameSession == null) return;

    try {
      for (final player in _currentGameSession!.players) {
        final score = _currentGameState!.getPlayerScore(player.userId);
        
        // Update player stats in Firestore - game completed normally but no winner
        await FirestoreService.updateStudentStats(
          studentId: player.userId,
          wordsRead: score,
          won: false, // No winner in this game
        );
      }
      
      print('✅ All player stats updated (game completed without winner)');
    } catch (e) {
      print('❌ Error updating player stats without winner: $e');
      rethrow;
    }
  }

  void _copyGameCode() {
    Clipboard.setData(ClipboardData(text: widget.gameSession.gameId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Game code copied!'), duration: Duration(seconds: 1)),
    );
  }

  String _getPlayerName(String playerId) {
    final player = _currentGameSession?.players.firstWhere(
      (p) => p.userId == playerId,
      orElse: () => _currentGameSession!.players.first,
    );
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
          onTap: _copyGameCode,
          child: Text(
            'Game Code: ${gameSession.gameId}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        backgroundColor: AppColors.gamePrimary,
        foregroundColor: Colors.white,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Pronunciation Approval Section
            if (gameState?.pendingPronunciations.isNotEmpty ?? false)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.warning, width: 2),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.mic, size: 40, color: Colors.orange),
                    const SizedBox(height: 12),
                    const Text(
                      'Pronunciation Pending',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...gameState!.pendingPronunciations.entries.map((entry) {
                      final cellKey = entry.key;
                      final pronunciationAttempt = entry.value;
                      final playerName = pronunciationAttempt.playerName;
                      final word = pronunciationAttempt.word;
                      
                      // Check if this is a steal attempt
                      final currentOwner = gameState.getCellOwner(cellKey);
                      final isStealAttempt = currentOwner != null && currentOwner != pronunciationAttempt.playerId;
                      String? victimName;
                      if (isStealAttempt) {
                        victimName = _getPlayerName(currentOwner!);
                      }
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            if (isStealAttempt) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.security, color: Colors.purple.shade700, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      '⚔️ STEAL ATTEMPT from $victimName',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.purple.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Text(
                              isStealAttempt 
                                ? '$playerName is trying to steal:'
                                : '$playerName is pronouncing:',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              word.toUpperCase(),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: isStealAttempt ? Colors.purple : Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _rejectPronunciation(cellKey),
                                    icon: const Icon(Icons.close, color: Colors.white),
                                    label: const Text('Reject', style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.error,
                                      padding: const EdgeInsets.all(12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _approvePronunciation(cellKey),
                                    icon: const Icon(Icons.check, color: Colors.white),
                                    label: const Text('Approve', style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.success,
                                      padding: const EdgeInsets.all(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),

            // Players List
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                        if (hasWinner)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '🏆 WINNER!',
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
                            final isWinner = player.userId == winnerId;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isWinner 
                                  ? AppColors.success.withOpacity(0.1)
                                  : (isCurrentTurn 
                                    ? AppColors.primary.withOpacity(0.1)
                                    : AppColors.gameBackground),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isWinner 
                                    ? AppColors.success
                                    : (isCurrentTurn 
                                      ? AppColors.primary 
                                      : Colors.transparent),
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
                                        Row(
                                          children: [
                                            Text(
                                              player.displayName,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (isWinner) ...[
                                              const SizedBox(width: 8),
                                              const Text('👑', style: TextStyle(fontSize: 18)),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          isWinner 
                                            ? '🏆 Winner!'
                                            : (isCurrentTurn ? '🎯 Taking turn' : '⏳ Waiting'),
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isWinner 
                                              ? AppColors.success
                                              : (isCurrentTurn 
                                                ? AppColors.primary 
                                                : Colors.grey[600]),
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
            
            // Game Log Section
            if (gameState?.pronunciationLog.isNotEmpty ?? false)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.history, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Game Log',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${gameState!.pronunciationLog.length} attempts',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200, // Fixed height for the log
                      child: ListView.builder(
                        itemCount: gameState.pronunciationLog.length,
                        reverse: true, // Show newest first
                        itemBuilder: (context, index) {
                          final logEntry = gameState.pronunciationLog.reversed.toList()[index];
                          final timeAgo = _formatTimeAgo(logEntry.resolvedTime);
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: logEntry.approved 
                                  ? AppColors.success.withOpacity(0.1)
                                  : AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: logEntry.approved 
                                    ? AppColors.success.withOpacity(0.3)
                                    : AppColors.error.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Status icon
                                Icon(
                                  logEntry.approved ? Icons.check_circle : Icons.cancel,
                                  color: logEntry.approved ? AppColors.success : AppColors.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                
                                // Player info and word
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          style: const TextStyle(color: Colors.black),
                                          children: [
                                            TextSpan(
                                              text: logEntry.playerName,
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            const TextSpan(text: ' said '),
                                            TextSpan(
                                              text: '"${logEntry.word}"',
                                              style: const TextStyle(
                                                fontStyle: FontStyle.italic,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        timeAgo,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Status text
                                Text(
                                  logEntry.approved ? 'Approved' : 'Rejected',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: logEntry.approved ? AppColors.success : AppColors.error,
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
            
            // Game Control Buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // End Game Early Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _endGameEarly,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stop, size: 20),
                          SizedBox(height: 4),
                          Text('End Early', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Complete Game Button  
                  Expanded(
                    child: ElevatedButton(
                      onPressed: hasWinner ? _completeGame : _endGameWithoutWinner,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasWinner ? AppColors.success : AppColors.warning,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(hasWinner ? Icons.emoji_events : Icons.stop_circle_outlined, size: 20),
                          const SizedBox(height: 4),
                          Text(
                            hasWinner ? 'Complete Game' : 'Complete - No Winner',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}