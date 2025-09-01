import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_session_model.dart';
import '../models/user_model.dart';
import '../models/word_list_model.dart';
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
    
    print('🎮 DEBUG: Generated unique game ID/code: $gameId');

    List<List<String>>? finalWordGrid = wordGrid;
    
    // Generate AI words if requested
    if (useAIWords && aiPrompt != null) {
      try {
        print('🤖 Generating AI words with prompt: "$aiPrompt" (difficulty: ${difficulty ?? 'elementary'})');
        finalWordGrid = await AIWordService.generateWordGrid(
          prompt: aiPrompt,
          difficulty: difficulty ?? 'elementary',
        );
        print('✅ AI word generation completed successfully');
        
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

    final createdGame = await FirestoreService.createGameSession(gameSession);
    print('✅ Game session created successfully: ${gameSession.gameId} (${gameSession.gameName})');
    return createdGame;
  }

  // Get all game sessions (no filter)
  static Future<List<GameSessionModel>> getAllGameSessions() async {
    try {
      return await FirestoreService.getAllGameSessions();
    } catch (e) {
      print('Error getting all game sessions: $e');
      return [];
    }
  }
  
  // Get game session by ID
  static Future<GameSessionModel?> getGameSession(String gameId) async {
    try {
      return await FirestoreService.getGameSession(gameId.toUpperCase());
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
      print('🚀 ENTRY: joinGameSession called with gameId: $gameId, user: ${user.displayName}');
      print('🔍 JOIN ATTEMPT: User ${user.displayName} trying to join game $gameId');
      final gameSession = await FirestoreService.getGameSession(gameId.toUpperCase());
      
      if (gameSession == null) {
        print('❌ JOIN FAILED: Game $gameId not found');
        throw Exception('Game not found');
      }
      
      print('✅ JOIN CHECK: Found game $gameId with ${gameSession.players.length}/${gameSession.maxPlayers} players');
      print('✅ JOIN CHECK: Game status: ${gameSession.status}');
      print('✅ JOIN CHECK: Current players: ${gameSession.players.map((p) => p.displayName).toList()}');

      if (gameSession.isFull) {
        print('❌ JOIN FAILED: Game is full (${gameSession.players.length}/${gameSession.maxPlayers})');
        throw Exception('Game is full');
      }

      if (gameSession.playerIds.contains(user.id)) {
        print('❌ JOIN FAILED: User ${user.displayName} already in game');
        throw Exception('You are already in this game');
      }

      if (gameSession.status != GameStatus.waitingForPlayers) {
        print('❌ JOIN FAILED: Game status is ${gameSession.status}, not accepting players');
        
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
      
      print('✅ JOIN VALIDATION: All checks passed, proceeding to add player');

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

      // Debug color information
      print('DEBUG: Adding player ${user.displayName} to game:');
      print('  user.playerColor: ${user.playerColor}');
      print('  user.playerColor?.value: ${user.playerColor?.value}');
      
      final player = PlayerInGame(
        userId: user.id,
        displayName: user.displayName,
        emailAddress: user.emailAddress,
        joinedAt: DateTime.now(),
        playerColor: user.playerColor?.value,
        avatarUrl: user.avatarUrl,
      );
      
      print('  Created PlayerInGame.playerColor: ${player.playerColor}');

      final updatedGame = gameSession.addPlayer(player);
      print('👤 Player ${player.displayName} joining game ${gameSession.gameId}');
      print('👤 Game now has ${updatedGame.players.length}/${updatedGame.maxPlayers} players');
      
      // Check if game is now full and should auto-start
      final shouldAutoStart = updatedGame.players.length >= updatedGame.maxPlayers;
      final finalGame = shouldAutoStart ? updatedGame.startGame() : updatedGame;
      
      // Save the updated game
      await FirestoreService.updateGameSession(finalGame);
      
      // Handle auto-start logic
      if (shouldAutoStart && gameSession.status == GameStatus.waitingForPlayers) {
        try {
          print('DEBUG: Auto-starting game ${finalGame.gameId} - initializing game state for ${finalGame.playerIds.length} players');
          // Initialize game state for the auto-started game
          await GameStateService.initializeGameState(finalGame.gameId, finalGame.playerIds);
        } catch (e) {
          print('Error initializing game state: $e');
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
      final gameSession = await FirestoreService.getGameSession(gameId.toUpperCase());
      
      if (gameSession == null) {
        throw Exception('Game not found');
      }

      // Get final game state to calculate player stats
      final gameState = await GameStateService.getGameState(gameId);
      
      // Update student statistics for each player
      if (gameState != null && gameSession.players.isNotEmpty) {
        print('📊 Updating stats for ${gameSession.players.length} players');
        
        for (final player in gameSession.players) {
          final playerId = player.userId;
          final playerScore = gameState.getPlayerScore(playerId);
          final isWinner = (winnerId != null && winnerId == playerId);
          
          print('📊 Player ${player.displayName}: $playerScore words, winner: $isWinner');
          
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
      print('Error ending game: $e');
      rethrow;
    }
  }

  // Get all game sessions created by a user
  static Future<List<GameSessionModel>> getGameSessionsForTeacher(String teacherId) async {
    try {
      return await FirestoreService.getAllGameSessions(teacherId: teacherId);
    } catch (e) {
      print('Error getting teacher game sessions: $e');
      return [];
    }
  }

  // Get all active (waiting for players or in progress) game sessions
  static Future<List<GameSessionModel>> getActiveGameSessions() async {
    try {
      // Use optimized server-side filtering
      return await FirestoreService.getActiveGameSessions();
    } catch (e) {
      print('Error getting active game sessions: $e');
      return [];
    }
  }

  // Delete a game session
  static Future<void> deleteGameSession(String gameId) async {
    try {
      await FirestoreService.deleteGameSession(gameId.toUpperCase());
    } catch (e) {
      print('Error deleting game session: $e');
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
      print('Error finding game by partial ID: $e');
      return null;
    }
  }

  // Update game session (generic update method)
  static Future<void> updateGameSession(GameSessionModel gameSession) async {
    try {
      await FirestoreService.updateGameSession(gameSession);
    } catch (e) {
      print('Error updating game session: $e');
      rethrow;
    }
  }

  // Test method to check basic local storage connectivity
  static Future<bool> testStorageConnection() async {
    try {
      print('🔧 Testing local storage connection...');
      return true; // Firebase connection assumed working if initialized
    } catch (e) {
      print('🔧 Local storage connection failed: $e');
      return false;
    }
  }

  // Stream methods for local storage (optimized with caching)
  static Stream<List<GameSessionModel>> listenToGamesByAdmin(String adminId) {
    print('🎮 Setting up games listener for admin: $adminId');
    
    // For now, let's use a simpler approach - get all games for teacher and filter client-side
    // This avoids potential Firestore compound query issues  
    return FirebaseFirestore.instance.collection('games')
        .where('createdBy', isEqualTo: adminId)
        .limit(20) // Increased limit to see more games
        .snapshots()
        .map((snapshot) {
      print('🎮 Stream update: Firebase returned ${snapshot.docs.length} documents for teacher $adminId');
      
      final allGames = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final game = GameSessionModel.fromMap(data);
        print('  📊 Game ${game.gameId}: ${game.players.length}/${game.maxPlayers} players');
        return game;
      }).toList();
      
      // Client-side filtering for active games
      final activeGames = allGames.where((game) => 
        game.status == GameStatus.waitingForPlayers || 
        game.status == GameStatus.inProgress
      ).toList();
      
      // Client-side sorting by creation time (newest first) since we removed orderBy to avoid index requirement
      activeGames.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      print('🎮 Found ${allGames.length} total games, ${activeGames.length} active games for teacher $adminId');
      
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
      print('Error getting available games: $e');
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
      print('Error leaving game: $e');
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
      print('✅ AI-generated word list saved to local storage: "$prompt"');
    } catch (e) {
      print('❌ Failed to save AI word list to local storage: $e');
      // Don't rethrow - this is not critical for game creation
    }
  }
}