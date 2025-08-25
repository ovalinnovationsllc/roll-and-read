import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_session_model.dart';
import '../models/user_model.dart';
import 'ai_word_service.dart';
import 'firestore_service.dart';
import 'game_state_service.dart';
import 'dart:math';

class GameSessionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _gamesCollection = _firestore.collection('game_sessions');

  // Generate a unique 6-character game ID
  static String generateGameId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  // Create a new game session
  static Future<GameSessionModel> createGameSession({
    required String createdBy,
    required String gameName,
    bool useAIWords = false,
    String? aiPrompt,
    String? difficulty,
    List<List<String>>? wordGrid,
    int maxPlayers = 2,
  }) async {
    String gameId;
    bool isUnique = false;

    // Keep generating IDs until we find a unique one
    do {
      gameId = generateGameId();
      final existing = await _gamesCollection.doc(gameId).get();
      isUnique = !existing.exists;
    } while (!isUnique);

    // Use provided wordGrid or generate AI words if requested
    List<List<String>>? finalWordGrid = wordGrid;
    if (finalWordGrid == null && useAIWords && aiPrompt != null && aiPrompt.isNotEmpty) {
      try {
        finalWordGrid = await AIWordService.generateWordGrid(
          prompt: aiPrompt,
          difficulty: difficulty ?? 'elementary',
        );
      } catch (e) {
        print('AI word generation failed, using fallback: $e');
        // Continue without AI words - will use default grid
      }
    }

    final gameSession = GameSessionModel.create(
      gameId: gameId,
      createdBy: createdBy,
      gameName: gameName,
      useAIWords: useAIWords,
      aiPrompt: aiPrompt,
      difficulty: difficulty,
      wordGrid: finalWordGrid,
      maxPlayers: maxPlayers,
    );

    await _gamesCollection.doc(gameId).set(gameSession.toMap());
    return gameSession;
  }

  // Get game session by ID
  static Future<GameSessionModel?> getGameSession(String gameId) async {
    try {
      final doc = await _gamesCollection.doc(gameId.toUpperCase()).get();
      if (!doc.exists) return null;
      
      return GameSessionModel.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) {
      print('Error getting game session: $e');
      return null;
    }
  }

  // Join a game session
  static Future<GameSessionModel?> joinGameSession({
    required String gameId,
    required UserModel user,
  }) async {
    try {
      final gameRef = _gamesCollection.doc(gameId.toUpperCase());
      
      final result = await _firestore.runTransaction((transaction) async {
        final gameDoc = await transaction.get(gameRef);
        
        if (!gameDoc.exists) {
          throw Exception('Game not found');
        }

        final gameSession = GameSessionModel.fromMap(gameDoc.data() as Map<String, dynamic>);
        
        if (gameSession.isFull) {
          throw Exception('Game is full');
        }

        if (gameSession.playerIds.contains(user.id)) {
          throw Exception('You are already in this game');
        }

        if (gameSession.status != GameStatus.waitingForPlayers) {
          throw Exception('Game is not accepting new players');
        }

        // Check for duplicate colors
        if (user.playerColor != null) {
          final existingColors = gameSession.players
              .where((p) => p.playerColor != null)
              .map((p) => p.playerColor)
              .toList();
          if (existingColors.contains(user.playerColor!.value)) {
            throw Exception('This color is already taken. Please choose a different color.');
          }
        }

        final player = PlayerInGame(
          userId: user.id,
          displayName: user.displayName,
          emailAddress: user.emailAddress,
          joinedAt: DateTime.now(),
          playerColor: user.playerColor?.value,
        );

        final updatedGame = gameSession.addPlayer(player);
        
        // Check if game is now full and should auto-start
        final shouldAutoStart = updatedGame.players.length >= updatedGame.maxPlayers;
        final finalGame = shouldAutoStart ? updatedGame.startGame() : updatedGame;
        
        transaction.update(gameRef, finalGame.toMap());
        
        return {
          'game': finalGame,
          'autoStarted': shouldAutoStart && gameSession.status == GameStatus.waitingForPlayers,
        };
      });
      
      final finalGame = result['game'] as GameSessionModel;
      final autoStarted = result['autoStarted'] as bool;
      
      // Handle games played increment and game state initialization outside the transaction
      if (autoStarted) {
        try {
          print('DEBUG: Auto-starting game ${finalGame.gameId} - incrementing games played for ${finalGame.playerIds.length} players');
          await FirestoreService.incrementGamesPlayedForUsers(finalGame.playerIds);
          // Initialize game state for the auto-started game
          await GameStateService.initializeGameState(finalGame.gameId, finalGame.playerIds);
        } catch (e) {
          print('Error incrementing games played or initializing game state: $e');
          // Don't fail the join operation if this fails
        }
      }
      
      return finalGame;
    } catch (e) {
      print('Error joining game: $e');
      rethrow;
    }
  }

  // Start a game session
  static Future<GameSessionModel?> startGameSession(String gameId) async {
    try {
      final gameRef = _gamesCollection.doc(gameId.toUpperCase());
      
      final updatedGame = await _firestore.runTransaction((transaction) async {
        final gameDoc = await transaction.get(gameRef);
        
        if (!gameDoc.exists) {
          throw Exception('Game not found');
        }

        final gameSession = GameSessionModel.fromMap(gameDoc.data() as Map<String, dynamic>);
        
        if (!gameSession.canStart) {
          throw Exception('Need at least 1 player to start');
        }

        if (gameSession.status != GameStatus.waitingForPlayers) {
          throw Exception('Game cannot be started');
        }

        final updatedGame = gameSession.startGame();
        transaction.update(gameRef, updatedGame.toMap());
        
        return updatedGame;
      });
      
      // Handle game state initialization outside the transaction
      try {
        print('DEBUG: Manually starting game ${updatedGame.gameId}');
        // Initialize game state when manually starting game
        await GameStateService.initializeGameState(updatedGame.gameId, updatedGame.playerIds);
      } catch (e) {
        print('Error initializing game state: $e');
        // Don't fail the start operation if this fails
      }
      
      return updatedGame;
    } catch (e) {
      print('Error starting game: $e');
      rethrow;
    }
  }

  // End a game session
  static Future<GameSessionModel?> endGameSession({
    required String gameId,
    String? winnerId,
  }) async {
    try {
      final gameRef = _gamesCollection.doc(gameId.toUpperCase());
      
      final updatedGame = await _firestore.runTransaction((transaction) async {
        final gameDoc = await transaction.get(gameRef);
        
        if (!gameDoc.exists) {
          throw Exception('Game not found');
        }

        final gameSession = GameSessionModel.fromMap(gameDoc.data() as Map<String, dynamic>);
        final updatedGame = gameSession.endGame(winnerId: winnerId);
        
        transaction.update(gameRef, updatedGame.toMap());
        
        return updatedGame;
      });
      
      // Only increment games played if the game was completed with a winner
      // (not if teacher ended it early without declaring a winner)
      if (winnerId != null) {
        try {
          print('DEBUG: Game ${updatedGame.gameId} completed with winner - incrementing games played for ${updatedGame.playerIds.length} players');
          await FirestoreService.incrementGamesPlayedForUsers(updatedGame.playerIds);
        } catch (e) {
          print('Error incrementing games played for completed game: $e');
          // Don't fail the end operation if this fails
        }
      } else {
        print('DEBUG: Game ${updatedGame.gameId} ended early by teacher - NOT incrementing games played');
      }
      
      return updatedGame;
    } catch (e) {
      print('Error ending game: $e');
      rethrow;
    }
  }

  // Get games created by admin
  static Future<List<GameSessionModel>> getGamesByAdmin(String adminUserId) async {
    try {
      final query = await _gamesCollection
          .where('createdBy', isEqualTo: adminUserId)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs
          .map((doc) => GameSessionModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting admin games: $e');
      return [];
    }
  }

  // Listen to games created by admin (for real-time updates)
  static Stream<List<GameSessionModel>> listenToGamesByAdmin(String adminUserId) {
    return _gamesCollection
        .where('createdBy', isEqualTo: adminUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => GameSessionModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  // Get active games for a player
  static Future<List<GameSessionModel>> getActiveGamesForPlayer(String userId) async {
    try {
      final query = await _gamesCollection
          .where('playerIds', arrayContains: userId)
          .where('status', whereIn: [
            GameStatus.waitingForPlayers.toString(),
            GameStatus.inProgress.toString()
          ])
          .get();

      return query.docs
          .map((doc) => GameSessionModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting player games: $e');
      return [];
    }
  }

  // Listen to game session updates (for real-time updates)
  static Stream<GameSessionModel?> listenToGameSession(String gameId) {
    return _gamesCollection
        .doc(gameId.toUpperCase())
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return GameSessionModel.fromMap(doc.data() as Map<String, dynamic>);
        });
  }

  // Update player progress in game
  static Future<void> updatePlayerProgress({
    required String gameId,
    required String playerId,
    required int wordsRead,
    bool? isReady,
  }) async {
    try {
      final gameRef = _gamesCollection.doc(gameId.toUpperCase());
      
      await _firestore.runTransaction((transaction) async {
        final gameDoc = await transaction.get(gameRef);
        
        if (!gameDoc.exists) {
          throw Exception('Game not found');
        }

        final gameSession = GameSessionModel.fromMap(gameDoc.data() as Map<String, dynamic>);
        
        final updatedPlayers = gameSession.players.map((player) {
          if (player.userId == playerId) {
            return player.copyWith(
              wordsRead: wordsRead,
              isReady: isReady ?? player.isReady,
            );
          }
          return player;
        }).toList();

        final updatedGame = gameSession.copyWith(players: updatedPlayers);
        transaction.update(gameRef, updatedGame.toMap());
      });
    } catch (e) {
      print('Error updating player progress: $e');
      rethrow;
    }
  }

  // Leave a game session
  static Future<GameSessionModel?> leaveGameSession({
    required String gameId,
    required String playerId,
  }) async {
    try {
      final gameRef = _gamesCollection.doc(gameId.toUpperCase());
      
      return await _firestore.runTransaction((transaction) async {
        final gameDoc = await transaction.get(gameRef);
        
        if (!gameDoc.exists) {
          throw Exception('Game not found');
        }

        final gameSession = GameSessionModel.fromMap(gameDoc.data() as Map<String, dynamic>);
        
        // Remove player from the game
        final updatedPlayers = gameSession.players.where((p) => p.userId != playerId).toList();
        final updatedPlayerIds = gameSession.playerIds.where((id) => id != playerId).toList();
        
        // If no players left, delete the game entirely
        if (updatedPlayers.isEmpty) {
          transaction.delete(gameRef);
          return null; // Game deleted
        }
        
        // Update the game with remaining players
        final updatedGame = gameSession.copyWith(
          players: updatedPlayers,
          playerIds: updatedPlayerIds,
        );
        
        transaction.update(gameRef, updatedGame.toMap());
        
        return updatedGame;
      });
    } catch (e) {
      print('Error leaving game: $e');
      rethrow;
    }
  }

  // Complete a game session (mark as won)
  static Future<GameSessionModel?> completeGameSession({
    required String gameId,
    required String winnerId,
  }) async {
    try {
      GameSessionModel? gameSession;
      
      // First, complete the game session
      gameSession = await _firestore.runTransaction<GameSessionModel?>((transaction) async {
        final docRef = _gamesCollection.doc(gameId.toUpperCase());
        final doc = await transaction.get(docRef);
        
        if (!doc.exists) {
          throw Exception('Game session not found');
        }
        
        final gs = GameSessionModel.fromMap(doc.data() as Map<String, dynamic>);
        
        final updatedGame = gs.copyWith(
          status: GameStatus.completed,
          winnerId: winnerId,
          endedAt: DateTime.now(),
        );
        
        transaction.update(docRef, updatedGame.toMap());
        
        return updatedGame;
      });
      
      // Now update player statistics based on game state
      if (gameSession != null) {
        try {
          // Get game state to calculate word counts for each player
          final gameState = await GameStateService.getGameState(gameId);
          if (gameState != null) {
            final playerWordCounts = <String, int>{};
            
            // Calculate word count for each player
            for (final playerId in gameSession.playerIds) {
              playerWordCounts[playerId] = gameState.getPlayerScore(playerId);
            }
            
            // Update all players' statistics
            await FirestoreService.updatePlayersGameStats(
              playerIds: gameSession.playerIds,
              playerWordCounts: playerWordCounts,
              winnerId: winnerId,
            );
            
            // Increment games played for all players since game was completed
            print('DEBUG: Game ${gameSession.gameId} completed naturally - incrementing games played for ${gameSession.playerIds.length} players');
            await FirestoreService.incrementGamesPlayedForUsers(gameSession.playerIds);
          }
        } catch (e) {
          print('Error updating player stats after game completion: $e');
          // Don't rethrow - game completion should still succeed even if stats update fails
        }
      }
      
      return gameSession;
    } catch (e) {
      print('Error completing game: $e');
      rethrow;
    }
  }

  // Delete a game session
  static Future<void> deleteGameSession(String gameId) async {
    try {
      await _gamesCollection.doc(gameId.toUpperCase()).delete();
    } catch (e) {
      print('Error deleting game: $e');
      rethrow;
    }
  }

  // Get all available games that are waiting for players
  static Future<List<GameSessionModel>> getAvailableGames() async {
    try {
      final query = await _gamesCollection
          .where('status', isEqualTo: GameStatus.waitingForPlayers.toString())
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs
          .map((doc) => GameSessionModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting available games: $e');
      return [];
    }
  }
}