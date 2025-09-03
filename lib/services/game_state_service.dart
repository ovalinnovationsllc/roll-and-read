import '../models/game_state_model.dart';
import 'firestore_service.dart';

class GameStateService {
  // Initialize game state when a game starts
  static Future<void> initializeGameState(String gameId, List<String> playerIds) async {
    try {
      
      // Create maps for player data
      final Map<String, Set<String>> playerCompletedCells = <String, Set<String>>{};
      final Map<String, int> playerScores = <String, int>{};
      
      for (final playerId in playerIds) {
        playerCompletedCells[playerId] = <String>{};
        playerScores[playerId] = 0;
      }
      
      final gameState = GameStateModel(
        gameId: gameId,
        playerCompletedCells: playerCompletedCells,
        playerScores: playerScores,
        currentTurnPlayerId: playerIds.isNotEmpty ? playerIds[0] : null, // Start with first player
        simultaneousPlay: false, // Turn-based play with teacher validation
      );
      
      await FirestoreService.saveGameState(gameState);
      
    } catch (e) {
      rethrow;
    }
  }

  // Get game state stream for real-time updates (using polling for local storage)
  static Stream<GameStateModel?> getGameStateStream(String gameId) {
    return Stream.periodic(const Duration(seconds: 2), (_) async {
      return await FirestoreService.getGameState(gameId.toUpperCase());
    }).asyncMap((future) => future);
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
      return;
    }
    
    if (playerIds.isEmpty) {
      return;
    }
    
    
    final currentIndex = playerIds.indexOf(gameState.currentTurnPlayerId ?? '');
    final nextIndex = (currentIndex + 1) % playerIds.length;
    final nextPlayerId = playerIds[nextIndex];
    
    
    final updatedGameState = gameState.switchToNextTurn(playerIds);
    
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
  
  static Future<void> startPronunciationAttemptAndSwitchTurn({
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
      await switchToNextTurn(gameId: gameId, playerIds: playerIds);
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
      await switchToNextTurn(gameId: gameId, playerIds: playerIds);
    } catch (e) {
      rethrow;
    }
  }

}