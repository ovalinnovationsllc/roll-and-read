import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:flutter_tts/flutter_tts.dart';
import '../config/app_colors.dart';
import '../widgets/animated_dice.dart';
import '../models/user_model.dart';
import '../models/game_session_model.dart';
import '../services/game_state_service.dart';
import '../services/game_session_service.dart';
import '../services/firestore_service.dart';
import '../models/game_state_model.dart';
import '../models/student_model.dart';
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
    final isCurrentPlayer = winnerId == widget.user.id;
    
    // Show the winning celebration overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WinningCelebration(
        winnerName: winnerName,
        isCurrentPlayer: isCurrentPlayer,
        onComplete: () {
          Navigator.of(context).pop(); // Close the celebration
          // Teacher will handle game completion - no dialog needed
        },
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
      
      print('📊 Saving student game results for ${currentUser.displayName}:');
      print('  - Student ID: ${currentUser.id}');
      print('  - Games played: +1');
      print('  - Games won: ${isWinner ? '+1' : '0'}'); 
      print('  - Words read: +$wordsRead');
      
      // Update student stats using the StudentModel approach
      await FirestoreService.updateStudentStats(
        studentId: currentUser.id,
        wordsRead: wordsRead,
        won: isWinner,
      );
      
      print('✅ Student game results saved successfully!');
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Results saved! Games played +1, Words read +$wordsRead${isWinner ? ', Games won +1' : ''}'),
          backgroundColor: AppColors.success,
        ),
      );
      
    } catch (e) {
      print('❌ Error saving student game results: $e');
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
      print('Using AI-generated word grid from game session');
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
      print('Using default word grid');
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
      print('Error initializing game state: $e');
    }
  }

  void _initializeGameSession() {
    try {
      _gameSessionStream = GameSessionService.getGameSessionStream(widget.gameSession.gameId);
      _currentGameSession = widget.gameSession;
    } catch (e) {
      print('Error initializing game session stream: $e');
    }
  }

  Future<void> _rollDice() async {
    if (_isRolling) return;
    
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
    print('🎲 New dice rolled: $diceValue - Fresh turn, can make ONE selection');
  }

  // Helper methods to avoid duplicate calculations
  bool get _isMyTurn => _currentGameState?.currentTurnPlayerId == widget.user.id ?? false;
  bool get _playerHasPendingPronunciation => _currentGameState?.pendingPronunciations.values
      .any((attempt) => attempt.playerId == widget.user.id) ?? false;
  
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
      if (showDebugLogs) print('❌ Cannot select: Already processing another selection');
      return false;
    }
    
    if (_currentGameState == null) {
      if (showDebugLogs) print('❌ Cannot select: Game state is null');
      return false;
    }
    
    // Check if it's player's turn
    if (!_isMyTurn) {
      if (showDebugLogs) print('❌ Cannot select: Not your turn');
      return false;
    }
    
    // Check if dice has been rolled
    final diceValue = _currentGameState!.currentDiceValue;
    if (showDebugLogs) {
      print('🎲 DEBUG: Dice validation check:');
      print('  gameState.currentDiceValue: $diceValue');
      print('  local _currentDiceRoll: $_currentDiceRoll');
      print('  player trying to select: ${widget.user.id}');
      print('  currentTurnPlayerId: ${_currentGameState!.currentTurnPlayerId}');
    }
    
    if (diceValue == null) {
      if (showDebugLogs) print('❌ Cannot select: No dice rolled yet! Roll dice first.');
      return false;
    }
    
    // Check if valid column for dice roll
    final validColumn = col + 1 == diceValue;
    if (!validColumn) {
      if (showDebugLogs) print('❌ Cannot select: Wrong column! Dice: $diceValue, Selected: ${col + 1}');
      return false;
    }
    
    // Check if cell is already owned BY THE CURRENT PLAYER (stealing is allowed from others)
    final cellOwner = _currentGameState!.getCellOwner(cellKey);
    if (cellOwner == widget.user.id) {
      if (showDebugLogs) print('❌ Cannot select: You already own this cell');
      return false;
    } else if (cellOwner != null) {
      // Cell is owned by another player - stealing is allowed!
      if (showDebugLogs) print('⚔️ STEAL ATTEMPT: Trying to steal cell from $cellOwner');
    }
    
    // Check if there's already a pending pronunciation for this cell
    final hasPendingPronunciation = _currentGameState!.hasPendingPronunciation(cellKey);
    if (hasPendingPronunciation) {
      if (showDebugLogs) print('❌ Cannot select: Cell already has a pending pronunciation');
      return false;
    }
    
    // CRITICAL: Check if player already made a selection this dice roll
    if (_hasSelectedThisTurn) {
      if (showDebugLogs) print('❌ BLOCKED: You already selected a square for dice roll $_currentDiceRoll');
      return false;
    }
    
    // SECONDARY: Check if player has ANY pending pronunciations (prevents multiple selections)
    if (_playerHasPendingPronunciation) {
      if (showDebugLogs) {
        print('❌ BLOCKED: You have pending pronunciations - wait for teacher response');
        final pendingAttempts = _currentGameState!.pendingPronunciations.values
            .where((attempt) => attempt.playerId == widget.user.id)
            .map((a) => '${a.cellKey}:${a.word}')
            .toList();
        print('  Your pending pronunciations: $pendingAttempts');
      }
      return false;
    }
    
    if (showDebugLogs) print('✅ Cell selection allowed for $cellKey');
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
    
    print('🎯 CELL TAP ATTEMPT: $cellKey:$word at ${DateTime.now()}');
    
    // IMMEDIATE: Check if we're already processing a selection
    if (_isProcessingSelection) {
      print('❌ BLOCKED: Already processing a selection (flag is true)');
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
        print('❌ BLOCKED: Too soon since last selection (${timeSinceLastSelection.inMilliseconds}ms < 1000ms)');
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
      print('❌ BLOCKED: Same cell already selected: $cellKey');
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
      print('❌ BLOCKED: Double-check found pending pronunciation!');
      final pending = _currentGameState!.pendingPronunciations.values
          .where((attempt) => attempt.playerId == widget.user.id)
          .map((a) => '${a.cellKey}:${a.word}')
          .toList();
      print('  Pending: $pending');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wait for teacher to approve or reject your current word!'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    print('✅ ALL CHECKS PASSED: Processing cell selection for $cellKey:$word');
    
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
      
      print('✅ Pronunciation attempt created successfully for $cellKey');
      
      // Keep the processing flag true for longer to ensure Firebase updates
      await Future.delayed(const Duration(seconds: 2));
      
    } catch (e) {
      print('❌ Error creating pronunciation attempt: $e');
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
    print('✅ Pronunciation approved - but player cannot select more squares this turn');
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
    print('❌ Pronunciation rejected - but player cannot select more squares this turn');
  }
  
  void _resetSelectionState() {
    if (mounted) {
      setState(() {
        _isProcessingSelection = false;
        _lastSelectedCell = null;
        _lastSelectionTime = null;
        _hasSelectedThisTurn = false; // Reset turn-based blocking
      });
      print('🔄 Selection state reset - ready for next turn');
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

  @override
  Widget build(BuildContext context) {
    final gameCode = widget.gameSession.gameId.length >= 6 
        ? widget.gameSession.gameId.substring(0, 6).toUpperCase() 
        : widget.gameSession.gameId.toUpperCase();
    
    // Check for winner and show celebration
    final winnerId = _currentGameState?.checkForWinner();
    if (winnerId != null && !_gameEnded) {
      print('🏆 WINNER DETECTED: $winnerId (${_getPlayerName(winnerId)}) - showing celebration!');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showWinnerDialog(winnerId);
      });
    }
    
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
          'Roll & Read',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: _showQuitDialog,
            tooltip: 'Quit Game',
          ),
        ],
        centerTitle: true,
        elevation: 2,
      ),
      body: StreamBuilder<GameSessionModel?>(
        stream: _gameSessionStream,
        builder: (context, gameSessionSnapshot) {
          // Debug teacher view updates
          if (widget.isTeacherMode) {
            print('🎯 CleanMultiplayerScreen (Teacher) Stream Update:');
            print('  connectionState: ${gameSessionSnapshot.connectionState}');
            print('  hasData: ${gameSessionSnapshot.hasData}');
            if (gameSessionSnapshot.hasData && gameSessionSnapshot.data != null) {
              print('  players: ${gameSessionSnapshot.data!.players.length}/${gameSessionSnapshot.data!.maxPlayers}');
              print('  player details: ${gameSessionSnapshot.data!.players.map((p) => '${p.displayName}(${p.userId})').toList()}');
            }
          }
          
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
                  print('🔄 TURN CHANGE DETECTED: $previousTurnPlayer -> $currentTurnPlayer');
                  
                  // If it's now my turn and I'm not in teacher mode, reset selection state and dice
                  if (currentTurnPlayer == widget.user.id && !widget.isTeacherMode) {
                    print('🎯 My turn started! Resetting selection state and dice');
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
        // Use consistent proportions for all screen sizes  
        final padding = screenWidth * 0.02; // 2% of screen width for padding
        
        // Calculate available space
        final safeHeight = screenHeight - padding * 2;
        final safeWidth = screenWidth - padding * 2;
        
        // Better space distribution with more spacing
        final headerHeight = safeHeight * 0.10;  // 10% for player cards
        final diceHeight = safeHeight * 0.08;    // 8% for clickable dice
        final controlsHeight = widget.isTeacherMode ? safeHeight * 0.12 : safeHeight * 0.02; // Minimal for students
        final boardAreaHeight = safeHeight * 0.80; // 80% for game board
        
        // Make board square, scaled to fit available space (smaller for proper gradient coverage)
        final maxBoardSize = math.min(safeWidth * 0.85, boardAreaHeight * 0.85);
        final boardSize = maxBoardSize;
        
        return SizedBox(
          height: constraints.maxHeight,
          width: constraints.maxWidth,
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Header with player cards
                    SizedBox(
                      height: headerHeight,
                      child: _buildPlayerCards(),
                    ),
                    
                    // Spacing
                    SizedBox(height: safeHeight * 0.01),
                    
                    // Clickable dice - between player cards and board
                    SizedBox(
                      height: diceHeight,
                      child: Center(
                        child: _buildCenteredDice(),
                      ),
                    ),
                    
                    // Spacing
                    SizedBox(height: safeHeight * 0.01),
                    
                    // Game board with overlay - maximum space
                    Expanded(
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
                
                // Spacing
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
        
        // Proportional sizing
        final diceSize = constraints.maxHeight * 0.7;
        final fontSize = constraints.maxHeight * 0.25;
        
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
              // Dice
              GestureDetector(
                onTap: widget.isTeacherMode 
                    ? () => _showTeacherCantRollMessage()
                    : (!_isMyTurn 
                        ? () => _showNotYourTurnMessage()
                        : (_isRolling 
                            ? () => _showDiceAlreadyRollingMessage()
                            : _rollDice)),
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
                  : (_isMyTurn 
                    ? (_isRolling ? 'Rolling...' : 'Tap to roll!')
                    : 'Waiting for turn...'),
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: widget.isTeacherMode 
                    ? AppColors.primary 
                    : (_isMyTurn ? AppColors.success : AppColors.textSecondary),
                ),
              ),
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
                  // For current user, prioritize their actual user color to ensure consistency
                  Color playerColor;
                  
                  // TEMPORARY DEBUG FIX: If this is Ian, force blue color
                  if (isCurrentUser && (player.displayName.toLowerCase() == 'ian' || widget.user.displayName.toLowerCase() == 'ian')) {
                    playerColor = Colors.blue;
                    print('🔧 TEMP FIX: Forcing Ian to blue color');
                  } else if (isCurrentUser && widget.user.playerColor != null) {
                    // Always use the user's actual color for the current user
                    playerColor = widget.user.playerColor!;
                  } else if (player.playerColor != null) {
                    // Use game session color for other players
                    playerColor = Color(player.playerColor!);
                  } else {
                    // Final fallback
                    playerColor = AppColors.gamePrimary;
                  }
                  
                  // Debug player color info
                  if (player.userId == widget.user.id) {
                    print('DEBUG: Player widget color for ${player.displayName} (userId: ${player.userId}):');
                    print('  FROM GAME SESSION player.playerColor: ${player.playerColor}');
                    if (player.playerColor != null) {
                      print('  Game session color as Color: ${Color(player.playerColor!)} (${Color(player.playerColor!).value})');
                    }
                    print('  FROM USER OBJECT widget.user.playerColor: ${widget.user.playerColor}');
                    print('  widget.user.playerColor?.value: ${widget.user.playerColor?.value}');
                    print('  isCurrentUser: ${isCurrentUser}');
                    print('  Final playerColor chosen: $playerColor (value: ${playerColor.value})');
                    print('  Expected color should be: Blue (${Colors.blue.value}) if Ian chose blue');
                    print('  Color selection logic:');
                    if (isCurrentUser && widget.user.playerColor != null) {
                      print('    ✅ Using current user color (priority): ${widget.user.playerColor?.value}');
                    } else if (player.playerColor != null) {
                      print('    - Using game session color: ${player.playerColor}');
                    } else {
                      print('    - Using fallback AppColors.gamePrimary: ${AppColors.gamePrimary.value}');
                    }
                  }
                  
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
                          // Avatar
                          Container(
                            width: avatarSize,
                            height: avatarSize,
                            decoration: BoxDecoration(
                              color: playerColor.withOpacity(0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isCurrentTurn ? AppColors.success : playerColor,
                                width: isCurrentTurn ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                player.avatarUrl ?? player.displayName.substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  fontSize: avatarSize * 0.5,
                                  fontWeight: FontWeight.bold,
                                  color: playerColor,
                                ),
                              ),
                            ),
                          ),
                          
                          SizedBox(width: padding),
                          
                          // Name and score column
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  player.displayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: fontSize,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.fade,
                                  maxLines: 2,
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
    
    // Get current player info for coloring
    final currentPlayer = widget.user;
    final playerColor = currentPlayer.playerColor ?? AppColors.primary;
    final darkerPlayerColor = Color.fromRGBO(
      (playerColor.red * 0.7).round(),
      (playerColor.green * 0.7).round(), 
      (playerColor.blue * 0.7).round(),
      1.0,
    );
    
    print('DEBUG: Player color info:');
    print('  User: ${currentPlayer.displayName}');
    print('  Raw playerColor: ${currentPlayer.playerColor}');
    print('  Computed playerColor: $playerColor');
    print('  Darker playerColor: $darkerPlayerColor');
    
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
                    darkerPlayerColor: darkerPlayerColor,
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
            child: _buildDiceDots(number, cellSize * 0.5), // Reduced size for AspectRatio
          ),
        ),
      ),
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
    required Color darkerPlayerColor,
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
      print('🏴‍☠️ STEAL VISUALIZATION: Showing diagonal split for cell $cellKey');
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
      // Owned by current player - use player's darker color
      backgroundColor = darkerPlayerColor;
      borderColor = darkerPlayerColor;
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
            child: Center(
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
          
          if (player?.playerColor != null) {
            final color = Color(player!.playerColor!);
            // Make colors darker for better visibility
            colors.add(_darkenColor(color));
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
        colors.add(Color(ownerPlayer.playerColor ?? Colors.blue.value));
      }
    }
    
    // Get the challenger's color (person with pending pronunciation)
    final pendingPronunciation = _currentGameState?.getPendingPronunciation(cellKey);
    if (pendingPronunciation != null) {
      final challengerPlayer = gameSession.players
          .where((p) => p.userId == pendingPronunciation.playerId)
          .firstOrNull;
      if (challengerPlayer != null) {
        colors.add(Color(challengerPlayer.playerColor ?? Colors.red.value));
      }
    }
    
    print('🎨 STEAL COLORS for $cellKey: Owner vs Challenger = ${colors.length} colors');
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
    
    if (ownerPlayer?.playerColor != null) {
      final ownerColor = Color(ownerPlayer!.playerColor!);
      // Return darker version
      return Color.fromRGBO(
        (ownerColor.red * 0.7).round(),
        (ownerColor.green * 0.7).round(), 
        (ownerColor.blue * 0.7).round(),
        1.0,
      );
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
      height: boardSize * 0.18, // 18% of board height (increased from 12%)
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
      print('❌ Invalid cell key format: $cellKey');
      return;
    }
    
    final row = int.tryParse(parts[0]);
    final col = int.tryParse(parts[1]);
    
    if (row == null || col == null) {
      print('❌ Invalid row/col in cell key: $cellKey');
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
        if (isCompleted && cellOwner != null && cellOwner.playerColor != null) {
          cellColor = Color(cellOwner.playerColor!).withOpacity(0.3);
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
                  ? Color(cellOwner!.playerColor!)
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
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  word,
                  style: TextStyle(
                    fontSize: cellSize * 0.35,
                    fontWeight: isCompleted ? FontWeight.bold : FontWeight.w600,
                    color: isCompleted ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
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
      final playerColor = Color(ownerPlayer.playerColor ?? AppColors.gamePrimary.value);
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
      print('DEBUG: Cell $cellKey has pending pronunciation - showing warning color');
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
        print('DEBUG: Cell tapped! Row: $row, Col: $col');
        print('DEBUG: Teacher mode: ${widget.isTeacherMode}');
        print('DEBUG: Game state available: ${_currentGameState != null}');
        if (_currentGameState != null) {
          print('DEBUG: Current turn player: ${_currentGameState!.currentTurnPlayerId}');
          print('DEBUG: Current dice value: ${_currentGameState!.currentDiceValue}');
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
      return _buildTeacherControls();
    } else {
      return _buildStudentControls(diceValue, _isMyTurn);
    }
  }

  Widget _buildStudentControls(int diceValue, bool _isMyTurn) {
    // No controls needed for students since quit button is in app bar
    return Container();
  }

  void _showQuitDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Quit Game?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to quit? Your progress will not be saved.',
            style: TextStyle(fontSize: 16),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog
                
                // If student is leaving, remove them from the game
                if (!widget.isTeacherMode && _currentGameSession != null) {
                  try {
                    print('👋 STUDENT LEAVING: Removing ${widget.user.displayName} from game ${_currentGameSession!.gameId}');
                    await GameSessionService.leaveGameSession(
                      gameId: _currentGameSession!.gameId,
                      playerId: widget.user.id,
                    );
                    print('✅ STUDENT LEFT: Successfully removed from game');
                  } catch (e) {
                    print('❌ Error leaving game: $e');
                    // Don't block the navigation if leave fails
                  }
                }
                
                // Navigate to home screen
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Quit Game',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
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
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).popUntil((route) => route.isFirst); // Go to home
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
}