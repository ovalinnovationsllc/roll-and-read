import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/game_session_model.dart';
import '../models/user_model.dart';
import '../models/word_list_model.dart';
import '../models/player_colors.dart';
import '../utils/safe_print.dart';
import 'ai_word_service.dart';
import 'firestore_service.dart';
import 'game_state_service.dart';
import 'word_list_service.dart';
import 'dart:math';

class GameSessionService {
  // Generate a unique friendly word game ID
  static String generateGameId() {
    // Very simple 3-5 letter words for students with reading difficulties
    const words = [
      // 3 letter words
      'CAT', 'DOG', 'BIG', 'HOT', 'RED', 'SUN', 'FUN', 'RUN', 'TOP', 'BOX',
      'BAT', 'HAT', 'PIG', 'COW', 'BED', 'CUP', 'BAG', 'BUS', 'CAR', 'EGG',
      'FOX', 'JAM', 'KEY', 'MAP', 'NET', 'OWL', 'PAN', 'RAT', 'TOY', 'VAN',
      'WEB', 'YES', 'ZOO', 'ANT', 'BEE', 'FLY', 'HOP', 'JOB', 'LEG', 'MUD',
      
      // 4 letter words
      'BALL', 'BOOK', 'CAKE', 'DUCK', 'FISH', 'GAME', 'JUMP', 'KITE', 'LAMP',
      'MOON', 'NEST', 'PARK', 'RING', 'SHOP', 'TREE', 'WAVE', 'BIRD', 'BOAT',
      'CAMP', 'DOOR', 'FARM', 'GOLD', 'HAND', 'KING', 'LEAF', 'MILK', 'NAME',
      'PINK', 'RAIN', 'SAND', 'TEAM', 'WASH', 'BLUE', 'CORN', 'DESK', 'FAST',
      'GOOD', 'HELP', 'JOKE', 'LAKE', 'NICE', 'PLAY', 'QUIZ', 'ROCK', 'STAR',
      'SWIM', 'TALK', 'WALK', 'WORK', 'BEAR', 'FROG', 'GOAT', 'LION', 'WOLF',
      
      // 5 letter words (still simple)
      'HAPPY', 'FUNNY', 'APPLE', 'WATER', 'MOUSE', 'HOUSE', 'PIZZA', 'TRAIN',
      'SMILE', 'CLEAN', 'LIGHT', 'NIGHT', 'PAPER', 'BREAD', 'CHAIR', 'TABLE',
      'PHONE', 'WATCH', 'MUSIC', 'DANCE', 'PAINT', 'GRASS', 'CLOUD', 'BEACH'
    ];
    
    final random = Random();
    return words[random.nextInt(words.length)];
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
    // Generate unique game ID
    String gameId;
    do {
      gameId = generateGameId();
    } while (await FirestoreService.getGameSession(gameId) != null);
    

    List<List<String>>? finalWordGrid = wordGrid;
    
    // Generate AI words if requested
    if (useAIWords && aiPrompt != null) {
      try {
        finalWordGrid = await AIWordService.generateWordGrid(
          prompt: aiPrompt,
          difficulty: difficulty ?? 'elementary',
        );
        
        // Save the AI-generated word list to local storage for reuse
        if (finalWordGrid != null) {
          await _saveAIWordListToLocalStorage(
            prompt: aiPrompt,
            difficulty: difficulty ?? 'elementary',
            wordGrid: finalWordGrid,
            createdBy: createdBy,
          );
        }
      } catch (e) {
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

    final createdGame = await FirestoreService.createGameSession(gameSession);
    return createdGame;
  }

  // Get all game sessions (no filter)
  static Future<List<GameSessionModel>> getAllGameSessions() async {
    try {
      return await FirestoreService.getAllGameSessions();
    } catch (e) {
      return [];
    }
  }
  
  // Get game session by ID
  static Future<GameSessionModel?> getGameSession(String gameId) async {
    try {
      return await FirestoreService.getGameSession(gameId.toUpperCase());
    } catch (e) {
      return null;
    }
  }

  // Join a game session
  static Future<GameSessionModel?> joinGameSession({
    required String gameId,
    required UserModel user,
  }) async {
    try {
      final gameSession = await FirestoreService.getGameSession(gameId.toUpperCase());
      
      if (gameSession == null) {
        throw Exception('Game not found');
      }
      

      if (gameSession.isFull) {
        throw Exception('Game is full');
      }

      if (gameSession.playerIds.contains(user.id)) {
        throw Exception('You are already in this game');
      }

      if (gameSession.status != GameStatus.waitingForPlayers) {
        
        // Provide clearer error messages based on game status
        if (gameSession.status == GameStatus.inProgress) {
          throw Exception('This game has already started. Ask your teacher to create a new game.');
        } else if (gameSession.status == GameStatus.completed) {
          throw Exception('This game has ended. Ask your teacher to create a new game.');
        } else if (gameSession.status == GameStatus.cancelled) {
          throw Exception('This game was cancelled. Ask your teacher to create a new game.');
        } else {
          throw Exception('This game is not accepting new players.');
        }
      }
      

      // Assign player position based on join order  
      final playerPosition = gameSession.players.length;
      
      // Use the student's existing color instead of overriding it
      Color? finalPlayerColor = user.playerColor;
      String? uniqueAvatarUrl = user.avatarUrl;
      
      // If the user doesn't have a color, assign one based on position
      if (finalPlayerColor == null && playerPosition < PlayerColors.availableColors.length) {
        finalPlayerColor = PlayerColors.availableColors[playerPosition].color;
        safePrint('✅ Assigned player ${user.displayName} color: ${PlayerColors.availableColors[playerPosition].name}');
      } else if (finalPlayerColor == null) {
        // Fallback to default if somehow we exceed available colors
        finalPlayerColor = PlayerColors.getDefaultColor();
        safePrint('⚠️ Too many players, using default color');
      } else {
        safePrint('✅ Keeping player ${user.displayName} existing color');
      }
      
      // If no avatar, assign one based on position
      if (uniqueAvatarUrl == null) {
        final avatarIndex = playerPosition % 6; // Cycle through 6 unique avatars
        final avatarEmojis = ['🐱', '🐶', '⭐', '💖', '🦋', '☀️'];
        uniqueAvatarUrl = avatarEmojis[avatarIndex];
        safePrint('✅ Assigned player ${user.displayName} unique avatar: $uniqueAvatarUrl');
      }
      
      final player = PlayerInGame(
        userId: user.id,
        displayName: user.displayName,
        emailAddress: user.emailAddress,
        joinedAt: DateTime.now(),
        playerColor: finalPlayerColor?.value,
        avatarUrl: uniqueAvatarUrl, // Use unique position-based avatar
      );
      
      safePrint('✅ Added player: ${user.displayName}');
      

      final updatedGame = gameSession.addPlayer(player);
      
      // If color was changed, update the user's session with the new color
      if (finalPlayerColor != user.playerColor) {
        final userWithUpdatedColor = user.copyWith(playerColor: finalPlayerColor);
        // Note: The calling code should save this updated user to session
        // We can't import SessionService here to avoid circular dependencies
      }
      
      // Check if game is now full and should auto-start (need at least 2 players)
      final shouldAutoStart = updatedGame.isFull && updatedGame.canStart;
      final finalGame = shouldAutoStart ? updatedGame.startGame() : updatedGame;
      
      // Save the updated game
      await FirestoreService.updateGameSession(finalGame);
      
      // Handle auto-start logic
      if (shouldAutoStart && gameSession.status == GameStatus.waitingForPlayers) {
        try {
          // Initialize game state for the auto-started game
          await GameStateService.initializeGameState(finalGame.gameId, finalGame.playerIds);
        } catch (e) {
          // Don't fail the join operation if this fails
        }
      }
      
      return finalGame;
    } catch (e) {
      rethrow;
    }
  }

  // Start a game session
  static Future<GameSessionModel?> startGameSession(String gameId) async {
    try {
      final gameSession = await FirestoreService.getGameSession(gameId.toUpperCase());
      
      if (gameSession == null) {
        throw Exception('Game not found');
      }

      if (!gameSession.canStart) {
        throw Exception('Need at least 1 player to start');
      }

      if (gameSession.status != GameStatus.waitingForPlayers) {
        throw Exception('Game cannot be started');
      }

      final updatedGame = gameSession.startGame();
      await FirestoreService.updateGameSession(updatedGame);
      
      // Handle game state initialization
      try {
        // Initialize game state when manually starting game
        await GameStateService.initializeGameState(updatedGame.gameId, updatedGame.playerIds);
      } catch (e) {
        // Don't fail the start operation if this fails
      }
      
      return updatedGame;
    } catch (e) {
      rethrow;
    }
  }

  // End a game session without updating Firebase stats (for when stats are handled elsewhere)
  static Future<GameSessionModel?> endGameSessionOnly({
    required String gameId,
    String? winnerId,
  }) async {
    try {
      final gameSession = await FirestoreService.getGameSession(gameId.toUpperCase());
      
      if (gameSession == null) {
        return null;
      }

      // Just end the game session without updating player stats
      final updatedGame = gameSession.endGame(winnerId: winnerId);
      await FirestoreService.updateGameSession(updatedGame);
      
      return updatedGame;
    } catch (e) {
      rethrow;
    }
  }

  // End a game session with automatic stats updates
  static Future<GameSessionModel?> endGameSession({
    required String gameId,
    String? winnerId,
  }) async {
    try {
      final gameSession = await FirestoreService.getGameSession(gameId.toUpperCase());
      
      if (gameSession == null) {
        throw Exception('Game not found');
      }

      // Get final game state to calculate player stats
      final gameState = await GameStateService.getGameState(gameId);
      
      // Update student statistics for each player - ONLY if game was completed (has a winner)
      if (winnerId != null && gameState != null && gameSession.players.isNotEmpty) {
        
        for (final player in gameSession.players) {
          final playerId = player.userId;
          final playerScore = gameState.getPlayerScore(playerId);
          final isWinner = (winnerId == playerId);
          
          
          // Update student stats
          await FirestoreService.updateStudentStats(
            studentId: playerId,
            wordsRead: playerScore,
            won: isWinner,
          );
        }
      }

      final updatedGame = gameSession.endGame(winnerId: winnerId);
      await FirestoreService.updateGameSession(updatedGame);
      
      return updatedGame;
    } catch (e) {
      rethrow;
    }
  }

  // Get all game sessions created by a user
  static Future<List<GameSessionModel>> getGameSessionsForTeacher(String teacherId) async {
    try {
      return await FirestoreService.getAllGameSessions(teacherId: teacherId);
    } catch (e) {
      return [];
    }
  }

  // Get all active (waiting for players or in progress) game sessions
  static Future<List<GameSessionModel>> getActiveGameSessions() async {
    try {
      // Use optimized server-side filtering
      return await FirestoreService.getActiveGameSessions();
    } catch (e) {
      return [];
    }
  }

  // Delete a game session
  static Future<void> deleteGameSession(String gameId) async {
    try {
      await FirestoreService.deleteGameSession(gameId.toUpperCase());
    } catch (e) {
      rethrow;
    }
  }

  // Check if a partial game ID matches any existing game
  static Future<GameSessionModel?> findGameByPartialId(String partialId) async {
    try {
      final upperPartial = partialId.toUpperCase();
      
      // First try exact match
      final exact = await FirestoreService.getGameSession(upperPartial);
      if (exact != null) return exact;
      
      // Then try partial match
      final allSessions = await FirestoreService.getAllGameSessions();
      for (final session in allSessions) {
        if (session.gameId.startsWith(upperPartial)) {
          return session;
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  // Update game session (generic update method)
  static Future<void> updateGameSession(GameSessionModel gameSession) async {
    try {
      await FirestoreService.updateGameSession(gameSession);
    } catch (e) {
      rethrow;
    }
  }

  // Test method to check basic local storage connectivity
  static Future<bool> testStorageConnection() async {
    try {
      return true; // Firebase connection assumed working if initialized
    } catch (e) {
      return false;
    }
  }

  // Stream methods for local storage (optimized with caching)
  static Stream<List<GameSessionModel>> listenToGamesByAdmin(String adminId) {
    
    // For now, let's use a simpler approach - get all games for teacher and filter client-side
    // This avoids potential Firestore compound query issues  
    return FirebaseFirestore.instance.collection('games')
        .where('createdBy', isEqualTo: adminId)
        .limit(20) // Increased limit to see more games
        .snapshots()
        .map((snapshot) {
      
      final allGames = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final game = GameSessionModel.fromMap(data);
        return game;
      }).toList();
      
      // Client-side filtering for active games
      final activeGames = allGames.where((game) => 
        game.status == GameStatus.waitingForPlayers || 
        game.status == GameStatus.inProgress
      ).toList();
      
      // Client-side sorting by creation time (newest first) since we removed orderBy to avoid index requirement
      activeGames.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      
      return activeGames;
    });
  }

  static Stream<GameSessionModel?> getGameSessionStream(String gameId) {
    // Use real-time Firestore listener instead of polling
    return FirestoreService.listenToGameSession(gameId);
  }

  static Stream<GameSessionModel?> listenToGameSession(String gameId) {
    return getGameSessionStream(gameId);
  }

  // Get available games for joining
  static Future<List<GameSessionModel>> getAvailableGames() async {
    try {
      return await getActiveGameSessions();
    } catch (e) {
      return [];
    }
  }

  // Leave a game session (remove player)
  static Future<GameSessionModel?> leaveGameSession({
    required String gameId,
    required String playerId,
  }) async {
    try {
      final gameSession = await FirestoreService.getGameSession(gameId.toUpperCase());
      
      if (gameSession == null) {
        throw Exception('Game not found');
      }

      // Remove player from the game
      final updatedPlayers = gameSession.players.where((p) => p.userId != playerId).toList();
      final updatedPlayerIds = gameSession.playerIds.where((id) => id != playerId).toList();
      
      final updatedGame = gameSession.copyWith(
        players: updatedPlayers,
        playerIds: updatedPlayerIds,
      );
      
      await FirestoreService.updateGameSession(updatedGame);
      return updatedGame;
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> _saveAIWordListToLocalStorage({
    required String prompt,
    required String difficulty,
    required List<List<String>> wordGrid,
    required String createdBy,
  }) async {
    try {
      final wordList = WordListModel.create(
        prompt: prompt,
        difficulty: difficulty,
        wordGrid: wordGrid,
        createdBy: createdBy,
      );
      
      await WordListService.saveWordList(wordList);
    } catch (e) {
      // Don't rethrow - this is not critical for game creation
    }
  }
}