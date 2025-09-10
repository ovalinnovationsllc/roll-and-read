import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_state_model.dart';
import 'firestore_service.dart';

class GameStateService {
  // Initialize game state when a game starts
  static Future<void> initializeGameState(String gameId, List<String> playerIds) async {
    try {
      print('🎮 GAME STATE INIT: Initializing game $gameId with players: $playerIds');
      
      if (playerIds.isEmpty) {
        print('❌ GAME STATE INIT: No players provided! Cannot initialize game state.');
        throw Exception('Cannot initialize game state: no players provided');
      }
      
      // Create maps for player data
      final Map<String, Set<String>> playerCompletedCells = <String, Set<String>>{};
      final Map<String, int> playerScores = <String, int>{};
      
      for (final playerId in playerIds) {
        playerCompletedCells[playerId] = <String>{};
        playerScores[playerId] = 0;
      }
      
      final firstPlayerId = playerIds[0];
      print('🎮 GAME STATE INIT: Setting first turn to player: $firstPlayerId');
      
      final gameState = GameStateModel(
        gameId: gameId,
        playerCompletedCells: playerCompletedCells,
        playerScores: playerScores,
        currentTurnPlayerId: firstPlayerId, // Start with first player
        simultaneousPlay: false, // Turn-based play with teacher validation
      );
      
      await FirestoreService.saveGameState(gameState);
      print('✅ GAME STATE INIT: Successfully initialized game state for $gameId');
      
    } catch (e) {
      print('❌ GAME STATE INIT: Failed to initialize game state for $gameId: $e');
      rethrow;
    }
  }

  // Fix broken game state by reinitializing with current players
  static Future<void> fixBrokenGameState(String gameId, List<String> playerIds) async {
    try {
      print('🔧 FIXING BROKEN GAME STATE: Reinitializing $gameId with players: $playerIds');
      
      if (playerIds.isEmpty) {
        print('❌ CANNOT FIX: No players provided');
        return;
      }
      
      // Get existing game state
      final existingState = await FirestoreService.getGameState(gameId.toUpperCase());
      
      // Create new state preserving any existing scores but fixing the turn
      final Map<String, Set<String>> playerCompletedCells = <String, Set<String>>{};
      final Map<String, int> playerScores = <String, int>{};
      
      for (final playerId in playerIds) {
        playerCompletedCells[playerId] = existingState?.playerCompletedCells[playerId] ?? <String>{};
        playerScores[playerId] = existingState?.playerScores[playerId] ?? 0;
      }
      
      final firstPlayerId = playerIds[0];
      print('🔧 FIXING: Setting turn to first player: $firstPlayerId');
      
      final fixedGameState = GameStateModel(
        gameId: gameId,
        playerCompletedCells: playerCompletedCells,
        playerScores: playerScores,
        currentTurnPlayerId: firstPlayerId, // Reset to first player
        simultaneousPlay: false,
        currentPlayerId: null, // Reset current player
        lastDiceRoll: null, // Reset dice
        currentDiceValue: null, // Reset dice value
        pendingPronunciations: <String, PronunciationAttempt>{}, // Clear pending
        pronunciationLog: existingState?.pronunciationLog ?? [], // Preserve log
      );
      
      await FirestoreService.updateGameState(fixedGameState);
      print('✅ FIXED: Game state repaired for $gameId');
      
    } catch (e) {
      print('❌ FAILED TO FIX: Game state repair failed for $gameId: $e');
    }
  }

  // Get game state stream for real-time updates (using Firestore real-time listener)
  static Stream<GameStateModel?> getGameStateStream(String gameId) {
    return FirebaseFirestore.instance
        .collection('gameStates')
        .doc(gameId.toUpperCase())
        .snapshots()
        .map((snapshot) {
      try {
        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data();
          
          // Handle JavaScript object conversion for Flutter web
          Map<String, dynamic> convertedData;
          if (data is Map<String, dynamic>) {
            convertedData = data;
          } else {
            // Convert JavaScript object to proper Map for Flutter web
            convertedData = Map<String, dynamic>.from(data as Map);
          }
          
          final gameState = GameStateModel.fromMap(convertedData);
          
          // Check if game state is in a broken state (no current turn player)
          if (gameState.currentTurnPlayerId == null) {
            print('🚨 BROKEN GAME STATE DETECTED: No current turn player for game ${gameState.gameId}');
            // We can't fix it here in the stream, but we can log it
          }
          
          return gameState;
        }
        return null;
      } catch (e, stackTrace) {
        print('⚠️ Error parsing game state from stream: $e');
        print('⚠️ Stack trace: $stackTrace');
        return null;
      }
    });
  }

  // Get game state directly (non-stream)
  static Future<GameStateModel?> getGameState(String gameId) async {
    return await FirestoreService.getGameState(gameId.toUpperCase());
  }

  // Update dice roll
  static Future<void> updateDiceRoll({
    required String gameId,
    required String playerId,
    required int diceValue,
  }) async {
    final gameState = await FirestoreService.getGameState(gameId.toUpperCase());
    if (gameState != null) {
      final updatedGameState = gameState.copyWith(
        currentDiceValue: diceValue,
        currentPlayerId: playerId,
        lastDiceRoll: DateTime.now(),
      );
      await FirestoreService.updateGameState(updatedGameState);
    }
  }

  // Set rolling state
  static Future<void> setRollingState({
    required String gameId,
    required String playerId,
    required bool isRolling,
  }) async {
    final gameState = await FirestoreService.getGameState(gameId.toUpperCase());
    if (gameState != null) {
      final updatedGameState = gameState.copyWith(
        currentPlayerId: playerId,
      );
      await FirestoreService.updateGameState(updatedGameState);
    }
  }

  // Mark a cell as completed for a player (simplified for local storage)
  static Future<void> toggleCell({
    required String gameId,
    required String playerId,
    required String cellKey,
    required bool isCompleted,
  }) async {
    
    try {
      final gameState = await FirestoreService.getGameState(gameId.toUpperCase());
      if (gameState == null) {
        return;
      }
      
      final updatedState = isCompleted 
          ? gameState.markCellCompleted(playerId, cellKey)
          : gameState; // For simplicity, just mark completed for local storage
      
      await FirestoreService.updateGameState(updatedState);
    } catch (e) {
    }
  }

  // Update current turn (for turn-based mode)
  static Future<void> updateCurrentTurn({
    required String gameId,
    required String nextPlayerId,
  }) async {
    final gameState = await FirestoreService.getGameState(gameId.toUpperCase());
    if (gameState != null) {
      final updatedGameState = gameState.copyWith(
        currentTurnPlayerId: nextPlayerId,
      );
      await FirestoreService.updateGameState(updatedGameState);
    }
  }

  // Switch to next turn (simplified for local storage)
  static Future<void> switchToNextTurn({
    required String gameId,
    required List<String> playerIds,
  }) async {
    
    final gameState = await FirestoreService.getGameState(gameId.toUpperCase());
    if (gameState == null) {
      print('⚠️ SWITCH TURN: No game state found for $gameId');
      return;
    }
    
    if (playerIds.isEmpty) {
      print('⚠️ SWITCH TURN: No playerIds provided');
      return;
    }
    
    print('🔄 SWITCH TURN: Current player: ${gameState.currentTurnPlayerId}, PlayerIds: $playerIds');
    
    // Use the GameStateModel's switchToNextTurn method which has the proper logic
    final updatedGameState = gameState.switchToNextTurn(playerIds);
    
    print('🔄 SWITCH TURN: Next player will be: ${updatedGameState.currentTurnPlayerId}');
    
    await FirestoreService.updateGameState(updatedGameState);
  }

  // Delete game state when game ends
  static Future<void> deleteGameState(String gameId) async {
    try {
      await FirestoreService.deleteGameState(gameId.toUpperCase());
    } catch (e) {
    }
  }

  // Helper method to get player name (simplified for local storage)
  static String _getPlayerNameFromId(String playerId) {
    // For simplicity, just return the player ID
    // In a real implementation, you might look up the student name
    return playerId;
  }

  // Missing methods needed by multiplayer screen (simplified for local storage)
  
  static Future<void> startPronunciationAttempt({
    required String gameId,
    required String playerId,
    required String playerName,
    required String cellKey,
    required String word,
    required List<String> playerIds,
  }) async {
    
    try {
      // Get current game state
      final gameState = await getGameState(gameId);
      if (gameState == null) {
        return;
      }
      
      // Create pronunciation attempt
      final pronunciationAttempt = PronunciationAttempt(
        playerId: playerId,
        playerName: playerName,
        cellKey: cellKey,
        word: word,
        startTime: DateTime.now(),
      );
      
      // Add to pending pronunciations
      final updatedPending = Map<String, PronunciationAttempt>.from(gameState.pendingPronunciations);
      updatedPending[cellKey] = pronunciationAttempt;
      
      // Update game state with pending pronunciation
      final updatedState = gameState.copyWith(
        pendingPronunciations: updatedPending,
      );
      
      await FirestoreService.updateGameState(updatedState);
    } catch (e) {
    }
  }
  
  // Pronunciation approval methods for teacher monitor
  static Future<void> approvePronunciation({
    required String gameId,
    required String cellKey,
    required List<String> playerIds, // Add playerIds parameter for turn switching
  }) async {
    try {
      print('🎯 APPROVE: Switching turns with playerIds: $playerIds');
      
      // Get current game state
      final gameState = await getGameState(gameId);
      if (gameState == null) return;
      
      print('🎯 APPROVE: Current turn player: ${gameState.currentTurnPlayerId}');
      
      // Get the pronunciation attempt
      final pronunciationAttempt = gameState.pendingPronunciations[cellKey];
      if (pronunciationAttempt == null) return;
      
      // Check if this was a steal attempt (cell was owned by another player)
      String? previousOwnerId;
      String? previousOwnerName;
      final cellOwner = gameState.getCellOwner(cellKey);
      if (cellOwner != null && cellOwner != pronunciationAttempt.playerId) {
        previousOwnerId = cellOwner;
        // We can't easily get the player name here since we don't have game session access
        // The teacher monitor will handle name resolution
        previousOwnerName = null; // Will be resolved in the UI
      }
      
      // Create log entry for approved pronunciation
      final logEntry = PronunciationLogEntry(
        playerId: pronunciationAttempt.playerId,
        playerName: pronunciationAttempt.playerName,
        cellKey: cellKey,
        word: pronunciationAttempt.word,
        attemptTime: pronunciationAttempt.startTime,
        resolvedTime: DateTime.now(),
        approved: true,
        previousOwnerId: previousOwnerId,
        previousOwnerName: previousOwnerName,
      );
      
      // Remove from pending pronunciations, mark cell as completed, and add to log
      final updatedLog = List<PronunciationLogEntry>.from(gameState.pronunciationLog)..add(logEntry);
      final updatedState = gameState
          .markCellCompleted(pronunciationAttempt.playerId, cellKey)
          .copyWith(
            pendingPronunciations: Map<String, PronunciationAttempt>.from(gameState.pendingPronunciations)..remove(cellKey),
            pronunciationLog: updatedLog,
          );
      
      await FirestoreService.updateGameState(updatedState);
      
      // Switch to next turn after approval
      print('🎯 APPROVE: About to switch to next turn');
      await switchToNextTurn(gameId: gameId, playerIds: playerIds);
      print('🎯 APPROVE: Turn switching completed');
    } catch (e) {
      rethrow;
    }
  }
  
  static Future<void> rejectPronunciation({
    required String gameId,
    required String cellKey,
    required List<String> playerIds, // Add playerIds parameter for turn switching
  }) async {
    try {
      
      // Get current game state
      final gameState = await getGameState(gameId);
      if (gameState == null) return;
      
      // Get the pronunciation attempt
      final pronunciationAttempt = gameState.pendingPronunciations[cellKey];
      if (pronunciationAttempt == null) return;
      
      // Check if this was a steal attempt (cell was owned by another player)
      String? previousOwnerId;
      String? previousOwnerName;
      final cellOwner = gameState.getCellOwner(cellKey);
      if (cellOwner != null && cellOwner != pronunciationAttempt.playerId) {
        previousOwnerId = cellOwner;
        previousOwnerName = null; // Will be resolved in the UI
      }
      
      // Create log entry for rejected pronunciation
      final logEntry = PronunciationLogEntry(
        playerId: pronunciationAttempt.playerId,
        playerName: pronunciationAttempt.playerName,
        cellKey: cellKey,
        word: pronunciationAttempt.word,
        attemptTime: pronunciationAttempt.startTime,
        resolvedTime: DateTime.now(),
        approved: false,
        previousOwnerId: previousOwnerId,
        previousOwnerName: previousOwnerName,
      );
      
      // Remove from pending pronunciations and add to log (no point awarded)
      final updatedPending = Map<String, PronunciationAttempt>.from(gameState.pendingPronunciations);
      updatedPending.remove(cellKey);
      final updatedLog = List<PronunciationLogEntry>.from(gameState.pronunciationLog)..add(logEntry);
      
      // Update game state
      final updatedState = gameState.copyWith(
        pendingPronunciations: updatedPending,
        pronunciationLog: updatedLog,
      );
      
      await FirestoreService.updateGameState(updatedState);
      
      // Switch to next turn after rejection
      print('🎯 REJECT: About to switch to next turn');
      await switchToNextTurn(gameId: gameId, playerIds: playerIds);
      print('🎯 REJECT: Turn switching completed');
    } catch (e) {
      rethrow;
    }
  }

}