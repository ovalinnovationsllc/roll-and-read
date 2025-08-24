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
}