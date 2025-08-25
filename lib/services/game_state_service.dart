import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_state_model.dart';

class GameStateService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _gameStatesCollection = 
      _firestore.collection('game_states');

  // Initialize game state when a game starts
  static Future<void> initializeGameState(String gameId, List<String> playerIds) async {
    final gameState = GameStateModel(
      gameId: gameId,
      playerCompletedCells: {for (var id in playerIds) id: {}},
      playerScores: {for (var id in playerIds) id: 0},
      currentTurnPlayerId: playerIds.isNotEmpty ? playerIds[0] : null,
      simultaneousPlay: false, // Set to turn-based mode
    );
    
    await _gameStatesCollection.doc(gameId).set(gameState.toMap());
  }

  // Get game state stream for real-time updates
  static Stream<GameStateModel?> getGameStateStream(String gameId) {
    return _gameStatesCollection
        .doc(gameId.toUpperCase())
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return GameStateModel.fromMap(doc.data() as Map<String, dynamic>);
        });
  }

  // Update dice roll
  static Future<void> updateDiceRoll({
    required String gameId,
    required String playerId,
    required int diceValue,
  }) async {
    await _gameStatesCollection.doc(gameId.toUpperCase()).update({
      'currentDiceValue': diceValue,
      'currentPlayerId': playerId,
      'lastDiceRoll': Timestamp.now(),
      'isRolling': false,
    });
  }

  // Set rolling state
  static Future<void> setRollingState({
    required String gameId,
    required String playerId,
    required bool isRolling,
  }) async {
    await _gameStatesCollection.doc(gameId.toUpperCase()).update({
      'isRolling': isRolling,
      'currentPlayerId': playerId,
    });
  }

  // Mark a cell as completed for a player
  static Future<void> toggleCell({
    required String gameId,
    required String playerId,
    required String cellKey,
    required bool isCompleted,
  }) async {
    final docRef = _gameStatesCollection.doc(gameId.toUpperCase());
    
    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);
      if (!doc.exists) return;
      
      final gameState = GameStateModel.fromMap(doc.data() as Map<String, dynamic>);
      
      final updatedState = isCompleted 
          ? gameState.markCellCompleted(playerId, cellKey)
          : gameState.unmarkCell(playerId, cellKey);
      
      transaction.update(docRef, updatedState.toMap());
    });
  }
  
  // Resolve a contested cell (player pronounced word correctly and steals it)
  static Future<void> resolveContestedCell({
    required String gameId,
    required String winningPlayerId,
    required String cellKey,
  }) async {
    final docRef = _gameStatesCollection.doc(gameId.toUpperCase());
    
    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);
      if (!doc.exists) return;
      
      final gameState = GameStateModel.fromMap(doc.data() as Map<String, dynamic>);
      final updatedState = gameState.resolveContestedCell(winningPlayerId, cellKey);
      
      transaction.update(docRef, updatedState.toMap());
    });
  }

  // Update current turn (for turn-based mode)
  static Future<void> updateCurrentTurn({
    required String gameId,
    required String nextPlayerId,
  }) async {
    await _gameStatesCollection.doc(gameId.toUpperCase()).update({
      'currentTurnPlayerId': nextPlayerId,
    });
  }

  // Reset game state
  static Future<void> resetGameState(String gameId, List<String> playerIds) async {
    final gameState = GameStateModel(
      gameId: gameId,
      playerCompletedCells: {for (var id in playerIds) id: {}},
      playerScores: {for (var id in playerIds) id: 0},
      currentDiceValue: 1,
      currentTurnPlayerId: playerIds.isNotEmpty ? playerIds[0] : null,
    );
    
    await _gameStatesCollection.doc(gameId).set(gameState.toMap());
  }

  // Delete game state when game ends
  static Future<void> deleteGameState(String gameId) async {
    try {
      await _gameStatesCollection.doc(gameId.toUpperCase()).delete();
    } catch (e) {
      print('Error deleting game state: $e');
    }
  }

  // Remove a player from the game state
  static Future<void> removePlayerFromGame({
    required String gameId,
    required String playerId,
  }) async {
    final docRef = _gameStatesCollection.doc(gameId.toUpperCase());
    
    try {
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) return;
        
        final gameState = GameStateModel.fromMap(doc.data() as Map<String, dynamic>);
        
        // Remove player's data
        final updatedPlayerCells = Map<String, Set<String>>.from(gameState.playerCompletedCells);
        final updatedPlayerScores = Map<String, int>.from(gameState.playerScores);
        final updatedContestedCells = Set<String>.from(gameState.contestedCells);
        
        updatedPlayerCells.remove(playerId);
        updatedPlayerScores.remove(playerId);
        
        // Remove any contested cells that involved this player
        final playerCells = gameState.getPlayerCompletedCells(playerId);
        for (final cellKey in playerCells) {
          if (updatedContestedCells.contains(cellKey)) {
            updatedContestedCells.remove(cellKey);
            // If this was a contested cell, we need to check if any other player still owns it
            bool otherPlayerOwnsCell = false;
            for (final otherPlayerId in updatedPlayerCells.keys) {
              if (updatedPlayerCells[otherPlayerId]!.contains(cellKey)) {
                otherPlayerOwnsCell = true;
                break;
              }
            }
            // If no other player owns this cell, remove it from their collections too
            if (!otherPlayerOwnsCell) {
              for (final otherPlayerId in updatedPlayerCells.keys) {
                updatedPlayerCells[otherPlayerId] = 
                    Set<String>.from(updatedPlayerCells[otherPlayerId]!)..remove(cellKey);
              }
            }
          }
        }
        
        final updatedState = gameState.copyWith(
          playerCompletedCells: updatedPlayerCells,
          playerScores: updatedPlayerScores,
          contestedCells: updatedContestedCells,
        );
        
        transaction.update(docRef, updatedState.toMap());
      });
    } catch (e) {
      print('Error removing player from game state: $e');
    }
  }

  // Get current game state (one-time fetch)
  static Future<GameStateModel?> getGameState(String gameId) async {
    try {
      final doc = await _gameStatesCollection.doc(gameId.toUpperCase()).get();
      if (!doc.exists) return null;
      return GameStateModel.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) {
      print('Error getting game state: $e');
      return null;
    }
  }

  // Update game state with a new state object
  static Future<void> updateGameState(GameStateModel gameState) async {
    try {
      await _gameStatesCollection.doc(gameState.gameId.toUpperCase()).set(gameState.toMap());
    } catch (e) {
      print('Error updating game state: $e');
      rethrow;
    }
  }

  // Approve a pronunciation attempt (Mrs. Elson marks it correct)
  static Future<void> approvePronunciation({
    required String gameId,
    required String cellKey,
    List<String>? playerIds,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _gameStatesCollection.doc(gameId.toUpperCase());
        final doc = await transaction.get(docRef);
        
        if (!doc.exists) {
          throw Exception('Game state not found');
        }
        
        final gameState = GameStateModel.fromMap(doc.data() as Map<String, dynamic>);
        var updatedState = gameState.approvePronunciation(cellKey);
        
        // Switch to next player's turn after approval
        if (playerIds != null) {
          updatedState = updatedState.switchToNextTurn(playerIds);
        }
        
        transaction.update(docRef, updatedState.toMap());
      });
    } catch (e) {
      print('Error approving pronunciation: $e');
      rethrow;
    }
  }

  // Reject a pronunciation attempt (Mrs. Elson marks it wrong or it times out)
  static Future<void> rejectPronunciation({
    required String gameId,
    required String cellKey,
    List<String>? playerIds,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _gameStatesCollection.doc(gameId.toUpperCase());
        final doc = await transaction.get(docRef);
        
        if (!doc.exists) {
          throw Exception('Game state not found');
        }
        
        final gameState = GameStateModel.fromMap(doc.data() as Map<String, dynamic>);
        var updatedState = gameState.rejectPronunciation(cellKey);
        
        // Switch to next player's turn after rejection
        if (playerIds != null) {
          updatedState = updatedState.switchToNextTurn(playerIds);
        }
        
        transaction.update(docRef, updatedState.toMap());
      });
    } catch (e) {
      print('Error rejecting pronunciation: $e');
      rethrow;
    }
  }
}