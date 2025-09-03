import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_game_model.dart';
import '../models/user_model.dart';
import 'game_state_service.dart';

class StudentGameService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'student_games';
  
  // Create a new student-friendly game
  static Future<StudentGameModel> createStudentGame({
    required UserModel teacher,
    required int maxPlayers,
    String? customCode,
    String wordListType = 'long_u',
  }) async {
    // Generate a unique game code
    String gameCode = customCode ?? await _generateUniqueGameCode();
    String gameId = _firestore.collection(_collection).doc().id;
    
    final studentGame = StudentGameModel(
      gameId: gameId,
      gameCode: gameCode,
      teacherId: teacher.id,
      teacherName: teacher.displayName,
      players: [],
      gameMode: 'waiting',
      createdAt: DateTime.now(),
      wordListType: wordListType,
      maxPlayers: maxPlayers,
    );
    
    await _firestore
        .collection(_collection)
        .doc(gameId)
        .set(studentGame.toMap());
    
<<<<<<< HEAD
=======
    print('Created student game with code: $gameCode');
>>>>>>> 8fa281c869b61ec6fc67458e87ba6748b80c6078
    return studentGame;
  }
  
  // Find game by code
  static Future<StudentGameModel?> findGameByCode(String gameCode) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('gameCode', isEqualTo: gameCode.toUpperCase())
          .where('gameMode', whereIn: ['waiting', 'active'])
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        return StudentGameModel.fromMap(querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
<<<<<<< HEAD
=======
      print('Error finding game by code: $e');
>>>>>>> 8fa281c869b61ec6fc67458e87ba6748b80c6078
      return null;
    }
  }
  
  // Add player to game with customization
  static Future<Map<String, dynamic>?> addPlayerToGame({
    required String gameCode,
    String? playerName,
    String? avatarColor,
    String? avatarIcon,
  }) async {
    try {
      final game = await findGameByCode(gameCode);
      if (game == null) {
<<<<<<< HEAD
=======
        print('Game not found with code: $gameCode');
>>>>>>> 8fa281c869b61ec6fc67458e87ba6748b80c6078
        return null;
      }
      
      if (game.isFull) {
<<<<<<< HEAD
=======
        print('Game is full');
>>>>>>> 8fa281c869b61ec6fc67458e87ba6748b80c6078
        return null;
      }
      
      // Get next available slot
      final slot = game.nextAvailableSlot;
      if (slot == -1) {
<<<<<<< HEAD
=======
        print('No available slots');
>>>>>>> 8fa281c869b61ec6fc67458e87ba6748b80c6078
        return null;
      }
      
      // Use provided avatar or get default for slot
      final defaultAvatar = _getAvatarForSlot(slot);
      final finalPlayerName = playerName ?? 'Player $slot';
      final finalAvatarColor = avatarColor ?? defaultAvatar['color']!;
      final finalAvatarIcon = avatarIcon ?? defaultAvatar['icon']!;
      
      final playerId = _generatePlayerId();
      final newPlayer = StudentPlayer(
        playerId: playerId,
        playerName: finalPlayerName,
        playerSlot: slot,
        avatarColor: finalAvatarColor,
        avatarIcon: finalAvatarIcon,
        joinedAt: DateTime.now(),
      );
      
      // Update the game with the new player
      final updatedPlayers = [...game.players, newPlayer];
      final updatedGame = game.copyWith(players: updatedPlayers);
      
      await _firestore
          .collection(_collection)
          .doc(game.gameId)
          .update(updatedGame.toMap());
      
<<<<<<< HEAD
=======
      print('Added player ${newPlayer.playerName} to game $gameCode');
>>>>>>> 8fa281c869b61ec6fc67458e87ba6748b80c6078
      return {
        'game': updatedGame,
        'playerId': playerId,
      };
      
    } catch (e) {
<<<<<<< HEAD
=======
      print('Error adding player to game: $e');
>>>>>>> 8fa281c869b61ec6fc67458e87ba6748b80c6078
      return null;
    }
  }
  
  // Start the game
  static Future<bool> startGame(String gameId) async {
    try {
      // Get the game to find all players
      final gameDoc = await _firestore
          .collection(_collection)
          .doc(gameId)
          .get();
      
      if (!gameDoc.exists) {
<<<<<<< HEAD
=======
        print('Game not found: $gameId');
>>>>>>> 8fa281c869b61ec6fc67458e87ba6748b80c6078
        return false;
      }
      
      final game = StudentGameModel.fromMap(gameDoc.data()!);
      final playerIds = game.players.map((p) => p.playerId).toList();
      
      // Initialize shared game state for all players with turn-based settings
      await GameStateService.initializeGameState(gameId, playerIds);
      
      // Update game status to active
      await _firestore
          .collection(_collection)
          .doc(gameId)
          .update({
        'gameMode': 'active',
        'startedAt': Timestamp.fromDate(DateTime.now()),
      });
      
<<<<<<< HEAD
      return true;
    } catch (e) {
=======
      print('Started student game: $gameId with shared state for ${playerIds.length} players');
      return true;
    } catch (e) {
      print('Error starting game: $e');
>>>>>>> 8fa281c869b61ec6fc67458e87ba6748b80c6078
      return false;
    }
  }
  
  // Get games created by teacher
  static Stream<List<StudentGameModel>> getTeacherGames(String teacherId) {
    return _firestore
        .collection(_collection)
        .where('teacherId', isEqualTo: teacherId)
        .where('gameMode', whereIn: ['waiting', 'active'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StudentGameModel.fromMap(doc.data()))
            .toList());
  }
  
  // Get game stream
  static Stream<StudentGameModel?> getGameStream(String gameId) {
    return _firestore
        .collection(_collection)
        .doc(gameId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return StudentGameModel.fromMap(snapshot.data()!);
      }
      return null;
    });
  }
  
  // Delete game
  static Future<bool> deleteGame(String gameId) async {
    try {
      await _firestore.collection(_collection).doc(gameId).delete();
<<<<<<< HEAD
      return true;
    } catch (e) {
=======
      print('Deleted game: $gameId');
      return true;
    } catch (e) {
      print('Error deleting game: $e');
>>>>>>> 8fa281c869b61ec6fc67458e87ba6748b80c6078
      return false;
    }
  }
  
  // Remove player from game
  static Future<bool> removePlayer(String gameId, String playerId) async {
    try {
      final gameDoc = await _firestore.collection(_collection).doc(gameId).get();
      if (!gameDoc.exists) return false;
      
      final game = StudentGameModel.fromMap(gameDoc.data()!);
      final updatedPlayers = game.players.where((p) => p.playerId != playerId).toList();
      
      await _firestore
          .collection(_collection)
          .doc(gameId)
          .update({'players': updatedPlayers.map((p) => p.toMap()).toList()});
      
<<<<<<< HEAD
      return true;
    } catch (e) {
=======
      print('Removed player $playerId from game $gameId');
      return true;
    } catch (e) {
      print('Error removing player: $e');
>>>>>>> 8fa281c869b61ec6fc67458e87ba6748b80c6078
      return false;
    }
  }
  
  // Complete a student game and update teacher stats
  static Future<bool> completeStudentGame({
    required String gameId,
    String? winnerId,
    Map<String, int>? playerWordCounts,
  }) async {
    try {
      // Update the game status to completed
      await _firestore
          .collection(_collection)
          .doc(gameId)
          .update({
            'gameMode': 'completed',
            'endedAt': Timestamp.fromDate(DateTime.now()),
            if (winnerId != null) 'winnerId': winnerId,
          });

      // Get the game to find the teacher
      final gameDoc = await _firestore
          .collection(_collection)
          .doc(gameId)
          .get();

      if (gameDoc.exists) {
        final game = StudentGameModel.fromMap(gameDoc.data()!);
        
        // Update teacher stats
        await _updateTeacherStatsForStudentGame(
          teacherId: game.teacherId,
          playerWordCounts: playerWordCounts ?? {},
          winnerId: winnerId,
          totalPlayers: game.players.length,
        );
        
<<<<<<< HEAD
=======
        print('Completed student game $gameId and updated teacher ${game.teacherId} stats');
>>>>>>> 8fa281c869b61ec6fc67458e87ba6748b80c6078
        return true;
      }
      
      return false;
    } catch (e) {
<<<<<<< HEAD
=======
      print('Error completing student game: $e');
>>>>>>> 8fa281c869b61ec6fc67458e87ba6748b80c6078
      return false;
    }
  }
  
  // Update teacher statistics when a student game ends
  static Future<void> _updateTeacherStatsForStudentGame({
    required String teacherId,
    required Map<String, int> playerWordCounts,
    String? winnerId,
    required int totalPlayers,
  }) async {
    try {
      // Teachers get credit for games managed, not played
      // Count total words read by all players in the game
      final totalWordsRead = playerWordCounts.values.fold<int>(0, (total, words) => total + words);
      
      await _firestore.runTransaction((transaction) async {
        final teacherRef = _firestore.collection('users').doc(teacherId);
        final teacherDoc = await transaction.get(teacherRef);
        
        if (teacherDoc.exists) {
          final currentData = teacherDoc.data() as Map<String, dynamic>;
          final currentGamesPlayed = (currentData['gamesPlayed'] ?? 0) as int;
          final currentWordsCorrect = (currentData['wordsCorrect'] ?? 0) as int;
          final currentGamesWon = (currentData['gamesWon'] ?? 0) as int;
          
          // Update teacher stats:
          // - Increment games managed (using gamesPlayed field)
          // - Add total words read by students
          // - If teacher-facilitated game had a winner, count as a "win" for teaching
          final updates = <String, dynamic>{
            'gamesPlayed': currentGamesPlayed + 1,
            'wordsCorrect': currentWordsCorrect + totalWordsRead,
          };
          
          // For student games, we consider it a "teacher win" if students successfully completed words
          if (totalWordsRead > 0) {
            updates['gamesWon'] = currentGamesWon + 1;
          }
          
          transaction.update(teacherRef, updates);
          
<<<<<<< HEAD
        }
      });
    } catch (e) {
=======
          print('Updated teacher $teacherId stats: +1 game managed, +$totalWordsRead words facilitated');
        }
      });
    } catch (e) {
      print('Error updating teacher stats for student game: $e');
>>>>>>> 8fa281c869b61ec6fc67458e87ba6748b80c6078
    }
  }
  


  // Helper methods
  static Future<String> _generateUniqueGameCode() async {
    for (int attempt = 0; attempt < 10; attempt++) {
      final code = StudentAvatars.generateRandomCode();
      final existing = await findGameByCode(code);
      if (existing == null) {
        return code;
      }
    }
    
    // Fallback: generate a random number-based code
    final random = Random();
    final code = (100 + random.nextInt(900)).toString();
    return code;
  }
  
  static String _generatePlayerId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           Random().nextInt(1000).toString();
  }
  
  static Map<String, String> _getAvatarForSlot(int slot) {
    final avatarIndex = (slot - 1) % StudentAvatars.defaultAvatars.length;
    return StudentAvatars.defaultAvatars[avatarIndex];
  }
}