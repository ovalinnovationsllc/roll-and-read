import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter_tts/flutter_tts.dart';
import '../config/app_colors.dart';
import '../widgets/animated_dice.dart';
import '../models/user_model.dart';
import '../models/game_session_model.dart';
import '../services/game_session_service.dart';
import '../services/game_state_service.dart';
import '../models/game_state_model.dart';

class DiagonalSplitPainter extends CustomPainter {
  final Color color1;
  final Color color2;

  DiagonalSplitPainter({
    required this.color1,
    required this.color2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()..color = color1;
    final paint2 = Paint()..color = color2;

    // Create path for top-left triangle (color1)
    final path1 = Path();
    path1.moveTo(0, 0); // Top-left corner
    path1.lineTo(size.width, 0); // Top-right corner
    path1.lineTo(0, size.height); // Bottom-left corner
    path1.close();

    // Create path for bottom-right triangle (color2)
    final path2 = Path();
    path2.moveTo(size.width, 0); // Top-right corner
    path2.lineTo(size.width, size.height); // Bottom-right corner
    path2.lineTo(0, size.height); // Bottom-left corner
    path2.close();

    // Paint the triangles
    canvas.drawPath(path1, paint1);
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class MultiplayerRollAndRead extends StatefulWidget {
  final UserModel user;
  final GameSessionModel gameSession;
  final bool isTeacherMode;
  
  const MultiplayerRollAndRead({
    super.key,
    required this.user,
    required this.gameSession,
    this.isTeacherMode = false,
  });

  @override
  State<MultiplayerRollAndRead> createState() => _MultiplayerRollAndReadState();
}

class _MultiplayerRollAndReadState extends State<MultiplayerRollAndRead> {
  final Random _random = Random();
  late FlutterTts _flutterTts;
  
  // Firebase synchronized state
  Stream<GameStateModel?>? _gameStateStream;
  GameStateModel? _currentGameState;
  
  // Local UI state
  bool _isRolling = false;
  
  // Grid content - 6 columns (for dice 1-6) x 6 rows
  late List<List<String>> gridContent;

  @override
  void initState() {
    super.initState();
    _initializeGrid();
    _initializeTts();
    _initializeGameState();
  }
  
  Future<void> _initializeGameState() async {
    try {
      // Always listen to game state changes first
      _gameStateStream = GameStateService.getGameStateStream(widget.gameSession.gameId);
      
      // Check if game state exists, if not create it
      final existingState = await GameStateService.getGameState(widget.gameSession.gameId);
      if (existingState == null) {
        print('Initializing game state for game: ${widget.gameSession.gameId}');
        await GameStateService.initializeGameState(
          widget.gameSession.gameId,
          widget.gameSession.playerIds,
        );
      } else {
        print('Game state already exists for game: ${widget.gameSession.gameId}');
      }
    } catch (e) {
      print('Error initializing game state: $e');
    }
  }
  
  void _initializeGrid() {
    // Use game session word grid if available, otherwise use default
    if (widget.gameSession.wordGrid != null) {
      gridContent = widget.gameSession.wordGrid!;
    } else {
      // Default word grid
      gridContent = [
        ['cat', 'dog', 'pig', 'cow', 'hen', 'fox'],
        ['run', 'hop', 'sit', 'jump', 'walk', 'skip'],
        ['red', 'blue', 'green', 'pink', 'yellow', 'white'],
        ['mom', 'dad', 'sister', 'brother', 'baby', 'family'],
        ['one', 'two', 'three', 'four', 'five', 'six'],
        ['sun', 'moon', 'star', 'cloud', 'rain', 'snow'],
      ];
    }
  }

  Future<void> _initializeTts() async {
    try {
      _flutterTts = FlutterTts();
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
    } catch (e) {
      print('TTS initialization error: $e');
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _rollDice() async {
    if (_isRolling) return;

    // Check if it's this player's turn (if turn-based)
    if (_currentGameState != null && !_currentGameState!.simultaneousPlay) {
      if (_currentGameState!.currentTurnPlayerId != widget.user.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Wait for your turn!'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }
    }

    setState(() {
      _isRolling = true;
    });

    // Set rolling state in Firebase
    await GameStateService.setRollingState(
      gameId: widget.gameSession.gameId,
      playerId: widget.user.id,
      isRolling: true,
    );

    // Play sound effect (placeholder)
    // SoundService.playSound('dice_roll');

    // Animate dice roll
    int finalDiceValue = 1;
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        finalDiceValue = _random.nextInt(6) + 1;
      }
    }

    // Update Firebase with final dice roll
    await GameStateService.updateDiceRoll(
      gameId: widget.gameSession.gameId,
      playerId: widget.user.id,
      diceValue: finalDiceValue,
    );

    setState(() {
      _isRolling = false;
    });
  }

  void _toggleCell(int row, int col) {
    if (_currentGameState == null) return;

    final cellKey = '$row-$col';
    final word = gridContent[row][col];
    final diceValue = _currentGameState!.currentDiceValue;
    final isMyTurn = _currentGameState!.simultaneousPlay || _currentGameState!.currentTurnPlayerId == widget.user.id;

    // Check if it's the player's turn
    if (!isMyTurn && !widget.isTeacherMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Wait for your turn!'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Check if this is a valid column selection (matching dice value)
    if (!widget.isTeacherMode && col + 1 != diceValue) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You can only select words from column $diceValue!'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final playerCells = _currentGameState!.getPlayerCompletedCells(widget.user.id);
    final playerOwnsCell = playerCells.contains(cellKey);

    // Prevent players from selecting cells they already own
    if (playerOwnsCell && !widget.isTeacherMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You have already completed this word!'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Prevent players from selecting more than one square per turn (check pending pronunciations)
    if (!widget.isTeacherMode) {
      final playerPendingPronunciations = _currentGameState!.pendingPronunciations.values
          .where((attempt) => attempt.playerId == widget.user.id);
      
      if (playerPendingPronunciations.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You can only select one square per turn! Wait for teacher approval.'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }
    }

    // For non-teacher mode
    if (!widget.isTeacherMode && !playerOwnsCell) {
      // Check if this is a steal attempt (another player owns this cell)
      final cellOwner = _currentGameState!.getCellOwner(cellKey);
      if (cellOwner != null && cellOwner != widget.user.id) {
        // This is a steal attempt - mark as contested AND start pronunciation
        GameStateService.toggleCell(
          gameId: widget.gameSession.gameId,
          playerId: widget.user.id,
          cellKey: cellKey,
          isCompleted: true, // Mark as completed to trigger contest logic
        );
      }
      
      // Start pronunciation attempt for teacher review
      _startPronunciationAttempt(cellKey, word);
    } else if (widget.isTeacherMode) {
      // Teachers can toggle cells directly without pronunciation approval
      GameStateService.toggleCell(
        gameId: widget.gameSession.gameId,
        playerId: widget.user.id,
        cellKey: cellKey,
        isCompleted: !playerOwnsCell,
      );
    }

    // Play sound effect (placeholder)
    // SoundService.playSound('word_select');
  }

  void _startPronunciationAttempt(String cellKey, String word) {
    // This would typically record/listen for pronunciation, 
    // but for now we'll simulate it by adding to pending pronunciations
    GameStateService.updateGameState(
      _currentGameState!.startPronunciationAttempt(
        playerId: widget.user.id,
        playerName: widget.user.displayName,
        cellKey: cellKey,
        word: word,
      ),
    );
  }

  void _speakWord(String word) {
    try {
      _flutterTts.speak(word);
    } catch (e) {
      print('Error speaking word: $e');
    }
  }

  Future<void> _approvePronunciation(String cellKey) async {
    try {
      final winnerId = await GameStateService.approvePronunciation(
        gameId: widget.gameSession.gameId,
        cellKey: cellKey,
        playerIds: widget.gameSession.playerIds,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pronunciation approved!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Check if someone won the game
      if (winnerId != null) {
        await GameSessionService.completeGameSession(
          gameId: widget.gameSession.gameId,
          winnerId: winnerId,
        );
      }
    } catch (e) {
      print('Error approving pronunciation: $e');
    }
  }

  Future<void> _rejectPronunciation(String cellKey) async {
    try {
      await GameStateService.rejectPronunciation(
        gameId: widget.gameSession.gameId,
        cellKey: cellKey,
        playerIds: widget.gameSession.playerIds,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pronunciation needs improvement'),
          backgroundColor: AppColors.warning,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error rejecting pronunciation: $e');
    }
  }

  Color _getCellColor(int row, int col) {
    if (_currentGameState == null) return Colors.grey.shade100;
    
    final cellKey = '$row-$col';
    final diceValue = _currentGameState!.currentDiceValue;
    
    // Check if this cell is contested
    if (_currentGameState!.isCellContested(cellKey)) {
      // Get the players involved in the contest
      final playersInvolved = <String>[];
      for (String playerId in _currentGameState!.playerCompletedCells.keys) {
        if (_currentGameState!.playerCompletedCells[playerId]!.contains(cellKey)) {
          playersInvolved.add(playerId);
        }
      }
      
      if (playersInvolved.length >= 2) {
        // Show half-and-half colors for contested cells
        final player1 = widget.gameSession.players.firstWhere(
          (p) => p.userId == playersInvolved[0],
          orElse: () => widget.gameSession.players.first,
        );
        final player2 = widget.gameSession.players.firstWhere(
          (p) => p.userId == playersInvolved[1],
          orElse: () => widget.gameSession.players.last,
        );
        
        // For now, blend the colors - we'll implement a better half-and-half visual later
        final color1 = player1.playerColor != null ? Color(player1.playerColor!) : Colors.blue;
        final color2 = player2.playerColor != null ? Color(player2.playerColor!) : Colors.red;
        
        return Color.lerp(color1, color2, 0.5)!.withOpacity(0.7);
      }
      return Colors.red.withOpacity(0.3); // Fallback
    }
    
    // Check if this cell is completed by any player
    final owner = _currentGameState!.getCellOwner(cellKey);
    if (owner != null) {
      // Find the player to get their color
      final ownerPlayer = widget.gameSession.players.firstWhere(
        (p) => p.userId == owner,
        orElse: () => widget.gameSession.players.first,
      );
      
      if (ownerPlayer.playerColor != null) {
        return Color(ownerPlayer.playerColor!).withOpacity(0.7);
      }
      return Colors.green.withOpacity(0.7);
    }
    
    // Check if there's a pending pronunciation for this cell
    if (_currentGameState!.hasPendingPronunciation(cellKey)) {
      return AppColors.warning.withOpacity(0.3);
    }
    
    // Highlight valid columns after dice roll (for current player)
    final isMyTurn = _currentGameState!.simultaneousPlay || _currentGameState!.currentTurnPlayerId == widget.user.id;
    if (isMyTurn && col + 1 == diceValue && !widget.isTeacherMode) {
      return Colors.yellow.withOpacity(0.3);
    }
    
    return Colors.grey.shade100;
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    
    return StreamBuilder<GameStateModel?>(
      stream: _gameStateStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error loading game: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _initializeGameState(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        _currentGameState = snapshot.data;
        if (_currentGameState == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Setting up game...'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _initializeGameState(),
                    child: const Text('Initialize Game'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.gameBackground,
          body: _buildGame(context, isTablet),
        );
      },
    );
  }

  Widget _buildGame(BuildContext context, bool isTablet) {
    final diceValue = _currentGameState!.currentDiceValue;
    final myCompletedCells = _currentGameState!.getPlayerCompletedCells(widget.user.id);
    
    final player1 = widget.gameSession.players.isNotEmpty ? widget.gameSession.players[0] : null;
    final player2 = widget.gameSession.players.length > 1 ? widget.gameSession.players[1] : null;
    
    final player1Score = player1 != null ? _currentGameState!.getPlayerScore(player1.userId) : 0;
    final player2Score = player2 != null ? _currentGameState!.getPlayerScore(player2.userId) : 0;
    
    // Check if someone else is rolling
    final someoneElseRolling = _currentGameState!.isRolling && 
        _currentGameState!.currentPlayerId != widget.user.id;

    return Column(
      children: [
        // Player status bar
        Container(
          padding: const EdgeInsets.all(12),
          color: AppColors.gameBackground,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (player1 != null)
                Expanded(
                  child: _buildPlayerIndicator(
                    player1.userId,
                    player1.displayName,
                    player1Score,
                    !widget.isTeacherMode && player1.userId == widget.user.id,
                  ),
                ),
              if (player1 != null && player2 != null)
                const SizedBox(width: 16),
              if (player2 != null)
                Expanded(
                  child: _buildPlayerIndicator(
                    player2.userId,
                    player2.displayName,
                    player2Score,
                    !widget.isTeacherMode && player2.userId == widget.user.id,
                  ),
                ),
            ],
          ),
        ),
        
        // Teacher panel (only show in teacher mode)
        if (widget.isTeacherMode)
          _buildTeacherPanel(isTablet),
        
        // Turn indicator (only show in turn-based mode)
        if (!_currentGameState!.simultaneousPlay)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              color: AppColors.gamePrimary.withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    (!widget.isTeacherMode && _currentGameState!.currentTurnPlayerId == widget.user.id)
                        ? Icons.play_circle_fill
                        : Icons.schedule,
                    color: (!widget.isTeacherMode && _currentGameState!.currentTurnPlayerId == widget.user.id)
                        ? AppColors.success
                        : AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final screenWidth = MediaQuery.of(context).size.width;
                      double fontSize;
                      
                      if (screenWidth > 1200) { // Desktop/Large laptop
                        fontSize = 18;
                      } else if (screenWidth > 800) { // Tablet/small laptop
                        fontSize = 16;
                      } else if (screenWidth > 600) { // Large phone/small tablet
                        fontSize = 14;
                      } else { // Small phone
                        fontSize = 12;
                      }
                      
                      return Text(
                        (!widget.isTeacherMode && _currentGameState!.currentTurnPlayerId == widget.user.id)
                            ? 'Your Turn - Roll the dice!'
                            : '${_getPlayerName(_currentGameState!.currentTurnPlayerId)}\'s Turn',
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w600,
                          color: (!widget.isTeacherMode && _currentGameState!.currentTurnPlayerId == widget.user.id)
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        
        // Dice rolling section
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          color: AppColors.gameBackground,
          child: Column(
            children: [
              Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Calculate dice size based on available width
                    final screenWidth = MediaQuery.of(context).size.width;
                    double diceSize;
                    
                    if (screenWidth > 1200) { // Desktop/Large laptop
                      diceSize = 140;
                    } else if (screenWidth > 800) { // Tablet/small laptop
                      diceSize = 120;
                    } else if (screenWidth > 600) { // Large phone/small tablet
                      diceSize = 100;
                    } else { // Small phone
                      diceSize = 80;
                    }
                    
                    return AnimatedDice(
                      value: diceValue,
                      isRolling: _isRolling,
                      size: diceSize,
                      onTap: someoneElseRolling ? null : _rollDice,
                    );
                  },
                ),
              ),
              if (someoneElseRolling) ...[
                const SizedBox(height: 24),
                Text(
                  '${_currentGameState!.currentPlayerId == player1?.userId ? player1?.displayName : player2?.displayName} is rolling...',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary,
                  ),
                ),
              ] else if (_currentGameState!.lastDiceRoll != null) ...[
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    double fontSize;
                    
                    if (screenWidth > 1200) { // Desktop/Large laptop
                      fontSize = 18;
                    } else if (screenWidth > 800) { // Tablet/small laptop
                      fontSize = 16;
                    } else if (screenWidth > 600) { // Large phone/small tablet
                      fontSize = 14;
                    } else { // Small phone
                      fontSize = 12;
                    }
                    
                    return Text(
                      _buildDiceRollMessage(player1, player2),
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        
        // Game board - Dynamic sizing to fit device
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate available space for the grid
              final availableWidth = constraints.maxWidth - 16; // Account for margin
              final availableHeight = constraints.maxHeight - 16; // Account for margin
              
              // Calculate cell size based on available space
              final maxCellWidth = availableWidth / 6;
              final maxCellHeight = availableHeight / 6;
              final cellSize = maxCellWidth < maxCellHeight ? maxCellWidth : maxCellHeight;
              
              // Calculate spacing based on cell size
              final spacing = cellSize * 0.03; // 3% of cell size for spacing
              final borderRadius = cellSize * 0.08; // 8% of cell size for border radius
              
              // Calculate font size based on cell size
              final fontSize = cellSize * 0.18; // 18% of cell size
              
              return Container(
                margin: const EdgeInsets.all(8),
                child: Center(
                  child: SizedBox(
                    width: (cellSize * 6) + (spacing * 5),
                    height: (cellSize * 6) + (spacing * 5),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        childAspectRatio: 1,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                      ),
                      itemCount: 36,
                      itemBuilder: (context, index) {
                        final row = index ~/ 6;
                        final col = index % 6;
                        final word = gridContent[row][col];
                        
                        return InkWell(
                          onTap: widget.isTeacherMode ? null : () => _toggleCell(row, col),
                          onLongPress: () => _speakWord(word),
                          borderRadius: BorderRadius.circular(borderRadius),
                          child: _buildCellContainer(row, col, borderRadius, cellSize, word, fontSize),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerIndicator(String playerId, String displayName, int score, bool isCurrentUser) {
    // Find the player to get their color
    final player = widget.gameSession.players.firstWhere(
      (p) => p.userId == playerId,
      orElse: () => widget.gameSession.players.first,
    );
    final playerColor = player.playerColor != null ? Color(player.playerColor!) : AppColors.gamePrimary;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        double nameFontSize, scoreFontSize, youFontSize;
        double iconSize;
        EdgeInsets padding;
        
        if (screenWidth > 1200) { // Desktop/Large laptop
          nameFontSize = 16;
          scoreFontSize = 14;
          youFontSize = 14;
          iconSize = 24;
          padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
        } else if (screenWidth > 800) { // Tablet/small laptop
          nameFontSize = 14;
          scoreFontSize = 12;
          youFontSize = 12;
          iconSize = 20;
          padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
        } else if (screenWidth > 600) { // Large phone/small tablet
          nameFontSize = 13;
          scoreFontSize = 11;
          youFontSize = 11;
          iconSize = 18;
          padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10);
        } else { // Small phone
          nameFontSize = 12;
          scoreFontSize = 10;
          youFontSize = 10;
          iconSize = 16;
          padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 8);
        }
        
        return Container(
          padding: padding,
          decoration: BoxDecoration(
            color: playerColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: playerColor,
              width: isCurrentUser ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person,
                    color: playerColor,
                    size: iconSize,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      displayName,
                      style: TextStyle(
                        fontSize: nameFontSize,
                        fontWeight: FontWeight.w600,
                        color: playerColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isCurrentUser) ...[
                    const SizedBox(width: 4),
                    Text(
                      '(You)',
                      style: TextStyle(
                        fontSize: youFontSize,
                        fontStyle: FontStyle.italic,
                        color: playerColor,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Score: $score',
                style: TextStyle(
                  fontSize: scoreFontSize,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTeacherPanel(bool isTablet) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.adminBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.school, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentGameState!.pendingPronunciations.isNotEmpty 
                          ? 'Teacher Approval Needed'
                          : 'Teacher Controls',
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        _currentGameState!.pendingPronunciations.isNotEmpty
                          ? 'Students have pronounced words and need approval'
                          : 'Monitor the game and manage student progress',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Pronunciation attempts
          ..._currentGameState!.pendingPronunciations.entries.map((entry) {
            final cellKey = entry.key;
            final attempt = entry.value;
            return Container(
              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${attempt.playerName} pronounced: "${attempt.word}"',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Just now',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _approvePronunciation(cellKey),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(80, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _rejectPronunciation(cellKey),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Reject'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(80, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
          
          // End Game button for teachers
          Container(
            margin: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showEndGameConfirmation,
                icon: const Icon(Icons.stop, size: 18),
                label: const Text('End Game'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildDiceRollMessage(PlayerInGame? player1, PlayerInGame? player2) {
    final isSinglePlayer = widget.gameSession.playerIds.length <= 1;
    
    if (widget.isTeacherMode) {
      // Teacher mode - show who rolled
      final playerName = _currentGameState!.currentPlayerId == player1?.userId 
          ? player1?.displayName 
          : player2?.displayName;
      return '$playerName rolled a ${_currentGameState!.currentDiceValue}';
    } else if (_currentGameState!.currentPlayerId == widget.user.id) {
      // Current player rolled
      if (isSinglePlayer) {
        return 'You rolled a ${_currentGameState!.currentDiceValue}! Pick any word from the board';
      } else {
        return 'You rolled a ${_currentGameState!.currentDiceValue}! Pick a word in column ${_currentGameState!.currentDiceValue}';
      }
    } else {
      // Other player rolled
      final playerName = _currentGameState!.currentPlayerId == player1?.userId 
          ? player1?.displayName 
          : player2?.displayName;
      return '$playerName rolled a ${_currentGameState!.currentDiceValue}';
    }
  }

  String _getPlayerName(String? playerId) {
    if (playerId == null) return 'Unknown Player';
    final player = widget.gameSession.players.firstWhere(
      (p) => p.userId == playerId,
      orElse: () => PlayerInGame(
        userId: playerId,
        displayName: 'Unknown Player',
        emailAddress: '',
        joinedAt: DateTime.now(),
      ),
    );
    return player.displayName;
  }

  void _showEndGameConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('End Game?'),
          content: const Text('Are you sure you want to end this game? No additional points will be awarded and the game will be marked as completed.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _endGameWithoutPoints();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
              ),
              child: const Text('End Game'),
            ),
          ],
        );
      },
    );
  }

  void _endGameWithoutPoints() async {
    try {
      // End the game session without declaring a winner (no points awarded)
      await GameSessionService.endGameSession(
        gameId: widget.gameSession.gameId,
        winnerId: null, // No winner - game ended early
      );
      
      if (mounted) {
        Navigator.of(context).pop(); // Return to previous screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Game ended successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      print('Error ending game: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to end game. Please try again.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }

  Widget _buildCellContainer(int row, int col, double borderRadius, double cellSize, String word, double fontSize) {
    final cellKey = '$row-$col';
    
    // Check if this cell is contested
    if (_currentGameState != null && _currentGameState!.isCellContested(cellKey)) {
      // Get the players involved in the contest
      final playersInvolved = <String>[];
      for (String playerId in _currentGameState!.playerCompletedCells.keys) {
        if (_currentGameState!.playerCompletedCells[playerId]!.contains(cellKey)) {
          playersInvolved.add(playerId);
        }
      }
      
      if (playersInvolved.length >= 2) {
        // Create half-and-half visual
        final player1 = widget.gameSession.players.firstWhere(
          (p) => p.userId == playersInvolved[0],
          orElse: () => widget.gameSession.players.first,
        );
        final player2 = widget.gameSession.players.firstWhere(
          (p) => p.userId == playersInvolved[1],
          orElse: () => widget.gameSession.players.last,
        );
        
        final color1 = player1.playerColor != null ? Color(player1.playerColor!) : Colors.blue;
        final color2 = player2.playerColor != null ? Color(player2.playerColor!) : Colors.red;
        
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.grey.shade400,
              width: cellSize > 60 ? 1.5 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: DiagonalSplitPainter(
                      color1: color1.withOpacity(0.7),
                      color2: color2.withOpacity(0.7),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    word,
                    style: TextStyle(
                      fontSize: fontSize.clamp(8.0, 20.0),
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          offset: const Offset(1.0, 1.0),
                          blurRadius: 2.0,
                          color: Colors.black.withOpacity(0.7),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    
    // Regular cell (non-contested)
    return Container(
      decoration: BoxDecoration(
        color: _getCellColor(row, col),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.grey.shade400,
          width: cellSize > 60 ? 1.5 : 1,
        ),
      ),
      child: Center(
        child: Text(
          word,
          style: TextStyle(
            fontSize: fontSize.clamp(8.0, 20.0),
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}