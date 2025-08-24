import 'package:flutter/material.dart';
import 'dart:math';
import '../widgets/animated_dice.dart';
import '../models/user_model.dart';
import '../models/game_session_model.dart';
import '../models/game_state_model.dart';
import '../services/game_state_service.dart';
import '../services/game_session_service.dart';

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
  
  // Grid content - 6 columns (for dice 1-6) x 6 rows
  late List<List<String>> gridContent;
  
  @override
  void initState() {
    super.initState();
    _initializeGrid();
    _gameStateStream = GameStateService.getGameStateStream(widget.gameSession.gameId);
    _initializeGameState();
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
    
    final cellKey = '$row-$col';
    final myCompletedCells = gameState.getPlayerCompletedCells(widget.user.id);
    final isCompleted = myCompletedCells.contains(cellKey);
    
    await GameStateService.toggleCell(
      gameId: widget.gameSession.gameId,
      playerId: widget.user.id,
      cellKey: cellKey,
      isCompleted: !isCompleted,
    );
  }

  Color _getCellColor(int row, int col, GameStateModel gameState) {
    final cellKey = '$row-$col';
    final player1Id = widget.gameSession.playerIds.isNotEmpty ? widget.gameSession.playerIds[0] : '';
    final player2Id = widget.gameSession.playerIds.length > 1 ? widget.gameSession.playerIds[1] : '';
    
    final player1Cells = gameState.getPlayerCompletedCells(player1Id);
    final player2Cells = gameState.getPlayerCompletedCells(player2Id);
    
    final isPlayer1Cell = player1Cells.contains(cellKey);
    final isPlayer2Cell = player2Cells.contains(cellKey);
    
    // Both players selected the same cell
    if (isPlayer1Cell && isPlayer2Cell) {
      return Colors.purple.shade100;
    }
    // Current player's cell
    else if (widget.user.id == player1Id && isPlayer1Cell) {
      return Colors.green.shade100;
    }
    // Other player's cell
    else if (widget.user.id == player2Id && isPlayer2Cell) {
      return Colors.blue.shade100;
    }
    // Other player's cell (from current player's perspective)
    else if (widget.user.id == player1Id && isPlayer2Cell) {
      return Colors.blue.shade100;
    }
    else if (widget.user.id == player2Id && isPlayer1Cell) {
      return Colors.green.shade100;
    }
    // Highlighted column for current dice value
    else if (gameState.currentDiceValue == col + 1 && !gameState.isRolling) {
      return Colors.yellow.shade50;
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
        color: isCurrentPlayer ? Colors.green.shade200 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrentPlayer ? Colors.green.shade400 : Colors.grey.shade400,
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
                color: isCurrentPlayer ? Colors.green.shade700 : Colors.grey.shade700,
              ),
              const SizedBox(width: 4),
              Text(
                playerName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isCurrentPlayer ? Colors.green.shade700 : Colors.grey.shade700,
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
                    color: Colors.green.shade600,
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
                  isCurrentPlayer ? Colors.green.shade600 : Colors.grey.shade600,
                ),
              ),
            ),
          ],
          if (justRolled) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.shade200,
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
              color: Colors.grey.shade100,
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
            
            // Dice rolling section
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              color: Colors.green.shade50,
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
                        color: Colors.grey.shade700,
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
                color: Colors.amber.shade100,
                child: Text(
                  _currentGameState!.currentPlayerId == widget.user.id
                      ? 'You rolled a ${_currentGameState!.currentDiceValue}! Pick a word in column ${_currentGameState!.currentDiceValue}'
                      : '${_currentGameState!.currentPlayerId == player1?.userId ? player1?.displayName : player2?.displayName} rolled a ${_currentGameState!.currentDiceValue}',
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
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
                        color: Colors.blue.shade100,
                        border: Border.all(color: Colors.blue.shade300, width: 2),
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
                                      ? BorderSide(color: Colors.blue.shade300, width: 1)
                                      : BorderSide.none,
                                  ),
                                  color: _currentGameState!.currentDiceValue == i && !_currentGameState!.isRolling
                                    ? Colors.yellow.shade300
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
                          border: Border.all(color: Colors.blue.shade300, width: 2),
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
                                          child: Container(
                                            decoration: BoxDecoration(
                                              border: Border(
                                                right: col < 5 
                                                  ? BorderSide(color: Colors.grey.shade300, width: 1)
                                                  : BorderSide.none,
                                                bottom: row < 5
                                                  ? BorderSide(color: Colors.grey.shade300, width: 1)
                                                  : BorderSide.none,
                                              ),
                                              color: _getCellColor(row, col, _currentGameState!),
                                            ),
                                            child: Stack(
                                              children: [
                                                Center(
                                                  child: Text(
                                                    gridContent[row][col],
                                                    style: TextStyle(
                                                      fontSize: isTablet ? 18 : 14,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.black87,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
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
  
  Widget _buildCellPlayerIndicators(int row, int col, GameStateModel gameState) {
    final cellKey = '$row-$col';
    final player1Id = widget.gameSession.playerIds.isNotEmpty ? widget.gameSession.playerIds[0] : '';
    final player2Id = widget.gameSession.playerIds.length > 1 ? widget.gameSession.playerIds[1] : '';
    
    final player1Cells = gameState.getPlayerCompletedCells(player1Id);
    final player2Cells = gameState.getPlayerCompletedCells(player2Id);
    
    final hasPlayer1 = player1Cells.contains(cellKey);
    final hasPlayer2 = player2Cells.contains(cellKey);
    
    if (!hasPlayer1 && !hasPlayer2) return const SizedBox.shrink();
    
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
                color: widget.user.id == player1Id ? Colors.green : Colors.blue,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  '1',
                  style: TextStyle(
                    color: Colors.white,
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
                color: widget.user.id == player2Id ? Colors.green : Colors.blue,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  '2',
                  style: TextStyle(
                    color: Colors.white,
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
        color: Colors.white,
        border: Border.all(color: Colors.black87, width: 2),
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