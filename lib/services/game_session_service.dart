import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_session_model.dart';
import '../models/user_model.dart';
import 'ai_word_service.dart';
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

    // Generate AI words if requested
    List<List<String>>? wordGrid;
    if (useAIWords && aiPrompt != null && aiPrompt.isNotEmpty) {
      try {
        wordGrid = await AIWordService.generateWordGrid(
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
      wordGrid: wordGrid,
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
      
      return await _firestore.runTransaction((transaction) async {
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

        final player = PlayerInGame(
          userId: user.id,
          displayName: user.displayName,
          emailAddress: user.emailAddress,
          joinedAt: DateTime.now(),
        );

        final updatedGame = gameSession.addPlayer(player);
        transaction.update(gameRef, updatedGame.toMap());
        
        return updatedGame;
      });
    } catch (e) {
      print('Error joining game: $e');
      rethrow;
    }
  }

  // Start a game session
  static Future<GameSessionModel?> startGameSession(String gameId) async {
    try {
      final gameRef = _gamesCollection.doc(gameId.toUpperCase());
      
      return await _firestore.runTransaction((transaction) async {
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
        
        // Initialize game state for real-time multiplayer
        await GameStateService.initializeGameState(
          gameSession.gameId,
          gameSession.playerIds,
        );
        
        return updatedGame;
      });
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
      
      return await _firestore.runTransaction((transaction) async {
        final gameDoc = await transaction.get(gameRef);
        
        if (!gameDoc.exists) {
          throw Exception('Game not found');
        }

        final gameSession = GameSessionModel.fromMap(gameDoc.data() as Map<String, dynamic>);
        final updatedGame = gameSession.endGame(winnerId: winnerId);
        
        transaction.update(gameRef, updatedGame.toMap());
        
        // Clean up game state
        await GameStateService.deleteGameState(gameSession.gameId);
        
        return updatedGame;
      });
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

  // Delete a game session
  static Future<void> deleteGameSession(String gameId) async {
    try {
      await _gamesCollection.doc(gameId.toUpperCase()).delete();
      // Also clean up the game state
      await GameStateService.deleteGameState(gameId);
    } catch (e) {
      print('Error deleting game: $e');
      rethrow;
    }
  }
}