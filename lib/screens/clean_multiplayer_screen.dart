import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:flutter_tts/flutter_tts.dart';
import '../config/app_colors.dart';
import '../widgets/animated_dice.dart';
import '../widgets/player_avatar.dart';
import '../models/user_model.dart';
import '../models/game_session_model.dart';
import '../services/game_state_service.dart';
import '../services/game_session_service.dart';
import '../services/firestore_service.dart';
import '../services/session_service.dart';
import '../models/game_state_model.dart';
import '../models/player_colors.dart';
import '../widgets/winning_celebration.dart';

class CleanMultiplayerScreen extends StatefulWidget {
  final UserModel user;
  final GameSessionModel gameSession;
  final bool isTeacherMode;
  final List<UserModel>? allPlayers;

  const CleanMultiplayerScreen({
    super.key,
    required this.user,
    required this.gameSession,
    this.isTeacherMode = false,
    this.allPlayers,
  });

  @override
  State<CleanMultiplayerScreen> createState() => _CleanMultiplayerScreenState();
}

class _CleanMultiplayerScreenState extends State<CleanMultiplayerScreen> {
  final math.Random _random = math.Random();
  
  // Game state
  Stream<GameStateModel?>? _gameStateStream;
  GameStateModel? _currentGameState;
  
  // Game session state
  Stream<GameSessionModel?>? _gameSessionStream;
  GameSessionModel? _currentGameSession;
  
  // UI state
  bool _isRolling = false;
  bool _isProcessingSelection = false; // Prevent multiple clicks during processing
  DateTime? _lastSelectionTime; // Track last selection time for debouncing
  String? _lastSelectedCell; // Track last selected cell to prevent re-selection
  int _currentDiceRoll = 0; // Track current dice value
  bool _hasSelectedThisTurn = false; // Track if player already selected for this dice roll
  String? _previousTurnPlayerId; // Track previous turn to detect turn changes
  
  // Game content - 6x6 grid
  late List<List<String>> gridContent;
  
  // Initial random dice value
  late int _initialDiceValue;
  
  // Game end flag to prevent multiple win dialogs
  bool _gameEnded = false;
  bool _resultsSaved = false; // Track if results have been saved
  
  // Text-to-speech
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initializeGrid();
    _initializeRandomDice();
    _initializeGameState();
    _initializeGameSession();
    _initializeTts();
  }
  
  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.4);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }
  
  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  void _initializeRandomDice() {
    // Always initialize with a random value between 1-6
    _initialDiceValue = _random.nextInt(6) + 1;
  }
  
  void _showWinnerDialog(String winnerId) {
    if (_gameEnded) return;
    _gameEnded = true;
    
    final winnerName = _getPlayerName(winnerId);
    // Ensure proper comparison by trimming and converting to same case if needed
    final isCurrentPlayer = winnerId.trim() == widget.user.id.trim();
    
    print('DEBUG: Winner Dialog - winnerId: "$winnerId", currentUserId: "${widget.user.id}", isCurrentPlayer: $isCurrentPlayer');
    print('DEBUG: winnerId length: ${winnerId.length}, currentUserId length: ${widget.user.id.length}');
    
    // Calculate personal stats for this player
    final wordsRead = _currentGameState?.getPlayerScore(widget.user.id) ?? 0;
    
    // Show celebration for winner or results dialog for others
    if (isCurrentPlayer) {
      print('DEBUG: Showing confetti celebration for winner');
      // Show confetti celebration for the winner
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WinningCelebration(
          winnerName: widget.user.displayName,
          isCurrentPlayer: true,
          onComplete: () {
            if (mounted) {
              Navigator.of(context).pop();
              // Show results dialog for winner, which will then navigate home
              _showResultsDialog(wordsRead, winnerName, isCurrentPlayer);
            }
          },
        ),
      );
    } else {
      print('DEBUG: Showing results dialog for loser');
      // Show results dialog for non-winners
      _showResultsDialog(wordsRead, winnerName, isCurrentPlayer);
    }
  }

  void _showResultsDialog(int wordsRead, String winnerName, bool isCurrentPlayer) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Text(
                isCurrentPlayer ? "Congratulations!" : "You lost ☹️",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isCurrentPlayer ? AppColors.success : AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              
              // Winner announcement
              if (!isCurrentPlayer)
                Text(
                  "$winnerName won the game!",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 20),
              
              // Personal stats
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Column(
                  children: [
                    Text(
                      "Your Results",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            // Show player avatar instead of ABC icon
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _getUserColor(widget.user),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  widget.user.avatarUrl ?? widget.user.displayName[0],
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "$wordsRead",
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text("Words Read"),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // OK button
              ElevatedButton(
                onPressed: () async {
                  if (!mounted) return;
                  final navigator = Navigator.of(context);
                  navigator.pop(); // Close dialog
                  // Save results and return to home
                  await _saveGameResults();
                  // Navigate back to home page
                  if (mounted) {
                    navigator.popUntil((route) => route.isFirst);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "OK",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveGameResults() async {
    try {
      if (_currentGameState == null || _resultsSaved) return;
      
      _resultsSaved = true; // Prevent duplicate saves
      
      final currentUser = widget.user;
      final winnerId = _currentGameState!.checkForWinner();
      final isWinner = winnerId == currentUser.id;
      final wordsRead = _currentGameState!.getPlayerScore(currentUser.id);
      
      
      // Update student stats using the StudentModel approach
      await FirestoreService.updateStudentStats(
        studentId: currentUser.id,
        wordsRead: wordsRead,
        won: isWinner,
      );
      
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Results saved! Games played +1, Words read +$wordsRead${isWinner ? ', Games won +1' : ''}'),
          backgroundColor: AppColors.success,
        ),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save results: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _initializeGrid() {
    // Use AI-generated words from game session if available, otherwise use default
    if (widget.gameSession.wordGrid != null && widget.gameSession.wordGrid!.isNotEmpty) {
      gridContent = List<List<String>>.from(
        widget.gameSession.wordGrid!.map((row) => List<String>.from(row))
      );
    } else {
      // Fallback to default grid
      gridContent = [
        ['cat', 'dog', 'fish', 'bird', 'horse', 'cow'],
        ['red', 'blue', 'green', 'yellow', 'pink', 'purple'],
        ['car', 'bus', 'train', 'plane', 'bike', 'boat'],
        ['apple', 'banana', 'orange', 'grape', 'cherry', 'lemon'],
        ['happy', 'sad', 'angry', 'excited', 'calm', 'tired'],
        ['sun', 'moon', 'star', 'cloud', 'rain', 'snow'],
      ];
    }
  }

  Future<void> _initializeGameState() async {
    try {
      _gameStateStream = GameStateService.getGameStateStream(widget.gameSession.gameId);
      
      final existingState = await GameStateService.getGameState(widget.gameSession.gameId);
      if (existingState == null) {
        await GameStateService.initializeGameState(
          widget.gameSession.gameId,
          widget.gameSession.players.map((p) => p.userId).toList(),
        );
      }
    } catch (e) {
      // Game state initialization failed, continue without it
    }
  }

  void _initializeGameSession() {
    try {
      _gameSessionStream = GameSessionService.getGameSessionStream(widget.gameSession.gameId);
      _currentGameSession = widget.gameSession;
      
      // Save session for reconnection support
      // This ensures players can rejoin if they get disconnected
      SessionService.saveGameSession(widget.gameSession);
      SessionService.saveCurrentRoute('/multiplayer-game');
    } catch (e) {
      // Session saving failed, continue without it
    }
  }

  Future<void> _rollDice() async {
    if (_isRolling) return;
    
    // Check if game is waiting for more players
    if (_currentGameSession?.isWaiting == true) {
      _showWaitingForPlayersMessage();
      return;
    }
    
    // Check if player has already rolled the dice this turn
    if (_currentGameState?.currentPlayerId == widget.user.id && 
        _currentGameState?.currentDiceValue != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have already rolled the dice this turn!'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Check if player has a pending pronunciation waiting for teacher approval
    if (_playerHasPendingPronunciation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wait for teacher to approve or reject your word before rolling again!'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() => _isRolling = true);
    
    // Reset selection state when rolling new dice - this is a new turn
    _resetSelectionState();
    
    // Animate for 1 second
    await Future.delayed(const Duration(milliseconds: 1000));
    
    final diceValue = _random.nextInt(6) + 1;
    
    // Update game state
    await GameStateService.updateDiceRoll(
      gameId: widget.gameSession.gameId,
      playerId: widget.user.id,
      diceValue: diceValue,
    );
    
    setState(() {
      _isRolling = false;
      _currentDiceRoll = diceValue;
      _hasSelectedThisTurn = false; // New dice roll = new turn = can select again
    });
  }

  // Helper methods to avoid duplicate calculations
  bool get _isMyTurn => _currentGameState?.currentTurnPlayerId == widget.user.id ?? false;
  bool get _playerHasPendingPronunciation => _currentGameState?.pendingPronunciations.values
      .any((attempt) => attempt.playerId == widget.user.id) ?? false;
  bool get _hasAlreadyRolled => _currentGameState?.currentPlayerId == widget.user.id && 
      _currentGameState?.currentDiceValue != null;
  
  // Device type helpers
  bool get _isMobile => MediaQuery.of(context).size.width < 600;
  bool get _isTablet => MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 1200;
  bool get _isDesktopWeb => kIsWeb && MediaQuery.of(context).size.width >= 1200;
  bool get _isWeb => kIsWeb;

  // CENTRALIZED TAP HANDLER - All cell taps MUST go through this method
  // This ensures consistent validation and prevents multiple selections
  bool _canSelectCell({
    required int row,
    required int col,
    required String cellKey,
    bool showDebugLogs = true,
  }) {
    // Check if we're already processing another selection
    if (_isProcessingSelection) {
      return false;
    }
    
    if (_currentGameState == null) {
      return false;
    }
    
    // Check if game is waiting for more players
    if (_currentGameSession?.isWaiting == true) {
      return false;
    }
    
    // Check if it's player's turn
    if (!_isMyTurn) {
      return false;
    }
    
    // Check if dice has been rolled
    final diceValue = _currentGameState!.currentDiceValue;
    if (showDebugLogs) {
    }
    
    if (diceValue == null) {
      return false;
    }
    
    // Check if valid column for dice roll
    final validColumn = col + 1 == diceValue;
    if (!validColumn) {
      return false;
    }
    
    // Check if cell is already owned BY THE CURRENT PLAYER (stealing is allowed from others)
    final cellOwner = _currentGameState!.getCellOwner(cellKey);
    if (cellOwner == widget.user.id) {
      return false;
    } else if (cellOwner != null) {
      // Cell is owned by another player - stealing is allowed!
    }
    
    // Check if there's already a pending pronunciation for this cell
    final hasPendingPronunciation = _currentGameState!.hasPendingPronunciation(cellKey);
    if (hasPendingPronunciation) {
      return false;
    }
    
    // CRITICAL: Check if player already made a selection this dice roll
    if (_hasSelectedThisTurn) {
      return false;
    }
    
    // SECONDARY: Check if player has ANY pending pronunciations (prevents multiple selections)
    if (_playerHasPendingPronunciation) {
      if (showDebugLogs) {
        final pendingAttempts = _currentGameState!.pendingPronunciations.values
            .where((attempt) => attempt.playerId == widget.user.id)
            .map((a) => '${a.cellKey}:${a.word}')
            .toList();
      }
      return false;
    }
    
    return true;
  }
  
  void _showValidationError(int row, int col, String cellKey) {
    final diceValue = _currentGameState?.currentDiceValue;
    
    // Check each validation condition and show specific message
    
    // 1. No dice rolled
    if (diceValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Roll the dice first!'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }
    
    // 2. Wrong column for dice value
    final validColumn = col + 1 == diceValue;
    if (!validColumn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dice shows $diceValue - select from column $diceValue!'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // 3. Already own this cell
    final cellOwner = _currentGameState!.getCellOwner(cellKey);
    if (cellOwner == widget.user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already own this square!'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }
    
    // 4. Cell has pending pronunciation
    final hasPendingPronunciation = _currentGameState!.hasPendingPronunciation(cellKey);
    if (hasPendingPronunciation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Someone else is already attempting this word!'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.purple,
        ),
      );
      return;
    }
    
    // 5. Already selected this turn
    if (_hasSelectedThisTurn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only select one square per dice roll!'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // 6. Player has pending pronunciations
    if (_playerHasPendingPronunciation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wait for teacher to review your current word!'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // 7. Not player's turn (fallback message)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You cannot select this square right now.'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.grey,
      ),
    );
  }
  
  void _selectCell(int row, int col) async {
    final cellKey = '$row,$col';
    final word = gridContent[row][col];
    
    
    // IMMEDIATE: Check if we're already processing a selection
    if (_isProcessingSelection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait...'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.grey,
        ),
      );
      return;
    }
    
    // DEBOUNCE: Prevent rapid clicks within 1 second
    if (_lastSelectionTime != null) {
      final timeSinceLastSelection = DateTime.now().difference(_lastSelectionTime!);
      if (timeSinceLastSelection.inMilliseconds < 1000) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Slow down! One selection at a time.'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }
    
    // DUPLICATE CHECK: Prevent selecting the same cell twice
    if (_lastSelectedCell == cellKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already selected this square!'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Show specific validation error messages
    if (!_canSelectCell(row: row, col: col, cellKey: cellKey)) {
      _showValidationError(row, col, cellKey);
      return;
    }
    
    // DOUBLE-CHECK: Make absolutely sure no pending pronunciations exist
    final pendingCheck = _currentGameState?.pendingPronunciations.values
        .any((attempt) => attempt.playerId == widget.user.id) ?? false;
    
    if (pendingCheck) {
      final pending = _currentGameState!.pendingPronunciations.values
          .where((attempt) => attempt.playerId == widget.user.id)
          .map((a) => '${a.cellKey}:${a.word}')
          .toList();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wait for teacher to approve or reject your current word!'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    
    // CRITICAL: Set ALL blocking flags immediately
    setState(() {
      _isProcessingSelection = true;
      _lastSelectionTime = DateTime.now();
      _lastSelectedCell = cellKey;
      _hasSelectedThisTurn = true; // CRITICAL: Block any additional selections for this dice roll
    });
    
    try {
      // Start pronunciation attempt
      final playerIds = widget.gameSession.players.map((p) => p.userId).toList();
      await GameStateService.startPronunciationAttemptAndSwitchTurn(
        gameId: widget.gameSession.gameId,
        playerId: widget.user.id,
        playerName: widget.user.displayName,
        cellKey: cellKey,
        word: word,
        playerIds: playerIds,
      );
      
      
      // Keep the processing flag true for longer to ensure Firebase updates
      await Future.delayed(const Duration(seconds: 2));
      
    } catch (e) {
      // Reset on error
      if (mounted) {
        setState(() {
          _isProcessingSelection = false;
          _lastSelectedCell = null;
        });
      }
    } finally {
      // Only clear the processing flag after significant delay
      if (mounted) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _isProcessingSelection = false;
            });
          }
        });
      }
    }
  }

  void _approvePronunciation(String cellKey) async {
    // Get player IDs from current game session
    final playerIds = (_currentGameSession ?? widget.gameSession).players.map((p) => p.userId).toList();
    
    await GameStateService.approvePronunciation(
      gameId: widget.gameSession.gameId,
      cellKey: cellKey,
      playerIds: playerIds,
    );
    
    // DON'T reset selection state here - player should only get ONE selection per dice roll
  }

  void _rejectPronunciation(String cellKey) async {
    // Get player IDs from current game session
    final playerIds = (_currentGameSession ?? widget.gameSession).players.map((p) => p.userId).toList();
    
    await GameStateService.rejectPronunciation(
      gameId: widget.gameSession.gameId,
      cellKey: cellKey,
      playerIds: playerIds,
    );
    
    // DON'T reset selection state here - player should only get ONE selection per dice roll
  }
  
  void _resetSelectionState() {
    if (mounted) {
      setState(() {
        _isProcessingSelection = false;
        _lastSelectedCell = null;
        _lastSelectionTime = null;
        _hasSelectedThisTurn = false; // Reset turn-based blocking
      });
    }
  }

  String _getPlayerName(String playerId) {
    final gameSession = _currentGameSession ?? widget.gameSession;
    final player = gameSession.players.firstWhere(
      (p) => p.userId == playerId,
      orElse: () => gameSession.players.first,
    );
    return player.displayName;
  }

  Future<void> _handleGameEnd() async {
    if (_currentGameState == null || _currentGameSession == null) return;

    final winnerId = _currentGameState!.checkForWinner();
    final hasWinner = winnerId != null;

    try {
      if (hasWinner) {
        // Winner determined - update student stats and end game session
        final gameSession = _currentGameSession!;
        for (final player in gameSession.players) {
          final wordsRead = _currentGameState!.getPlayerScore(player.userId);
          await FirestoreService.updateStudentStats(
            studentId: player.userId,
            wordsRead: wordsRead,
          );
        }
        
        // End the game session with winner
        await GameSessionService.endGameSession(
          gameId: gameSession.gameId,
          winnerId: winnerId,
        );
        
        // Show completion message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Game completed! ${_getPlayerName(winnerId)} wins. Stats updated.'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Game ended early - no points awarded, end game session without winner
        await GameSessionService.endGameSession(
          gameId: _currentGameSession!.gameId,
          winnerId: null,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Game ended. No points awarded.'),
              backgroundColor: AppColors.warning,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      // Navigate back
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // Helper method to get player's assigned color from their stored color value
  Color _getPlayerColor(PlayerInGame player) {
    if (player.playerColor != null) {
      return Color(player.playerColor!);
    }
    // Fallback to default color if no color assigned
    return PlayerColors.getDefaultColor();
  }

  // Helper method to get user's assigned color from their stored color value
  Color _getUserColor(UserModel user) {
    if (user.playerColor != null) {
      return user.playerColor!;
    }
    // Fallback to default color if no color assigned
    return PlayerColors.getDefaultColor();
  }

  @override
  Widget build(BuildContext context) {
    final gameCode = widget.gameSession.gameId.length >= 6 
        ? widget.gameSession.gameId.substring(0, 6).toUpperCase() 
        : widget.gameSession.gameId.toUpperCase();
    
    return Scaffold(
      backgroundColor: AppColors.gameBackground,
      appBar: AppBar(
        backgroundColor: AppColors.gamePrimary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: widget.isTeacherMode ? Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Game Code: $gameCode',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 12),
            IconButton(
              icon: Icon(Icons.copy, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: gameCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Game code copied!'),
                    backgroundColor: AppColors.success,
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              tooltip: 'Copy code',
            ),
          ],
        ) : Text(
          'Roll and Read',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [],
        centerTitle: true,
        elevation: 2,
      ),
      body: StreamBuilder<GameSessionModel?>(
        stream: _gameSessionStream,
        builder: (context, gameSessionSnapshot) {
          // Check if game has been deleted (for students)
          if (!widget.isTeacherMode && gameSessionSnapshot.data == null && gameSessionSnapshot.connectionState != ConnectionState.waiting) {
            // Game was deleted by teacher - show dialog and navigate home
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showGameDeletedDialog();
              }
            });
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading...',
                    style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }
          
          _currentGameSession = gameSessionSnapshot.data ?? widget.gameSession;
          
          return StreamBuilder<GameStateModel?>(
            stream: _gameStateStream,
            builder: (context, gameStateSnapshot) {
              final newGameState = gameStateSnapshot.data;
              
              // Detect turn changes and reset selection state for new player
              if (newGameState != null && _currentGameState != null) {
                final currentTurnPlayer = newGameState.currentTurnPlayerId;
                final previousTurnPlayer = _previousTurnPlayerId;
                
                if (currentTurnPlayer != previousTurnPlayer && currentTurnPlayer != null) {
                  
                  // If it's now my turn and I'm not in teacher mode, reset selection state and dice
                  if (currentTurnPlayer == widget.user.id && !widget.isTeacherMode) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _hasSelectedThisTurn = false; // Allow new player to make selection
                          _isProcessingSelection = false;
                          _lastSelectedCell = null;
                          _lastSelectionTime = null;
                          _currentDiceRoll = 0; // Reset dice value - player must roll fresh dice
                        });
                      }
                    });
                  }
                  
                  _previousTurnPlayerId = currentTurnPlayer;
                }
              }
              
              _currentGameState = newGameState;
              
              // Check for winner and show celebration (moved from build method)
              final winnerId = _currentGameState?.checkForWinner();
              if (winnerId != null && !_gameEnded) {
                print('DEBUG: Winner detected in StreamBuilder! winnerId: $winnerId, currentUserId: ${widget.user.id}');
                print('DEBUG: winnerId type: ${winnerId.runtimeType}, currentUserId type: ${widget.user.id.runtimeType}');
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _showWinnerDialog(winnerId);
                  }
                });
              }
              
              // Check if game session has ended (for students)
              if (!widget.isTeacherMode && _currentGameSession != null) {
                if (_currentGameSession!.status == GameStatus.completed || 
                    _currentGameSession!.status == GameStatus.cancelled) {
                  // Game ended by teacher - navigate back to home
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  });
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Game ended by teacher',
                          style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }
              }
              
              if (_currentGameState == null) {
                return const Center(child: CircularProgressIndicator());
              }

              return SafeArea(
                child: _buildGameLayout(),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildGameLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        // Use consistent proportions for all screen sizes - balanced padding
        final padding = screenWidth * 0.015; // 1.5% of screen width for padding (balanced approach)
        
        // Calculate available space
        final safeHeight = screenHeight - padding * 2;
        final safeWidth = screenWidth - padding * 2;
        
        // Better space distribution with more spacing
        // Device type detection
        final screenAspectRatio = safeWidth / safeHeight;
        
        // Responsive space allocation - MORE space for board now! Bigger dice especially for mobile
        final diceHeight = _isMobile ? safeHeight * 0.10 : safeHeight * 0.08;   // Dice space - bigger for mobile  
        final controlsHeight = widget.isTeacherMode 
            ? (_isMobile ? safeHeight * 0.09 : safeHeight * 0.11) 
            : safeHeight * 0.02; // Smaller teacher controls on mobile
        // Board gets much more space now without player cards!
        final boardAreaHeight = _isMobile ? safeHeight * 0.92 : safeHeight * 0.88;
        
        // Responsive board sizing - more aggressive on mobile for better usability
        
        // Adjust scaling factors based on device type - balanced space usage
        double widthScale, heightScale;
        if (_isMobile) {
          // Mobile: use more space but leave room for overflow protection
          widthScale = screenAspectRatio > 0.7 ? 0.96 : 0.94; // Portrait vs landscape
          heightScale = 0.96; // Leave some buffer for overflow
        } else if (_isTablet) {
          // Tablet: more generous approach
          widthScale = 0.90;
          heightScale = 0.90;
        } else {
          // Desktop: conservative but improved
          widthScale = 0.86;
          heightScale = 0.86;
        }
        
        final maxBoardSize = math.min(safeWidth * widthScale, boardAreaHeight * heightScale);
        final boardSize = maxBoardSize;
        
        return SizedBox(
          height: constraints.maxHeight,
          width: constraints.maxWidth,
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Turn indicator banner
                    _buildTurnIndicator(safeHeight),
                    
                    // Dice area - centered on web, fixed spacing on mobile
                    if (_isWeb)
                      Expanded(
                        flex: 1,
                        child: Center(
                          child: SizedBox(
                            height: diceHeight,
                            child: _buildCenteredDice(),
                          ),
                        ),
                      )
                    else ...[
                      // Fixed spacing for mobile/tablet
                      SizedBox(height: safeHeight * 0.04),
                      SizedBox(
                        height: diceHeight,
                        child: Center(
                          child: _buildCenteredDice(),
                        ),
                      ),
                    ],

                    // Game board with overlay (responsive)
                    Expanded(
                      flex: _isMobile ? 3 : 4, // Less space on mobile, more on tablet
                      child: Stack(
                    children: [
                      // Game board
                      Center(
                        child: _buildGameBoard(boardSize),
                      ),
                      // Dark overlay when pronunciation approval is showing
                      if (widget.isTeacherMode && (_currentGameState?.pendingPronunciations.isNotEmpty ?? false))
                        Positioned.fill(
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 300),
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ),
                      // Pronunciation approval overlay centered on board
                      if (widget.isTeacherMode && (_currentGameState?.pendingPronunciations.isNotEmpty ?? false))
                        Positioned.fill(
                          child: Center(
                            child: AnimatedScale(
                              scale: 1.0,
                              duration: Duration(milliseconds: 300),
                              curve: Curves.easeOutBack,
                              child: _buildPronunciationApproval(),
                            ),
                          ),
                        ),
                    ],
                      ),
                    ),

                // Flexible spacer - more on mobile for better centering
                if (_isMobile)
                  Expanded(
                    flex: 1,
                    child: SizedBox(),
                  )
                else
                  SizedBox(height: safeHeight * 0.01),
                
                // Controls
                SizedBox(
                  height: controlsHeight,
                  child: _buildControls(),
                ),
                  ],
                ),
            ),
        );
      },
    );
  }

  Widget _buildPronunciationApproval() {
    final pendingPronunciations = _currentGameState?.pendingPronunciations ?? {};
    
    if (!widget.isTeacherMode || pendingPronunciations.isEmpty) {
      return SizedBox.shrink();
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 768;
        final isPhone = constraints.maxWidth < 600;
        
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 30 : 24,
            vertical: isTablet ? 20 : 16,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.warning, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 5,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.record_voice_over,
                size: isTablet ? 28 : 24,
                color: AppColors.warning,
              ),
              SizedBox(width: isTablet ? 12 : 8),
              Text(
                'Did they say it correctly?',
                style: TextStyle(
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(width: isTablet ? 30 : 20),
              // Approve button
              Material(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(12),
                elevation: 4,
                child: InkWell(
                  onTap: () => _approvePronunciation(pendingPronunciations.keys.first),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 24 : 20,
                      vertical: isTablet ? 12 : 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: isTablet ? 28 : 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'YES',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: isTablet ? 20 : 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: isTablet ? 16 : 12),
              // Reject button
              Material(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(12),
                elevation: 4,
                child: InkWell(
                  onTap: () => _rejectPronunciation(pendingPronunciations.keys.first),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 24 : 20,
                      vertical: isTablet ? 12 : 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.cancel,
                          color: Colors.white,
                          size: isTablet ? 28 : 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'NO',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: isTablet ? 20 : 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCenteredDice() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Get current dice value - show blank if none rolled yet
        final gameStateDiceValue = _currentGameState?.currentDiceValue;
        final int diceValue;
        
        if (gameStateDiceValue == null) {
          // No dice rolled yet - show a blank/disabled state
          diceValue = 0; // 0 means blank dice
        } else if (gameStateDiceValue < 1 || gameStateDiceValue > 6) {
          // Invalid dice value - fall back to initial
          diceValue = _initialDiceValue;
        } else {
          diceValue = gameStateDiceValue;
        }
        
        // Proportional sizing - larger animated dice
        final diceSize = constraints.maxHeight * 0.8;
        final fontSize = constraints.maxHeight * 0.25;
        
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
              // Only show dice if game is not over
              if (!_gameEnded && _currentGameState?.checkForWinner() == null) ...[
                // Dice
                GestureDetector(
                  onTap: widget.isTeacherMode 
                      ? () => _showTeacherCantRollMessage()
                      : (_currentGameSession?.isWaiting == true
                          ? () => _showWaitingForPlayersMessage()
                          : (!_isMyTurn 
                              ? () => _showNotYourTurnMessage()
                              : (_hasAlreadyRolled
                                  ? () => _showAlreadyRolledMessage()
                                  : (_playerHasPendingPronunciation
                                      ? () => _showPendingPronunciationMessage()
                                      : (_isRolling 
                                          ? () => _showDiceAlreadyRollingMessage()
                                          : _rollDice))))),
                  child: AnimatedDice(
                    value: diceValue,
                    isRolling: _isRolling,
                    size: diceSize,
                  ),
                ),
                
                // Status text next to dice
                SizedBox(width: constraints.maxWidth * 0.02),
                Text(
                  widget.isTeacherMode 
                    ? (_isRolling ? 'Rolling...' : 'Teacher View')
                    : (_currentGameSession?.isWaiting == true
                      ? 'Waiting for players...'
                      : (_isMyTurn 
                          ? (_hasAlreadyRolled
                              ? 'Select a word!'
                              : (_playerHasPendingPronunciation
                                  ? 'Waiting for teacher...'
                                  : (_isRolling ? 'Rolling...' : 'Tap to roll!')))
                          : 'Waiting for turn...')),
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary, // Always use primary color
                  ),
                ),
              ],
          ],
        );
      },
    );
  }

  Widget _buildPlayerCards() {
    final gameSession = _currentGameSession ?? widget.gameSession;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        // Proportional sizing based on available space
        final avatarSize = height * 0.35;
        final fontSize = height * 0.18;
        final scoreFontSize = height * 0.22;
        final padding = width * 0.01;
        
        return Container(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: gameSession.players.map((player) {
                  final score = _currentGameState?.getPlayerScore(player.userId) ?? 0;
                  final isCurrentTurn = _currentGameState?.currentTurnPlayerId == player.userId;
                  final isCurrentUser = player.userId == widget.user.id;
                  // Assign color based on player position for consistent identification
                  final playerPosition = gameSession.players.indexOf(player);
                  final playerColor = playerPosition < PlayerColors.availableColors.length
                      ? PlayerColors.availableColors[playerPosition].color
                      : PlayerColors.getDefaultColor();
                  
                  return Flexible(
                    child: Container(
                      constraints: BoxConstraints(maxWidth: 200),
                      margin: EdgeInsets.symmetric(horizontal: padding * 0.5),
                      padding: EdgeInsets.symmetric(
                        horizontal: padding, 
                        vertical: padding * 0.75
                      ),
                      decoration: BoxDecoration(
                        color: isCurrentTurn 
                          ? AppColors.success.withOpacity(0.1)
                          : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCurrentTurn ? AppColors.success : playerColor.withOpacity(0.4),
                          width: isCurrentTurn ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Enhanced Player Avatar with better visual differentiation
                          PlayerAvatarCompact(
                            displayName: player.displayName,
                            avatarUrl: player.avatarUrl,
                            playerColor: playerColor,
                            size: avatarSize,
                            isCurrentTurn: isCurrentTurn,
                            isCurrentUser: isCurrentUser,
                          ),
                          
                          SizedBox(width: padding),
                          
                          // Name and score column with enhanced styling
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: padding * 2,
                                    vertical: padding,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCurrentTurn 
                                        ? AppColors.success.withOpacity(0.1)
                                        : (isCurrentUser 
                                            ? playerColor.withOpacity(0.1) 
                                            : Colors.transparent),
                                    borderRadius: BorderRadius.circular(padding * 2),
                                    border: isCurrentTurn || isCurrentUser
                                        ? Border.all(
                                            color: isCurrentTurn 
                                                ? AppColors.success.withOpacity(0.3)
                                                : playerColor.withOpacity(0.3),
                                            width: 1,
                                          )
                                        : null,
                                  ),
                                  child: Text(
                                    player.displayName,
                                    style: TextStyle(
                                      fontWeight: isCurrentTurn 
                                          ? FontWeight.bold 
                                          : (isCurrentUser ? FontWeight.w600 : FontWeight.w500),
                                      fontSize: fontSize,
                                      color: isCurrentTurn 
                                          ? AppColors.success 
                                          : (isCurrentUser ? playerColor : AppColors.textPrimary),
                                    ),
                                    overflow: TextOverflow.fade,
                                    maxLines: 2,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star,
                                      size: scoreFontSize * 0.9,
                                      color: AppColors.warning,
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      '$score',
                                      style: TextStyle(
                                        fontSize: scoreFontSize,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildGameBoard(double boardSize) {
    // New game board: Dice row + 6x6 word grid
    final padding = boardSize * 0.02; // Reduced padding
    final availableSize = boardSize - (padding * 2);
    
    final gameStateDiceValue = _currentGameState?.currentDiceValue;
    final int diceValue = gameStateDiceValue ?? 0; // 0 means no dice rolled yet
    
    return Container(
      width: boardSize,
      height: boardSize, // Fill entire space
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade50,
            AppColors.primary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(boardSize * 0.03),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 5,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 20,
            spreadRadius: -5,
            offset: Offset(-5, -5),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.8),
          width: 2,
        ),
      ),
      child: _buildNewGameGrid(availableSize, diceValue),
    );
  }

  Widget _buildNewGameGrid(double availableSize, int diceValue) {
    final gridContent = widget.gameSession.wordGrid ?? _getDefaultWordGrid();
    final rows = gridContent.length; // Should be 6
    final totalColumns = 6; // 6 word columns
    
    // Get current player info for coloring using consistent color system
    final currentPlayerInGame = widget.gameSession.players
        .where((p) => p.userId == widget.user.id)
        .firstOrNull;
    final playerColor = currentPlayerInGame != null 
        ? _getPlayerColor(currentPlayerInGame)
        : AppColors.primary;
    
    
    // Check if it's player's turn AND they have actually rolled the dice
    final hasRolledDice = _currentGameState?.lastDiceRoll != null;
    final highlightedColumn = (_isMyTurn && hasRolledDice && diceValue > 0) ? (diceValue - 1) : null; // Column to highlight (0-5 index)

    return Column(
      children: [
        // First row: Dice icons 1-6
        Expanded(
          child: Row(
            children: List.generate(6, (colIndex) {
              return Expanded(
                child: _buildDiceCell(colIndex + 1, availableSize / 6, false), // Dice never highlight
              );
            }),
          ),
        ),
        // Remaining rows: Word grid (perfectly aligned with dice above)
        ...List.generate(rows, (rowIndex) {
          return Expanded(
            child: Row(
              children: List.generate(6, (colIndex) {
                final word = gridContent[rowIndex][colIndex];
                final cellKey = '$rowIndex,$colIndex';
                
                // Check if this column should be highlighted (dice roll 1-6 maps to column 0-5)
                final isHighlightedColumn = highlightedColumn == colIndex;
                
                // Check cell states
                final cellOwner = _currentGameState?.getCellOwner(cellKey);
                final isOwned = cellOwner != null;
                final isOwnedByMe = cellOwner == widget.user.id;
                final hasPendingPronunciation = _currentGameState?.hasPendingPronunciation(cellKey) ?? false;
                
                // Note: All validation is now handled in _canSelectCell method
                // No need to duplicate checks here
                
                return Expanded(
                  child: _buildWordCell(
                    word: word,
                    cellKey: cellKey,
                    isHighlighted: isHighlightedColumn,
                    isOwned: isOwned,
                    isOwnedByMe: isOwnedByMe,
                    hasPending: hasPendingPronunciation,
                    playerColor: playerColor,
                    cellSize: availableSize / 6,
                    rowIndex: rowIndex,
                    colIndex: colIndex,
                  ),
                );
              }),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDiceCell(int number, double cellSize, bool isActive) {
    return Container(
      margin: EdgeInsets.all(1),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isActive ? [
                Colors.amber.shade200,
                Colors.amber.shade400,
              ] : [
                Colors.white,
                Colors.grey.shade200,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? Colors.amber.shade600 : Colors.grey.shade400,
              width: isActive ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: isActive ? Colors.amber.withOpacity(0.3) : Colors.black.withOpacity(0.1),
                blurRadius: isActive ? 8 : 4,
                spreadRadius: isActive ? 2 : 0,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: _buildSquareDice(number, cellSize * 0.65), // Even bigger square dice container
          ),
        ),
      ),
    );
  }

  Widget _buildSquareDice(int number, double diceSize) {
    final dotSize = diceSize * 0.15;
    final dotColor = AppColors.primary;
    
    Widget dot() => Container(
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(
        color: dotColor,
        shape: BoxShape.circle,
      ),
    );

    Widget empty() => SizedBox(width: dotSize, height: dotSize);

    Widget dicePattern;
    switch (number) {
      case 1:
        dicePattern = Center(child: dot());
        break;
      case 2:
        dicePattern = Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.start, children: [dot()]),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [dot()]),
          ],
        );
        break;
      case 3:
        dicePattern = Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.start, children: [dot()]),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [dot()]),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [dot()]),
          ],
        );
        break;
      case 4:
        dicePattern = Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [dot(), dot()]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [dot(), dot()]),
          ],
        );
        break;
      case 5:
        dicePattern = Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [dot(), dot()]),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [dot()]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [dot(), dot()]),
          ],
        );
        break;
      case 6:
        dicePattern = Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [dot(), dot()]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [dot(), dot()]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [dot(), dot()]),
          ],
        );
        break;
      default:
        dicePattern = Container();
    }

    // Return a square dice container with border like reference image
    return Container(
      width: diceSize,
      height: diceSize,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.primary, width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: EdgeInsets.all(diceSize * 0.1),
      child: dicePattern,
    );
  }

  Widget _buildDiceDots(int number, double diceSize) {
    final dotSize = diceSize * 0.18;
    // Use app theme's primary color for dice dots (consistent for all players)
    final dotColor = AppColors.primary;
    
    Widget dot() => Container(
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(
        color: dotColor,
        shape: BoxShape.circle,
      ),
    );

    switch (number) {
      case 1:
        return dot(); // Center dot
      case 2:
        return SizedBox(
          width: diceSize,
          height: diceSize,
          child: Stack(
            children: [
              Positioned(top: diceSize * 0.15, left: diceSize * 0.15, child: dot()),
              Positioned(bottom: diceSize * 0.15, right: diceSize * 0.15, child: dot()),
            ],
          ),
        );
      case 3:
        return SizedBox(
          width: diceSize,
          height: diceSize,
          child: Stack(
            children: [
              Positioned(top: diceSize * 0.15, left: diceSize * 0.15, child: dot()),
              Center(child: dot()),
              Positioned(bottom: diceSize * 0.15, right: diceSize * 0.15, child: dot()),
            ],
          ),
        );
      case 4:
        return SizedBox(
          width: diceSize,
          height: diceSize,
          child: Stack(
            children: [
              Positioned(top: diceSize * 0.15, left: diceSize * 0.15, child: dot()),
              Positioned(top: diceSize * 0.15, right: diceSize * 0.15, child: dot()),
              Positioned(bottom: diceSize * 0.15, left: diceSize * 0.15, child: dot()),
              Positioned(bottom: diceSize * 0.15, right: diceSize * 0.15, child: dot()),
            ],
          ),
        );
      case 5:
        return SizedBox(
          width: diceSize,
          height: diceSize,
          child: Stack(
            children: [
              Positioned(top: diceSize * 0.15, left: diceSize * 0.15, child: dot()),
              Positioned(top: diceSize * 0.15, right: diceSize * 0.15, child: dot()),
              Center(child: dot()),
              Positioned(bottom: diceSize * 0.15, left: diceSize * 0.15, child: dot()),
              Positioned(bottom: diceSize * 0.15, right: diceSize * 0.15, child: dot()),
            ],
          ),
        );
      case 6:
        return SizedBox(
          width: diceSize,
          height: diceSize,
          child: Stack(
            children: [
              Positioned(top: diceSize * 0.15, left: diceSize * 0.15, child: dot()),
              Positioned(top: diceSize * 0.15, right: diceSize * 0.15, child: dot()),
              Positioned(top: diceSize * 0.42, left: diceSize * 0.15, child: dot()),
              Positioned(top: diceSize * 0.42, right: diceSize * 0.15, child: dot()),
              Positioned(bottom: diceSize * 0.15, left: diceSize * 0.15, child: dot()),
              Positioned(bottom: diceSize * 0.15, right: diceSize * 0.15, child: dot()),
            ],
          ),
        );
      default:
        return Container();
    }
  }

  Widget _buildWordCell({
    required String word,
    required String cellKey,
    required bool isHighlighted,
    required bool isOwned,
    required bool isOwnedByMe,
    required bool hasPending,
    required Color playerColor,
    required double cellSize,
    required int rowIndex,
    required int colIndex,
  }) {
    // Check if this cell is contested (stolen/shared)
    final isContested = _currentGameState?.contestedCells.contains(cellKey) ?? false;
    
    Color backgroundColor;
    Color borderColor;
    Color textColor = Colors.black87;
    List<Color>? contestedColors;
    
    if (hasPending && isOwned && !isOwnedByMe) {
      // STEAL ATTEMPT - pending pronunciation on owned cell, show diagonal split immediately  
      contestedColors = _getStealAttemptColors(cellKey);
      backgroundColor = Colors.white; // Base color for contested cells
      borderColor = Colors.purple.shade600; // Purple border for steal attempt
      textColor = Colors.black87;
    } else if (hasPending) {
      // Pending pronunciation on unowned cell - yellow
      backgroundColor = Colors.yellow.shade200;
      borderColor = Colors.yellow.shade600;
    } else if (isContested) {
      // CONTESTED CELL - get both owner colors for diagonal split
      contestedColors = _getContestedColors(cellKey);
      backgroundColor = Colors.white; // Base color for contested cells
      borderColor = Colors.purple.shade600; // Purple border for contested
      textColor = Colors.black87;
    } else if (isOwnedByMe) {
      // Owned by current player - use player's color
      backgroundColor = playerColor;
      borderColor = playerColor;
      textColor = Colors.white;
    } else if (isOwned) {
      // Owned by other player - get their color
      final ownerColor = _getOwnerColor(cellKey);
      backgroundColor = ownerColor;
      borderColor = ownerColor;
      textColor = Colors.white;
    } else if (isHighlighted) {
      // Column highlighted - only show outline, keep white background
      backgroundColor = Colors.white;
      borderColor = playerColor;
    } else {
      // Default state - white/clickable appearance
      backgroundColor = Colors.white;
      borderColor = Colors.grey.shade400;
    }

    return Container(
      margin: EdgeInsets.all(1),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: GestureDetector(
          onTap: widget.isTeacherMode ? null : (_isProcessingSelection ? null : () {
            // Always call _selectCell and let it validate
            _selectCell(rowIndex, colIndex);
          }),
          onLongPress: () async {
            // Haptic feedback
            HapticFeedback.mediumImpact();
            // Pronounce the word
            await _flutterTts.speak(word);
          },
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              gradient: contestedColors != null && contestedColors.length >= 2
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [contestedColors[0], contestedColors[1]],
                      stops: const [0.49, 0.51], // Sharp diagonal split
                    )
                  : null,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: borderColor,
                width: isContested ? 3 : (isHighlighted ? 3 : 2),
              ),
              boxShadow: [
                BoxShadow(
                  color: isContested 
                    ? Colors.purple.withOpacity(0.4)
                    : (isHighlighted 
                      ? playerColor.withOpacity(0.3)
                      : Colors.black.withOpacity(0.1)),
                  blurRadius: isContested ? 6 : (isHighlighted ? 4 : 2),
                  offset: Offset(0, isContested ? 3 : (isHighlighted ? 2 : 1)),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Player name at top center for owned cells
                if (isOwned) 
                  Positioned(
                    top: 2,
                    left: 2,
                    right: 2,
                    child: Builder(
                      builder: (context) {
                        final cellOwner = _currentGameState?.getCellOwner(cellKey);
                        if (cellOwner == null) return Container();
                        
                        final gameSession = _currentGameSession ?? widget.gameSession;
                        final ownerPlayer = gameSession.players
                            .where((p) => p.userId == cellOwner)
                            .firstOrNull;
                        
                        if (ownerPlayer == null) return Container();
                        
                        return Text(
                          ownerPlayer.displayName,
                          style: TextStyle(
                            fontSize: cellSize * 0.12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white,
                            decorationThickness: 2.0,
                            decorationStyle: TextDecorationStyle.solid,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        );
                      },
                    ),
                  ),
                // Word text
                Center(
                  child: Text(
                    word,
                    style: TextStyle(
                      fontSize: 14, // Fixed size that will scale with container
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _darkenColor(Color color) {
    // Darken a color by 30% for better visibility
    return Color.fromRGBO(
      (color.red * 0.7).round(),
      (color.green * 0.7).round(),
      (color.blue * 0.7).round(),
      1,
    );
  }
  
  List<Color> _getContestedColors(String cellKey) {
    // Get colors of all players who own this contested cell
    final colors = <Color>[];
    final gameSession = _currentGameSession ?? widget.gameSession;
    
    if (_currentGameState != null) {
      for (final entry in _currentGameState!.playerCompletedCells.entries) {
        if (entry.value.contains(cellKey)) {
          // This player owns the cell
          final player = gameSession.players
              .where((p) => p.userId == entry.key)
              .firstOrNull;
          
          if (player != null) {
            colors.add(_getPlayerColor(player));
          }
        }
      }
    }
    
    // If we don't have 2 colors, add defaults
    while (colors.length < 2) {
      colors.add(Colors.grey);
    }
    
    return colors;
  }
  
  List<Color> _getStealAttemptColors(String cellKey) {
    final colors = <Color>[];
    final gameSession = _currentGameSession ?? widget.gameSession;
    
    // Get the current owner's color
    final cellOwner = _currentGameState?.getCellOwner(cellKey);
    if (cellOwner != null) {
      final ownerPlayer = gameSession.players
          .where((p) => p.userId == cellOwner)
          .firstOrNull;
      if (ownerPlayer != null) {
        colors.add(_getPlayerColor(ownerPlayer));
      }
    }
    
    // Get the challenger's color (person with pending pronunciation)
    final pendingPronunciation = _currentGameState?.getPendingPronunciation(cellKey);
    if (pendingPronunciation != null) {
      final challengerPlayer = gameSession.players
          .where((p) => p.userId == pendingPronunciation.playerId)
          .firstOrNull;
      if (challengerPlayer != null) {
        colors.add(_getPlayerColor(challengerPlayer));
      }
    }
    
    return colors;
  }
  
  Color _getOwnerColor(String cellKey) {
    // Get the color of the player who owns this cell
    final cellOwner = _currentGameState?.getCellOwner(cellKey);
    if (cellOwner == null) return Colors.grey;
    
    // Find the player in the game session
    final gameSession = _currentGameSession ?? widget.gameSession;
    final ownerPlayer = gameSession.players
        .where((p) => p.userId == cellOwner)
        .firstOrNull;
    
    if (ownerPlayer != null) {
      return _getPlayerColor(ownerPlayer);
    }
    
    // Fallback colors based on player index
    final playerIndex = gameSession.players.indexWhere((p) => p.userId == cellOwner);
    final fallbackColors = [
      Colors.red.shade600,
      Colors.blue.shade600,
      Colors.green.shade600,
      Colors.purple.shade600,
    ];
    return fallbackColors[playerIndex % fallbackColors.length];
  }

  Widget _buildBoardDiceRow(double boardSize, int diceValue) {
    return Container(
      height: boardSize * (_isMobile ? 0.15 : 0.18), // Smaller dice row on mobile for more word grid space
      padding: EdgeInsets.symmetric(horizontal: boardSize * 0.02),
      child: Row(
        children: List.generate(6, (index) {
          final size = boardSize * 0.12;
          return Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: boardSize * 0.005),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: (index + 1 == diceValue) 
                    ? [
                        AppColors.primary.withOpacity(0.3),
                        AppColors.primary.withOpacity(0.1),
                      ]
                    : [
                        Colors.white,
                        Colors.grey.shade200,
                      ],
                ),
                borderRadius: BorderRadius.circular(boardSize * 0.02),
                border: Border.all(
                  color: (index + 1 == diceValue) 
                    ? AppColors.primary
                    : Colors.grey.shade400,
                  width: (index + 1 == diceValue) ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (index + 1 == diceValue)
                      ? AppColors.primary.withOpacity(0.3)
                      : Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    spreadRadius: 1,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: _buildDiceDisplay(index + 1, size * 0.6),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDiceRow() {
    final screenWidth = MediaQuery.of(context).size.width;
    final gameStateDiceValue = _currentGameState?.currentDiceValue;
    final int diceValue = gameStateDiceValue ?? 0; // 0 means no dice rolled yet
    
    return Container(
      height: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(6, (index) {
                final size = screenWidth * 0.08; // Dice size proportional to screen width
                return Container(
                  width: size,
                  height: size,
                  margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.005),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: (index + 1 == diceValue) 
                          ? [
                              AppColors.primary.withOpacity(0.3),
                              AppColors.primary.withOpacity(0.1),
                            ]
                          : [
                              Colors.white,
                              Colors.grey.shade200,
                            ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (index + 1 == diceValue) 
                          ? AppColors.primary
                          : Colors.grey.shade400,
                        width: (index + 1 == diceValue) ? 3 : 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (index + 1 == diceValue)
                            ? AppColors.primary.withOpacity(0.3)
                            : Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          spreadRadius: 1,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _buildDiceDisplay(index + 1, size * 0.6),
                    ),
                  );
              }),
      ),
    );
  }
  
  List<List<String>> _getDefaultWordGrid() {
    return [
      ['CAT', 'DOG', 'SUN', 'HAT', 'BIG', 'RED'],
      ['RUN', 'FUN', 'TOP', 'BOX', 'COW', 'PIG'],
      ['BALL', 'BOOK', 'FISH', 'CAKE', 'JUMP', 'TREE'],
      ['BIRD', 'BOAT', 'RING', 'PARK', 'WAVE', 'MOON'],
      ['HAPPY', 'WATER', 'HOUSE', 'TRAIN', 'SMILE', 'LIGHT'],
      ['APPLE', 'MUSIC', 'DANCE', 'CLOUD', 'BEACH', 'PHONE'],
    ];
  }
  
  void _handleCellTap(String cellKey, String word) {
    // Parse row and column from cellKey
    final parts = cellKey.split(',');
    if (parts.length != 2) {
      return;
    }
    
    final row = int.tryParse(parts[0]);
    final col = int.tryParse(parts[1]);
    
    if (row == null || col == null) {
      return;
    }
    
    // ALL cell taps go through the centralized handler
    _selectCell(row, col);
  }
  
  Widget _buildWordGrid(double boardSize, double cellSize, int diceValue) {
    final gridContent = widget.gameSession.wordGrid ?? _getDefaultWordGrid();
    
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        childAspectRatio: 1,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: 36,
      itemBuilder: (context, index) {
        final row = index ~/ 6;
        final col = index % 6;
        final word = gridContent[row][col];
        final cellKey = '$row,$col';
        
        // Check if cell is completed by any player
        final completedByPlayerId = _currentGameState?.getCellOwner(cellKey);
        final isCompleted = completedByPlayerId != null;
        PlayerInGame? cellOwner;
        if (isCompleted && _currentGameSession?.players.isNotEmpty == true) {
          try {
            cellOwner = _currentGameSession!.players.firstWhere(
              (p) => p.userId == completedByPlayerId,
            );
          } catch (e) {
            // Player not found, use first player as fallback
            cellOwner = _currentGameSession!.players.first;
          }
        }
        
        // Cell color based on owner
        Color? cellColor;
        if (isCompleted && cellOwner != null) {
          cellColor = _getPlayerColor(cellOwner).withOpacity(0.3);
        }
        
        // Column color for dice match - vibrant rainbow colors
        final columnColors = [
          Colors.red.shade200,
          Colors.orange.shade200,
          Colors.green.shade200,
          Colors.blue.shade200,
          Colors.purple.shade200,
          Colors.pink.shade200,
        ];
        
        final bool isDiceColumn = (col + 1) == diceValue;
        
        return GestureDetector(
          onTap: (widget.isTeacherMode || _isProcessingSelection) ? null : () => _handleCellTap(cellKey, word),
          child: Container(
            decoration: BoxDecoration(
              color: columnColors[col].withOpacity(0.4),
              borderRadius: BorderRadius.circular(cellSize * 0.15),
              border: Border.all(
                color: cellColor != null
                  ? _getPlayerColor(cellOwner!)
                  : (isDiceColumn 
                    ? AppColors.primary.withOpacity(0.5)
                    : Colors.grey.shade300),
                width: cellColor != null ? 3 : (isDiceColumn ? 2 : 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Player name at top center for owned cells (only show in multiplayer games)
                if (isCompleted && cellOwner != null && (_currentGameSession?.players.length ?? 0) > 1) 
                  Positioned(
                    top: 2,
                    left: 2,
                    right: 2,
                    child: Text(
                      cellOwner.displayName,
                      style: TextStyle(
                        fontSize: cellSize * 0.12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white,
                        decorationThickness: 2.0,
                        decorationStyle: TextDecorationStyle.solid,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                // Word text centered
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      word,
                      style: TextStyle(
                        fontSize: math.max(cellSize * 0.35, _isMobile ? 14.0 : 12.0),
                        fontWeight: isCompleted ? FontWeight.bold : FontWeight.w600,
                        color: isCompleted ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildDiceDisplay(int value, double size) {
    // Simple dice representation with dots
    final dotSize = size * 0.22; // Back to original dot size
    final positions = _getDiceDotsPositions(value);
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.grey.shade400,
          width: 1,
        ),
      ),
      child: Stack(
        children: positions.map((pos) {
          return Positioned(
            left: pos['x']! * size - dotSize / 2,
            top: pos['y']! * size - dotSize / 2,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
  
  List<Map<String, double>> _getDiceDotsPositions(int value) {
    switch (value) {
      case 1:
        return [{'x': 0.5, 'y': 0.5}];
      case 2:
        return [
          {'x': 0.3, 'y': 0.3},
          {'x': 0.7, 'y': 0.7},
        ];
      case 3:
        return [
          {'x': 0.25, 'y': 0.25},
          {'x': 0.5, 'y': 0.5},
          {'x': 0.75, 'y': 0.75},
        ];
      case 4:
        return [
          {'x': 0.3, 'y': 0.3},
          {'x': 0.7, 'y': 0.3},
          {'x': 0.3, 'y': 0.7},
          {'x': 0.7, 'y': 0.7},
        ];
      case 5:
        return [
          {'x': 0.3, 'y': 0.3},
          {'x': 0.7, 'y': 0.3},
          {'x': 0.5, 'y': 0.5},
          {'x': 0.3, 'y': 0.7},
          {'x': 0.7, 'y': 0.7},
        ];
      case 6:
        return [
          {'x': 0.3, 'y': 0.25},
          {'x': 0.7, 'y': 0.25},
          {'x': 0.3, 'y': 0.5},
          {'x': 0.7, 'y': 0.5},
          {'x': 0.3, 'y': 0.75},
          {'x': 0.7, 'y': 0.75},
        ];
      default:
        return [];
    }
  }

  Widget _buildCell(String cellKey, String word, int row, int col, double cellSize, int diceValue) {
    List<Color> gradientColors = [Colors.white, Colors.grey.shade100];
    Color borderColor = Colors.grey.shade400;
    double borderWidth = 1.5;
    double elevation = 4;
    bool isHighlighted = false;
    bool isOwned = false;
    
    // Check if cell is owned by someone
    final owner = _currentGameState?.getCellOwner(cellKey);
    if (owner != null) {
      final gameSession = _currentGameSession ?? widget.gameSession;
      final ownerPlayer = gameSession.players.firstWhere(
        (p) => p.userId == owner,
        orElse: () => gameSession.players.first,
      );
      final playerColor = _getPlayerColor(ownerPlayer);
      gradientColors = [
        playerColor.withOpacity(0.9),
        playerColor.withOpacity(0.6),
      ];
      borderColor = playerColor;
      borderWidth = 2.5;
      elevation = 8;
      isOwned = true;
    }
    
    // Check if there's a pending pronunciation
    else if (_currentGameState?.hasPendingPronunciation(cellKey) == true) {
      gradientColors = [
        AppColors.warning.withOpacity(0.4),
        AppColors.warning.withOpacity(0.2),
      ];
      borderColor = AppColors.warning;
      borderWidth = 2;
      elevation = 6;
    }
    
    // Highlight valid column for current player
    else if (!widget.isTeacherMode && 
             _currentGameState?.currentTurnPlayerId == widget.user.id &&
             col + 1 == diceValue) {
      gradientColors = [
        AppColors.success.withOpacity(0.3),
        AppColors.success.withOpacity(0.15),
      ];
      borderColor = AppColors.success;
      borderWidth = 2.5;
      elevation = 6;
      isHighlighted = true;
    }
    // Default colorful cells based on position
    else {
      // Create a rainbow effect across the board
      final hue = (col * 60.0 + row * 10.0) % 360;
      final baseColor = HSLColor.fromAHSL(1.0, hue, 0.7, 0.95).toColor();
      gradientColors = [
        baseColor,
        baseColor.withOpacity(0.7),
      ];
      borderColor = HSLColor.fromAHSL(1.0, hue, 0.6, 0.8).toColor();
    }
    
    // Determine text color based on background
    Color textColor = AppColors.textPrimary;
    if (isOwned) {
      textColor = Colors.white;
      elevation = 10; // Higher elevation for owned cells
    } else if (isHighlighted) {
      textColor = AppColors.textPrimary.withOpacity(0.9);
    }
    
    return GestureDetector(
      onTap: (widget.isTeacherMode || _isProcessingSelection) ? null : () {
        if (_currentGameState != null) {
        }
        HapticFeedback.lightImpact(); // Immediate feedback
        _selectCell(row, col);
      },
      onLongPress: () async {
        // Haptic feedback
        HapticFeedback.mediumImpact();
        // Pronounce the word
        await _flutterTts.speak(word);
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: borderColor.withOpacity(0.3),
              blurRadius: elevation,
              spreadRadius: elevation / 4,
              offset: Offset(0, elevation / 2),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.8),
              blurRadius: elevation / 2,
              spreadRadius: -elevation / 4,
              offset: Offset(-2, -2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Shine effect overlay
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: cellSize * 0.3,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.3),
                      Colors.white.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Main text
            Center(
              child: Text(
                word,
                style: TextStyle(
                  fontSize: cellSize * 0.22,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.2),
                      offset: Offset(1, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    final gameStateDiceValue = _currentGameState?.currentDiceValue;
    final int diceValue = gameStateDiceValue ?? 0; // 0 means no dice rolled yet
    
    if (widget.isTeacherMode) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SizedBox(
            width: 200,
            child: ElevatedButton.icon(
              onPressed: _endGame,
              icon: const Icon(Icons.stop, size: 18),
              label: const Text('End Game'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gamePrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),
        ),
      );
    } else {
      return _buildStudentControls(diceValue, _isMyTurn);
    }
  }

  Widget _buildStudentControls(int diceValue, bool _isMyTurn) {
    // No controls needed for students since quit button is in app bar
    return Container();
  }

  Future<void> _endGame() async {
    if (_currentGameState == null || _currentGameSession == null) return;
    
    // Check if game has a winner (completed)
    final winnerId = _currentGameState!.checkForWinner();
    final hasWinner = winnerId != null;
    
    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Game'),
        content: Text(
          hasWinner 
            ? 'End this completed game? Player stats will be updated.'
            : 'End this game early? No stats will be updated.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('End Game'),
          ),
        ],
      ),
    );

    if (shouldEnd == true && context.mounted) {
      try {
        final gameSession = _currentGameSession!;
        
        if (hasWinner) {
          // Game completed with winner - update stats
          for (final player in gameSession.players) {
            final wordsRead = _currentGameState!.getPlayerScore(player.userId);
            final isWinner = player.userId == winnerId;
            await FirestoreService.updateStudentStats(
              studentId: player.userId,
              wordsRead: wordsRead,
              won: isWinner,
            );
          }
          
          // End game session with winner
          await GameSessionService.endGameSession(
            gameId: gameSession.gameId,
            winnerId: winnerId,
          );
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Game completed! ${_getPlayerName(winnerId)} wins. Stats updated.'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          // Game ended early - no stats update
          await GameSessionService.endGameSession(
            gameId: gameSession.gameId,
            winnerId: null,
          );
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Game ended early. No stats updated.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
        
        // Return to admin dashboard
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error ending game: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }


  Widget _buildTeacherControls() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use same proportional sizing as student controls
        final buttonWidth = constraints.maxWidth * 0.25;
        final buttonHeight = constraints.maxHeight * 0.4;
        
        return Center(
          child: SizedBox(
            width: buttonWidth,
            height: buttonHeight,
            child: ElevatedButton(
              onPressed: _handleGameEnd,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: AppColors.error.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: buttonWidth * 0.1,
                  vertical: buttonHeight * 0.15,
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.stop,
                      size: buttonHeight * 0.3,
                    ),
                    SizedBox(width: buttonWidth * 0.05),
                    Text(
                      'End Game',
                      style: TextStyle(
                        fontSize: buttonHeight * 0.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showGameDeletedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Can't dismiss by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: AppColors.warning, size: 28),
              const SizedBox(width: 12),
              const Text('Game Ended'),
            ],
          ),
          content: const Text(
            'The teacher has ended this game. You will be returned to the home page.',
            style: TextStyle(fontSize: 16),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  if (!mounted) return;
                  final navigator = Navigator.of(context);
                  navigator.pop(); // Close dialog
                  if (mounted) {
                    navigator.popUntil((route) => route.isFirst); // Go to home
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text('OK'),
              ),
            ),
          ],
        );
      },
    );
  }
  
  void _showTeacherCantRollMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Teachers cannot roll dice - you monitor the game!'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.blue,
      ),
    );
  }
  
  void _showNotYourTurnMessage() {
    final currentPlayerName = _currentGameState != null 
        ? widget.gameSession.players
            .firstWhere((p) => p.userId == _currentGameState!.currentTurnPlayerId, 
                       orElse: () => PlayerInGame(
                         userId: '',
                         displayName: 'Unknown',
                         emailAddress: '',
                         joinedAt: DateTime.now(),
                         wordsRead: 0,
                       ))
            .displayName
        : 'Someone else';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Wait for your turn! It\'s $currentPlayerName\'s turn.'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.orange,
      ),
    );
  }
  
  void _showDiceAlreadyRollingMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dice is already rolling!'),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.grey,
      ),
    );
  }

  void _showPendingPronunciationMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Wait for teacher to approve or reject your word before rolling again!'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showAlreadyRolledMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You have already rolled the dice this turn! Select a word or wait for next turn.'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showWaitingForPlayersMessage() {
    final currentPlayers = _currentGameSession?.players.length ?? 0;
    final maxPlayers = _currentGameSession?.maxPlayers ?? 2;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Waiting for more players to join ($currentPlayers/$maxPlayers). Game will start when ready!',
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: AppColors.mediumBlue,
      ),
    );
  }

  Widget _buildOwnerIndicator(String cellKey, double cellSize) {
    final cellOwner = _currentGameState?.getCellOwner(cellKey);
    if (cellOwner == null) return Container();
    
    // Find the player in the game session
    final gameSession = _currentGameSession ?? widget.gameSession;
    final ownerPlayer = gameSession.players
        .where((p) => p.userId == cellOwner)
        .firstOrNull;
    
    if (ownerPlayer == null) return Container();
    
    return Container(
      width: cellSize * 0.28,
      height: cellSize * 0.28,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: _getPlayerColor(ownerPlayer),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          ownerPlayer.displayName.substring(0, 1).toUpperCase(),
          style: TextStyle(
            fontSize: cellSize * 0.18, // Larger for better visibility
            fontWeight: FontWeight.w900,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.7),
                offset: const Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTurnIndicator(double safeHeight) {
    if (_currentGameState == null) {
      return const SizedBox.shrink();
    }
    
    // Check if game is over
    final winnerId = _currentGameState!.checkForWinner();
    if (_gameEnded || winnerId != null) {
      // Game is over - show winner banner
      final winnerPlayer = widget.gameSession.players
          .where((p) => p.userId == winnerId)
          .firstOrNull;
      
      if (winnerPlayer == null) return const SizedBox.shrink();
      
      final winnerColor = _getPlayerColor(winnerPlayer);
      
      return Container(
        height: safeHeight * 0.05,
        width: double.infinity,
        decoration: BoxDecoration(
          color: winnerColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: winnerColor, width: 2),
        ),
        child: Center(
          child: Text(
            "🎉 Game Over - ${winnerPlayer.displayName} Wins! 🎉",
            style: TextStyle(
              color: winnerColor,
              fontSize: safeHeight * 0.025,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
    
    // Game still in progress - show current turn
    if (_currentGameState!.currentTurnPlayerId == null) {
      return const SizedBox.shrink();
    }
    
    final sessionPlayer = widget.gameSession.players
        .where((p) => p.userId == _currentGameState!.currentTurnPlayerId)
        .firstOrNull;
    
    if (sessionPlayer == null) return const SizedBox.shrink();
    
    // Get consistent player color using the same logic as owned squares
    final playerColor = _getPlayerColor(sessionPlayer);
    
    // SIMPLE turn indicator - just the name
    return Container(
      height: safeHeight * 0.05, // Normal size
      width: double.infinity,
      decoration: BoxDecoration(
        color: playerColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: playerColor, width: 2),
      ),
      child: Center(
        child: Text(
          "${sessionPlayer.displayName}'s Turn",
          style: TextStyle(
            color: playerColor,
            fontSize: safeHeight * 0.025,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}