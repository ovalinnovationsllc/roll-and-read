import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter_tts/flutter_tts.dart';
import '../config/app_colors.dart';
import '../widgets/animated_dice.dart';
import '../models/user_model.dart';
import '../models/game_session_model.dart';
import '../models/game_state_model.dart';
import '../services/game_state_service.dart';
import '../services/game_session_service.dart';
import '../services/sound_service.dart';

class MultiplayerRollAndRead extends StatefulWidget {
  final UserModel user;
  final GameSessionModel gameSession;
  
  const MultiplayerRollAndRead({
    super.key,
    required this.user,
    required this.gameSession,
  });

  @override
  State<MultiplayerRollAndRead> createState() => _MultiplayerRollAndReadState();
}

class _MultiplayerRollAndReadState extends State<MultiplayerRollAndRead> {
  final Random _random = Random();
  late Stream<GameStateModel?> _gameStateStream;
  GameStateModel? _currentGameState;
  bool _isLocalRolling = false;
  bool _canRoll = true;
  late FlutterTts _flutterTts;
  
  // Grid content - 6 columns (for dice 1-6) x 6 rows
  late List<List<String>> gridContent;
  
  @override
  void initState() {
    super.initState();
    _initializeGrid();
    _gameStateStream = GameStateService.getGameStateStream(widget.gameSession.gameId);
    _initializeGameState();
    _initializeTts();
  }
  
  Color _getPlayerColor(String playerId) {
    final player = widget.gameSession.players.firstWhere(
      (p) => p.userId == playerId,
      orElse: () => throw Exception('Player not found'),
    );
    
    if (player.playerColor != null) {
      return Color(player.playerColor!);
    }
    
    // Fallback colors if no color is set
    final playerIndex = widget.gameSession.playerIds.indexOf(playerId);
    switch (playerIndex) {
      case 0:
        return AppColors.gamePrimary;
      case 1:
        return AppColors.darkBlue;
      default:
        return AppColors.gamePrimary;
    }
  }

  void _initializeTts() {
    _flutterTts = FlutterTts();
    _flutterTts.setLanguage("en-US");
    _flutterTts.setSpeechRate(0.5); // Slower speech for young learners
    _flutterTts.setVolume(1.0);
    _flutterTts.setPitch(1.0);
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  String _getPlayerName(String? playerId, GameStateModel gameState) {
    if (playerId == null) return 'Unknown Player';
    final player = widget.gameSession.players.firstWhere(
      (p) => p.userId == playerId,
      orElse: () => PlayerInGame(
        userId: playerId,
        displayName: 'Player',
        emailAddress: '',
        joinedAt: DateTime.now(),
      ),
    );
    return player.displayName;
  }

  Future<void> _speakWord(String word) async {
    try {
      await _flutterTts.speak(word);
    } catch (e) {
      print('Error speaking word: $e');
    }
  }

  void _initializeGrid() {
    // Use AI-generated words if available, otherwise use default
    if (widget.gameSession.wordGrid != null) {
      gridContent = widget.gameSession.wordGrid!;
    } else {
      // Default word grid
      gridContent = [
        ['cat', 'dog', 'pig', 'cow', 'hen', 'fox'],
        ['run', 'hop', 'sit', 'jump', 'walk', 'skip'],
        ['red', 'blue', 'green', 'pink', 'yellow', 'orange'],
        ['mom', 'dad', 'sister', 'brother', 'baby', 'family'],
        ['one', 'two', 'three', 'four', 'five', 'six'],
        ['sun', 'moon', 'star', 'cloud', 'rain', 'snow'],
      ];
    }
  }

  Future<void> _initializeGameState() async {
    // Check if game state exists, if not initialize it
    final gameState = await GameStateService.getGameState(widget.gameSession.gameId);
    if (gameState == null) {
      await GameStateService.initializeGameState(
        widget.gameSession.gameId,
        widget.gameSession.playerIds,
      );
    }
  }

  Future<void> _rollDice() async {
    if (!_canRoll || _isLocalRolling) return;
    
    // Check if it's this player's turn (in turn-based mode)
    final currentGameState = _currentGameState;
    if (currentGameState != null && !currentGameState.simultaneousPlay) {
      if (currentGameState.currentTurnPlayerId != widget.user.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('It\'s not your turn to roll!'),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
    }

    setState(() {
      _canRoll = false;
      _isLocalRolling = true;
    });

    // Set rolling state in Firestore
    await GameStateService.setRollingState(
      gameId: widget.gameSession.gameId,
      playerId: widget.user.id,
      isRolling: true,
    );

    // Simulate dice rolling animation
    Future.delayed(const Duration(milliseconds: 1500), () async {
      final diceValue = _random.nextInt(6) + 1;
      
      // Update dice value in Firestore
      await GameStateService.updateDiceRoll(
        gameId: widget.gameSession.gameId,
        playerId: widget.user.id,
        diceValue: diceValue,
      );

      setState(() {
        _isLocalRolling = false;
        _canRoll = true;
      });
    });
  }

  Future<void> _toggleCell(int row, int col, GameStateModel gameState) async {
    // Only allow marking cells in the column that matches the current dice value
    if (col + 1 != gameState.currentDiceValue || gameState.isRolling) return;
    
    // In turn-based mode, only allow the current turn player to select cells
    if (!gameState.simultaneousPlay && gameState.currentTurnPlayerId != widget.user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('It\'s not your turn! Wait for ${_getPlayerName(gameState.currentTurnPlayerId, gameState)} to finish.'),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    
    final cellKey = '$row-$col';
    final word = gridContent[row][col];
    
    // Check if there's already a pending pronunciation for this cell
    if (gameState.hasPendingPronunciation(cellKey)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Someone is already pronouncing this word. Please wait.'),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      // Play word selection sound
      await SoundService.playWordSelect();
      
      // Start pronunciation attempt
      final newState = gameState.startPronunciationAttempt(
        playerId: widget.user.id,
        playerName: widget.user.displayName,
        cellKey: cellKey,
        word: word,
      );
      
      await GameStateService.updateGameState(newState);
      
      // Show pronunciation request to the player
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Say "$word" aloud! Your teacher will approve when ready.'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Color _getCellColor(int row, int col, GameStateModel gameState) {
    final cellKey = '$row-$col';
    final player1Id = widget.gameSession.playerIds.isNotEmpty ? widget.gameSession.playerIds[0] : '';
    final player2Id = widget.gameSession.playerIds.length > 1 ? widget.gameSession.playerIds[1] : '';
    
    // Check if cell is contested - use white background so diagonal split shows properly
    if (gameState.isCellContested(cellKey)) {
      return AppColors.white;
    }
    
    // Check if cell has pending pronunciation on an already owned cell - treat as contested
    if (gameState.hasPendingPronunciation(cellKey)) {
      final cellOwner = gameState.getCellOwner(cellKey);
      if (cellOwner != null) {
        // Cell is owned and someone is trying to steal it - show as contested
        return AppColors.white;
      } else {
        // Cell is unowned and someone is trying to claim it - show purple/waiting color
        return AppColors.gamePrimary.withOpacity(0.3);
      }
    }
    
    // Check cell owner
    final cellOwner = gameState.getCellOwner(cellKey);
    if (cellOwner == player1Id) {
      return _getPlayerColor(player1Id).withOpacity(0.3);
    } else if (cellOwner == player2Id) {
      return _getPlayerColor(player2Id).withOpacity(0.3);
    }
    
    // Highlighted column for current dice value
    if (gameState.currentDiceValue == col + 1 && !gameState.isRolling) {
      return AppColors.mediumBlue.withOpacity(0.1);
    }
    
    // Default
    return Colors.white;
  }

  Widget _buildPlayerIndicator(String playerId, String playerName, int score, bool isCurrentPlayer, GameStateModel gameState) {
    final isRolling = gameState.isRolling && gameState.currentPlayerId == playerId;
    final justRolled = !gameState.isRolling && gameState.currentPlayerId == playerId;
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isCurrentPlayer ? AppColors.gamePrimary.withOpacity(0.2) : AppColors.lightGray.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrentPlayer ? AppColors.gamePrimary : AppColors.lightGray,
          width: justRolled ? 3 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person,
                size: 16,
                color: isCurrentPlayer ? AppColors.gamePrimary : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                playerName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isCurrentPlayer ? AppColors.gamePrimary : AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (isCurrentPlayer) ...[
                const SizedBox(width: 4),
                Text(
                  '(You)',
                  style: TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: AppColors.gamePrimary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Score: $score',
            style: const TextStyle(fontSize: 11),
          ),
          if (isRolling) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCurrentPlayer ? AppColors.gamePrimary : AppColors.textSecondary,
                ),
              ),
            ),
          ],
          if (justRolled) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.mediumBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Rolled ${gameState.currentDiceValue}',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    
    return StreamBuilder<GameStateModel?>(
      stream: _gameStateStream,
      builder: (context, snapshot) {
        final gameState = snapshot.data;
        if (gameState != null) {
          _currentGameState = gameState;
        }
        
        if (_currentGameState == null) {
          return const Center(child: CircularProgressIndicator());
        }
        
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
                        player1.userId == widget.user.id,
                        _currentGameState!,
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
                        player2.userId == widget.user.id,
                        _currentGameState!,
                      ),
                    ),
                ],
              ),
            ),
            
            // Turn indicator (only show in turn-based mode)
            if (!_currentGameState!.simultaneousPlay)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                color: AppColors.gamePrimary.withOpacity(0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _currentGameState!.currentTurnPlayerId == widget.user.id
                          ? Icons.play_circle_fill
                          : Icons.schedule,
                      color: _currentGameState!.currentTurnPlayerId == widget.user.id
                          ? AppColors.success
                          : AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _currentGameState!.currentTurnPlayerId == widget.user.id
                          ? 'Your Turn - Roll the dice!'
                          : '${_getPlayerName(_currentGameState!.currentTurnPlayerId, _currentGameState!)}\'s Turn',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _currentGameState!.currentTurnPlayerId == widget.user.id
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Dice rolling section
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              color: AppColors.gameBackground,
              child: Column(
                children: [
                  Center(
                    child: AnimatedDice(
                      value: _currentGameState!.currentDiceValue,
                      isRolling: _currentGameState!.isRolling,
                      size: isTablet ? 120 : 100,
                      onTap: someoneElseRolling ? null : _rollDice,
                    ),
                  ),
                  if (someoneElseRolling) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${_currentGameState!.currentPlayerId == player1?.userId ? player1?.displayName : player2?.displayName} is rolling...',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Result display
            if (!_currentGameState!.isRolling && _currentGameState!.lastDiceRoll != null)
              Container(
                padding: const EdgeInsets.all(10),
                color: AppColors.warning.withOpacity(0.1),
                child: Text(
                  _currentGameState!.currentPlayerId == widget.user.id
                      ? 'You rolled a ${_currentGameState!.currentDiceValue}! Pick a word in column ${_currentGameState!.currentDiceValue}'
                      : '${_currentGameState!.currentPlayerId == player1?.userId ? player1?.displayName : player2?.displayName} rolled a ${_currentGameState!.currentDiceValue}',
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkBlue,
                  ),
                ),
              ),
            
            // Grid section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    // Header row with dice
                    Container(
                      height: isTablet ? 70 : 60,
                      decoration: BoxDecoration(
                        color: AppColors.gamePrimary.withOpacity(0.1),
                        border: Border.all(color: AppColors.gamePrimary.withOpacity(0.3), width: 2),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10),
                        ),
                      ),
                      child: Row(
                        children: [
                          for (int i = 1; i <= 6; i++)
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: i < 6 
                                      ? BorderSide(color: AppColors.gamePrimary.withOpacity(0.3), width: 1)
                                      : BorderSide.none,
                                  ),
                                  color: _currentGameState!.currentDiceValue == i && !_currentGameState!.isRolling
                                    ? AppColors.mediumBlue.withOpacity(0.3)
                                    : Colors.transparent,
                                ),
                                child: Center(
                                  child: _buildDiceIcon(i, isTablet ? 40 : 35),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    // Grid rows
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.gamePrimary.withOpacity(0.3), width: 2),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(10),
                            bottomRight: Radius.circular(10),
                          ),
                        ),
                        child: Column(
                          children: [
                            for (int row = 0; row < 6; row++)
                              Expanded(
                                child: Row(
                                  children: [
                                    for (int col = 0; col < 6; col++)
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => _toggleCell(row, col, _currentGameState!),
                                          onLongPress: () => _speakWord(gridContent[row][col]),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              border: Border(
                                                right: col < 5 
                                                  ? BorderSide(color: AppColors.lightGray, width: 1)
                                                  : BorderSide.none,
                                                bottom: row < 5
                                                  ? BorderSide(color: AppColors.lightGray, width: 1)
                                                  : BorderSide.none,
                                              ),
                                              color: _getCellColor(row, col, _currentGameState!),
                                            ),
                                            child: Stack(
                                              children: [
                                                // Diagonal split for contested cells or pending steal attempts
                                                if (_currentGameState!.isCellContested('$row-$col') || 
                                                    (_currentGameState!.hasPendingPronunciation('$row-$col') && 
                                                     _currentGameState!.getCellOwner('$row-$col') != null))
                                                  _buildDiagonalSplit('$row-$col'),
                                                Center(
                                                  child: Text(
                                                    gridContent[row][col],
                                                    style: TextStyle(
                                                      fontSize: isTablet ? 18 : 14,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                                // Pending pronunciation indicator
                                                if (_currentGameState!.hasPendingPronunciation('$row-$col'))
                                                  _buildPronunciationPendingIndicator(),
                                                // Player indicators
                                                _buildCellPlayerIndicators(row, col, _currentGameState!),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  

  Widget _buildPronunciationPendingIndicator() {
    return Positioned(
      top: 2,
      right: 2,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.pending_actions,
          color: Colors.white,
          size: 12,
        ),
      ),
    );
  }

  Widget _buildDiagonalSplit(String cellKey) {
    final player1Id = widget.gameSession.playerIds.isNotEmpty ? widget.gameSession.playerIds[0] : '';
    final player2Id = widget.gameSession.playerIds.length > 1 ? widget.gameSession.playerIds[1] : '';
    
    // Determine which players are involved in the contest
    Color firstPlayerColor;
    Color secondPlayerColor;
    
    if (_currentGameState!.isCellContested(cellKey)) {
      // Cell is officially contested - show both player colors
      firstPlayerColor = _getPlayerColor(player1Id);
      secondPlayerColor = _getPlayerColor(player2Id);
    } else {
      // Cell has pending pronunciation on owned cell - show owner vs challenger
      final cellOwner = _currentGameState!.getCellOwner(cellKey);
      final pendingAttempt = _currentGameState!.getPendingPronunciation(cellKey);
      
      if (cellOwner != null && pendingAttempt != null) {
        firstPlayerColor = _getPlayerColor(cellOwner); // Current owner
        secondPlayerColor = _getPlayerColor(pendingAttempt.playerId); // Challenger
      } else {
        // Fallback
        firstPlayerColor = _getPlayerColor(player1Id);
        secondPlayerColor = _getPlayerColor(player2Id);
      }
    }
    
    return CustomPaint(
      painter: DiagonalSplitPainter(
        player1Color: firstPlayerColor,
        player2Color: secondPlayerColor,
      ),
      child: Container(
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }

  Widget _buildCellPlayerIndicators(int row, int col, GameStateModel gameState) {
    final cellKey = '$row-$col';
    final player1Id = widget.gameSession.playerIds.isNotEmpty ? widget.gameSession.playerIds[0] : '';
    final player2Id = widget.gameSession.playerIds.length > 1 ? widget.gameSession.playerIds[1] : '';
    
    final player1Cells = gameState.getPlayerCompletedCells(player1Id);
    final player2Cells = gameState.getPlayerCompletedCells(player2Id);
    
    final hasPlayer1 = player1Cells.contains(cellKey);
    final hasPlayer2 = player2Cells.contains(cellKey);
    
    if (!hasPlayer1 && !hasPlayer2) return const SizedBox.shrink();
    
    // Get player data from game session
    final player1 = widget.gameSession.players.firstWhere(
      (p) => p.userId == player1Id,
      orElse: () => PlayerInGame(
        userId: player1Id,
        displayName: 'Player 1',
        emailAddress: '',
        joinedAt: DateTime.now(),
      ),
    );
    final player2 = widget.gameSession.players.firstWhere(
      (p) => p.userId == player2Id,
      orElse: () => PlayerInGame(
        userId: player2Id,
        displayName: 'Player 2',
        emailAddress: '',
        joinedAt: DateTime.now(),
      ),
    );
    
    return Positioned(
      top: 2,
      right: 2,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasPlayer1)
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _getPlayerColor(player1Id),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  '1',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (hasPlayer1 && hasPlayer2)
            const SizedBox(width: 2),
          if (hasPlayer2)
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _getPlayerColor(player2Id),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  '2',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildDiceIcon(int value, double size) {
    final dotSize = size * 0.15;
    final dotColor = Colors.black87;
    
    Widget dot() => Container(
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(
        color: dotColor,
        shape: BoxShape.circle,
      ),
    );

    Widget empty() => SizedBox(width: dotSize, height: dotSize);

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.15),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.textPrimary, width: 2),
        borderRadius: BorderRadius.circular(size * 0.15),
      ),
      child: _getDicePattern(value, dot, empty),
    );
  }
  
  Widget _getDicePattern(int value, Widget Function() dot, Widget Function() empty) {
    switch (value) {
      case 1:
        return Center(child: dot());
      case 2:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [dot()],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [dot()],
            ),
          ],
        );
      case 3:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [dot()],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [dot()],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [dot()],
            ),
          ],
        );
      case 4:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [dot(), dot()],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [dot(), dot()],
            ),
          ],
        );
      case 5:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [dot(), dot()],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [dot()],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [dot(), dot()],
            ),
          ],
        );
      case 6:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [dot(), dot()],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [dot(), dot()],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [dot(), dot()],
            ),
          ],
        );
      default:
        return Center(child: dot());
    }
  }
}

class DiagonalSplitPainter extends CustomPainter {
  final Color player1Color;
  final Color player2Color;
  
  DiagonalSplitPainter({
    required this.player1Color,
    required this.player2Color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = player1Color.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    
    final paint2 = Paint()
      ..color = player2Color.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    
    // Draw top-left triangle (Player 1 - Blue)
    final path1 = Path();
    path1.moveTo(0, 0);
    path1.lineTo(size.width, 0);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, paint1);
    
    // Draw bottom-right triangle (Player 2 - Red)
    final path2 = Path();
    path2.moveTo(size.width, 0);
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }
  
  @override
  bool shouldRepaint(DiagonalSplitPainter oldDelegate) {
    return oldDelegate.player1Color != player1Color || 
           oldDelegate.player2Color != player2Color;
  }
}