import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/student_model.dart';
import '../models/game_session_model.dart';
import '../models/game_state_model.dart';
import '../models/word_list_model.dart';
import '../utils/safe_print.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _usersCollection = _firestore.collection('users');
  static final CollectionReference _studentsCollection = _firestore.collection('students');
  static final CollectionReference _gamesCollection = _firestore.collection('games');
  static final CollectionReference _gameStatesCollection = _firestore.collection('gameStates');
  static final CollectionReference _wordListsCollection = _firestore.collection('wordLists');
  
  // Flag to track if Firebase is properly initialized
  static bool _isFirebaseReady = false;
  
  /// Set Firebase ready status (called after successful initialization)
  static void setFirebaseReady(bool ready) {
    _isFirebaseReady = ready;
  }
  
  /// Check if Firebase operations are safe to perform
  static bool get isFirebaseReady => _isFirebaseReady;
  
  /// Alias for isFirebaseReady (for compatibility)
  static bool get isInitialized => _isFirebaseReady;

  /// Check if a user exists and is an admin by email
  static Future<bool> checkAdminByEmail(String email) async {
    try {
      final QuerySnapshot querySnapshot = await _usersCollection
          .where('emailAddress', isEqualTo: email.toLowerCase().trim())
          .where('isAdmin', isEqualTo: true)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      safePrint('Error checking admin status: ${e.runtimeType} - ${e.toString()}');
      return false;
    }
  }

  /// Get user by email
  static Future<UserModel?> getUserByEmail(String email) async {
    if (!_isFirebaseReady) {
      safePrint('Firebase not ready, returning null for getUserByEmail');
      return null;
    }
    
    try {
      final cleanEmail = email.toLowerCase().trim();
      safePrint('🔍 FirestoreService: Looking up user with email: "$cleanEmail"');
      
      final QuerySnapshot querySnapshot = await _usersCollection
          .where('emailAddress', isEqualTo: cleanEmail)
          .limit(1)
          .get();

      safePrint('🔍 FirestoreService: Found ${querySnapshot.docs.length} documents');
      
      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        safePrint('🔍 FirestoreService: User found - ${data['displayName']} (${data['emailAddress']})');
        return UserModel.fromMap(data);
      }
      
      safePrint('🔍 FirestoreService: No user found with email: "$cleanEmail"');
      return null;
    } catch (e) {
      // Handle Firebase web interop issues by catching all exceptions
      safePrint('Error getting user by email: ${e.runtimeType} - ${e.toString()}');
      return null;
    }
  }

  /// Create a new user
  static Future<UserModel?> createUser({
    required String email,
    required String displayName,
    required String pin,
    bool isAdmin = false,
  }) async {
    try {
      final docRef = _usersCollection.doc();
      
      final user = UserModel.create(
        id: docRef.id,
        displayName: displayName,
        emailAddress: email.toLowerCase().trim(),
        pin: pin,
        isAdmin: isAdmin,
      );

      await docRef.set(user.toMap());
      return user;
    } catch (e) {
      print('Error creating user: $e');
      return null;
    }
  }

  /// Update user data
  static Future<bool> updateUser(UserModel user) async {
    try {
      await _usersCollection
          .doc(user.id)
          .update(user.toMap());
      return true;
    } catch (e) {
      print('Error updating user: $e');
      return false;
    }
  }

  /// Get all users (admin only)
  static Stream<List<UserModel>> getAllUsers() {
    return _usersCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return UserModel.fromMap(data);
      }).toList();
    });
  }

  /// Delete user (admin only)
  static Future<bool> deleteUser(String userId) async {
    try {
      await _usersCollection
          .doc(userId)
          .delete();
      return true;
    } catch (e) {
      print('Error deleting user: $e');
      return false;
    }
  }

  /// Get user statistics (admin only)
  static Future<Map<String, dynamic>> getUserStatistics() async {
    try {
      final QuerySnapshot snapshot = await _usersCollection.get();

      int totalUsers = snapshot.docs.length;
      int totalGamesPlayed = 0;
      int totalWordsCorrect = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalGamesPlayed += (data['gamesPlayed'] ?? 0) as int;
        totalWordsCorrect += (data['wordsCorrect'] ?? 0) as int;
      }

      return {
        'totalUsers': totalUsers,
        'totalGamesPlayed': totalGamesPlayed,
        'totalWordsCorrect': totalWordsCorrect,
        'averageGamesPerUser': totalUsers > 0 ? totalGamesPlayed / totalUsers : 0,
        'averageWordsPerUser': totalUsers > 0 ? totalWordsCorrect / totalUsers : 0,
      };
    } catch (e) {
      print('Error getting statistics: $e');
      return {
        'totalUsers': 0,
        'totalGamesPlayed': 0,
        'totalWordsCorrect': 0,
        'averageGamesPerUser': 0,
        'averageWordsPerUser': 0,
      };
    }
  }

  // Update user statistics
  static Future<void> incrementUserWordsCorrect(String userId) async {
    try {
      print('DEBUG: Incrementing words correct for user $userId');
      await _firestore.runTransaction((transaction) async {
        final docRef = _usersCollection.doc(userId);
        final doc = await transaction.get(docRef);
        
        if (doc.exists) {
          final currentWordsCorrect = (doc.data() as Map<String, dynamic>)['wordsCorrect'] ?? 0;
          print('DEBUG: Current wordsCorrect: $currentWordsCorrect, incrementing to ${currentWordsCorrect + 1}');
          transaction.update(docRef, {
            'wordsCorrect': currentWordsCorrect + 1,
          });
          print('DEBUG: Successfully updated wordsCorrect for user $userId');
        } else {
          print('DEBUG: User document does not exist for $userId');
        }
      });
    } catch (e) {
      print('Error incrementing words correct: $e');
    }
  }

  // Update all players' statistics when game completes
  static Future<void> updatePlayersGameStats({
    required List<String> playerIds,
    required Map<String, int> playerWordCounts,
    required String? winnerId,
  }) async {
    try {
      print('DEBUG: Updating game stats for players: $playerIds');
      print('DEBUG: Word counts: $playerWordCounts');
      print('DEBUG: Winner: $winnerId');

      await _firestore.runTransaction((transaction) async {
        for (final playerId in playerIds) {
          final docRef = _usersCollection.doc(playerId);
          final doc = await transaction.get(docRef);
          
          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            final currentWordsCorrect = data['wordsCorrect'] ?? 0;
            final currentGamesWon = data['gamesWon'] ?? 0;
            final wordsToAdd = playerWordCounts[playerId] ?? 0;
            
            print('DEBUG: Player $playerId - current words: $currentWordsCorrect, adding: $wordsToAdd');
            
            final updates = <String, dynamic>{
              'wordsCorrect': currentWordsCorrect + wordsToAdd,
            };
            
            // Increment games won for the winner
            if (playerId == winnerId) {
              updates['gamesWon'] = currentGamesWon + 1;
              print('DEBUG: Player $playerId won - incrementing games won to ${currentGamesWon + 1}');
            }
            
            transaction.update(docRef, updates);
          } else {
            print('DEBUG: User document does not exist for player $playerId');
          }
        }
      });
      
      print('DEBUG: Successfully updated game stats for all players');
    } catch (e) {
      print('Error updating players game stats: $e');
      rethrow;
    }
  }

  static Future<void> incrementUserGamesPlayed(String userId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _usersCollection.doc(userId);
        final doc = await transaction.get(docRef);
        
        if (doc.exists) {
          final currentGamesPlayed = (doc.data() as Map<String, dynamic>)['gamesPlayed'] ?? 0;
          transaction.update(docRef, {
            'gamesPlayed': currentGamesPlayed + 1,
          });
        }
      });
    } catch (e) {
      print('Error incrementing games played: $e');
    }
  }

  static Future<void> incrementUserGamesWon(String userId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _usersCollection.doc(userId);
        final doc = await transaction.get(docRef);
        
        if (doc.exists) {
          final currentGamesWon = (doc.data() as Map<String, dynamic>)['gamesWon'] ?? 0;
          transaction.update(docRef, {
            'gamesWon': currentGamesWon + 1,
          });
        }
      });
    } catch (e) {
      print('Error incrementing games won: $e');
    }
  }

  // Batch update multiple users' games played (when a game starts)
  static Future<void> incrementGamesPlayedForUsers(List<String> userIds) async {
    try {
      print('DEBUG: Incrementing games played for users: $userIds');
      final batch = _firestore.batch();
      
      for (String userId in userIds) {
        final docRef = _usersCollection.doc(userId);
        // We can't read in a batch, so we'll use FieldValue.increment
        batch.update(docRef, {
          'gamesPlayed': FieldValue.increment(1),
        });
        print('DEBUG: Added increment for user $userId to batch');
      }
      
      await batch.commit();
      print('DEBUG: Successfully committed batch increment for games played');
    } catch (e) {
      print('Error batch incrementing games played: $e');
    }
  }

  // Set user words correct to exact count (for final game statistics)
  static Future<void> updateUserWordsCorrect(String userId, int totalWords) async {
    try {
      print('DEBUG: Setting words correct for user $userId to $totalWords');
      await _usersCollection.doc(userId).update({
        'wordsCorrect': FieldValue.increment(totalWords),
      });
      print('DEBUG: Successfully updated wordsCorrect to $totalWords for user $userId');
    } catch (e) {
      print('Error updating words correct: $e');
    }
  }

  // ========== STUDENT MANAGEMENT ==========
  
  /// Get all active students (for simple tap-to-play)
  static Future<List<StudentModel>> getAllActiveStudents() async {
    try {
      final QuerySnapshot snapshot = await _studentsCollection
          .where('isActive', isEqualTo: true)
          .orderBy('displayName')
          .get();
      
      return snapshot.docs
          .map((doc) => StudentModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting active students: $e');
      return [];
    }
  }

  /// Create a new student
  static Future<StudentModel?> createStudent({
    required String teacherId,
    required String displayName,
    required String avatarUrl,
    required Color playerColor,
  }) async {
    try {
      final docRef = _studentsCollection.doc();
      final now = DateTime.now();
      
      final student = StudentModel(
        studentId: docRef.id,
        teacherId: teacherId,
        displayName: displayName,
        avatarUrl: avatarUrl,
        playerColor: playerColor,
        createdAt: now,
        lastPlayedAt: now,
      );

      final studentMap = student.toMap();

      // Create student document
      await docRef.set(studentMap);
      
      // Also create a user document so the student can be used in games
      final user = UserModel.create(
        id: student.studentId,
        displayName: displayName,
        emailAddress: '${student.studentId}@student.local',
        pin: '0000',
        isAdmin: false,
        playerColor: playerColor,
        avatarUrl: avatarUrl,
      );
      
      await _usersCollection.doc(student.studentId).set(user.toMap());
      
      return student;
    } catch (e) {
      print('Error creating student: $e');
      return null;
    }
  }

  /// Update student statistics after a game
  static Future<void> updateStudentStats({
    required String studentId,
    required int wordsRead,
    bool won = false,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _studentsCollection.doc(studentId);
        final doc = await transaction.get(docRef);
        
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final currentGamesPlayed = data['gamesPlayed'] ?? 0;
          final currentGamesWon = data['gamesWon'] ?? 0;
          final currentWordsRead = data['wordsRead'] ?? 0;
          
          transaction.update(docRef, {
            'gamesPlayed': currentGamesPlayed + 1,
            'gamesWon': currentGamesWon + (won ? 1 : 0),
            'wordsRead': currentWordsRead + wordsRead,
            'lastPlayedAt': Timestamp.fromDate(DateTime.now()),
          });
        }
      });
    } catch (e) {
      print('Error updating student stats: $e');
    }
  }

  /// Get students for a specific teacher
  static Future<List<StudentModel>> getStudentsForTeacher(String teacherId) async {
    try {
      final QuerySnapshot snapshot = await _studentsCollection
          .where('teacherId', isEqualTo: teacherId)
          .where('isActive', isEqualTo: true)
          .orderBy('displayName')
          .get();
      
      return snapshot.docs
          .map((doc) => StudentModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting students for teacher: $e');
      return [];
    }
  }

  /// Delete student
  static Future<bool> deleteStudent(String studentId) async {
    try {
      await _studentsCollection.doc(studentId).update({'isActive': false});
      return true;
    } catch (e) {
      print('Error deleting student: $e');
      return false;
    }
  }

  /// Fix existing students by creating missing user documents
  static Future<void> fixExistingStudents() async {
    try {
      final QuerySnapshot studentsSnapshot = await _studentsCollection
          .where('isActive', isEqualTo: true)
          .get();
      
      for (final doc in studentsSnapshot.docs) {
        final student = StudentModel.fromMap(doc.data() as Map<String, dynamic>);
        
        // Check if user document exists
        final userDoc = await _usersCollection.doc(student.studentId).get();
        if (!userDoc.exists) {
          // Create missing user document
          final user = UserModel.create(
            id: student.studentId,
            displayName: student.displayName,
            emailAddress: '${student.studentId}@student.local',
            pin: '0000',
            isAdmin: false,
            playerColor: student.playerColor,
          );
          
          await _usersCollection.doc(student.studentId).set(user.toMap());
          print('Created missing user document for student: ${student.displayName}');
        }
      }
    } catch (e) {
      print('Error fixing existing students: $e');
    }
  }

  /// Create sample students for demo purposes
  static Future<void> createSampleStudents(String teacherId) async {
    try {
      final sampleStudents = [
        {'name': 'Emma', 'avatar': 'E', 'color': Colors.pink},
        {'name': 'Liam', 'avatar': 'L', 'color': Colors.blue},
        {'name': 'Sophia', 'avatar': 'S', 'color': Colors.purple},
        {'name': 'Noah', 'avatar': 'N', 'color': Colors.green},
        {'name': 'Olivia', 'avatar': 'O', 'color': Colors.orange},
        {'name': 'Mason', 'avatar': 'M', 'color': Colors.brown},
        {'name': 'Ava', 'avatar': 'A', 'color': Colors.red},
        {'name': 'Lucas', 'avatar': 'C', 'color': Colors.teal},
      ];

      for (final student in sampleStudents) {
        await createStudent(
          teacherId: teacherId,
          displayName: student['name'] as String,
          avatarUrl: student['avatar'] as String,
          playerColor: student['color'] as Color,
        );
      }
    } catch (e) {
      print('Error creating sample students: $e');
    }
  }

  // ========== GAME SESSION METHODS ==========
  
  /// Get game session by ID
  static Future<GameSessionModel?> getGameSession(String gameId) async {
    try {
      final doc = await _gamesCollection.doc(gameId.toUpperCase()).get();
      if (doc.exists) {
        return GameSessionModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting game session: $e');
      return null;
    }
  }

  /// Update game session
  static Future<void> updateGameSession(GameSessionModel gameSession) async {
    try {
      print('🔄 Updating game session ${gameSession.gameId} with ${gameSession.players.length} players');
      await _gamesCollection.doc(gameSession.gameId.toUpperCase()).set(gameSession.toMap());
      print('✅ Game session ${gameSession.gameId} updated successfully');
    } catch (e) {
      print('Error updating game session: $e');
      rethrow;
    }
  }

  /// Get all game sessions
  static Future<List<GameSessionModel>> getAllGameSessions({String? teacherId}) async {
    try {
      Query query = _gamesCollection;
      if (teacherId != null) {
        query = query.where('createdBy', isEqualTo: teacherId);
      }
      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => GameSessionModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting all game sessions: $e');
      return [];
    }
  }

  /// Get only active games (server-side filtering for performance)
  static Future<List<GameSessionModel>> getActiveGameSessions({String? teacherId}) async {
    try {
      Query query = _gamesCollection;
      
      if (teacherId != null) {
        query = query.where('createdBy', isEqualTo: teacherId);
      }
      
      // Server-side filter for active games only
      query = query.where('status', whereIn: [
        GameStatus.waitingForPlayers.toString(),
        GameStatus.inProgress.toString(),
      ]);
      
      // Order by creation time (newest first) and limit for performance
      query = query.orderBy('createdAt', descending: true).limit(10);
      
      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => GameSessionModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting active game sessions: $e');
      return [];
    }
  }

  /// Get active games stream (real-time updates)
  static Stream<List<GameSessionModel>> listenToActiveGames({String? teacherId}) {
    print('🔍 Setting up active games listener for teacher: $teacherId');
    
    Query query = _gamesCollection;
    
    if (teacherId != null) {
      query = query.where('createdBy', isEqualTo: teacherId);
      print('🔍 Added teacher filter: createdBy == $teacherId');
    }
    
    // Server-side filter for active games only
    final statusFilters = [
      GameStatus.waitingForPlayers.toString(),
      GameStatus.inProgress.toString(),
    ];
    query = query.where('status', whereIn: statusFilters);
    print('🔍 Added status filter: status in $statusFilters');
    
    // Order by creation time (newest first) and limit for performance  
    query = query.orderBy('createdAt', descending: true).limit(10);
    print('🔍 Added ordering and limit: createdAt desc, limit 10');
    
    return query.snapshots().map((snapshot) {
      print('🔍 Firebase query returned ${snapshot.docs.length} documents');
      final games = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            print('🔍 Game doc ${doc.id}: status=${data['status']}, createdBy=${data['createdBy']}');
            return GameSessionModel.fromMap(data);
          })
          .toList();
      print('🔍 Parsed ${games.length} GameSessionModel objects');
      return games;
    });
  }

  /// Listen to a specific game session (real-time updates)
  static Stream<GameSessionModel?> listenToGameSession(String gameId) {
    final upperGameId = gameId.toUpperCase();
    print('🎧 Setting up stream listener for game: $upperGameId');
    
    return _gamesCollection
        .doc(upperGameId)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            final game = GameSessionModel.fromMap(doc.data() as Map<String, dynamic>);
            print('🎧 Stream update for $upperGameId: ${game.players.length}/${game.maxPlayers} players');
            return game;
          }
          print('🎧 Stream update for $upperGameId: Game document not found');
          return null;
        });
  }

  // ========== GAME STATE METHODS ==========
  
  /// Save game state
  static Future<void> saveGameState(GameStateModel gameState) async {
    try {
      await _gameStatesCollection.doc(gameState.gameId.toUpperCase()).set(gameState.toMap());
    } catch (e) {
      print('Error saving game state: $e');
      rethrow;
    }
  }

  /// Get game state
  static Future<GameStateModel?> getGameState(String gameId) async {
    try {
      final doc = await _gameStatesCollection.doc(gameId.toUpperCase()).get();
      if (doc.exists) {
        return GameStateModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting game state: $e');
      return null;
    }
  }

  /// Update game state
  static Future<void> updateGameState(GameStateModel gameState) async {
    try {
      final gameStateMap = gameState.toMap();
      print('🔥 FIRESTORE DEBUG: Updating game state ${gameState.gameId}');
      print('  currentDiceValue being sent: ${gameStateMap['currentDiceValue']}');
      print('  currentTurnPlayerId being sent: ${gameStateMap['currentTurnPlayerId']}');
      
      await _gameStatesCollection.doc(gameState.gameId.toUpperCase()).set(gameStateMap);
      print('✅ FIRESTORE: Game state updated successfully');
    } catch (e) {
      print('Error updating game state: $e');
      rethrow;
    }
  }

  /// Delete game state
  static Future<void> deleteGameState(String gameId) async {
    try {
      await _gameStatesCollection.doc(gameId.toUpperCase()).delete();
    } catch (e) {
      print('Error deleting game state: $e');
      rethrow;
    }
  }

  // ========== WORD LIST METHODS ==========
  
  /// Save word list
  static Future<WordListModel> saveWordList(WordListModel wordList) async {
    try {
      final docRef = _wordListsCollection.doc();
      final wordListWithId = wordList.copyWith(id: docRef.id);
      await docRef.set(wordListWithId.toMap());
      return wordListWithId;
    } catch (e) {
      print('Error saving word list: $e');
      rethrow;
    }
  }

  /// Get all word lists
  static Future<List<WordListModel>> getAllWordLists() async {
    try {
      final snapshot = await _wordListsCollection.get();
      return snapshot.docs
          .map((doc) => WordListModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting all word lists: $e');
      return [];
    }
  }

  /// Get word lists by difficulty
  static Future<List<WordListModel>> getWordListsByDifficulty(String difficulty) async {
    try {
      final snapshot = await _wordListsCollection
          .where('difficulty', isEqualTo: difficulty)
          .get();
      return snapshot.docs
          .map((doc) => WordListModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting word lists by difficulty: $e');
      return [];
    }
  }

  /// Search word lists
  static Future<List<WordListModel>> searchWordLists(String searchQuery) async {
    try {
      final snapshot = await _wordListsCollection
          .where('prompt', isGreaterThanOrEqualTo: searchQuery)
          .where('prompt', isLessThan: searchQuery + 'z')
          .get();
      return snapshot.docs
          .map((doc) => WordListModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error searching word lists: $e');
      return [];
    }
  }

  /// Get word list by ID
  static Future<WordListModel?> getWordList(String id) async {
    try {
      final doc = await _wordListsCollection.doc(id).get();
      if (doc.exists) {
        return WordListModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting word list: $e');
      return null;
    }
  }

  /// Increment word list usage
  static Future<void> incrementWordListUsage(String wordListId) async {
    try {
      await _wordListsCollection.doc(wordListId).update({
        'usageCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error incrementing word list usage: $e');
    }
  }

  /// Delete word list
  static Future<void> deleteWordList(String id) async {
    try {
      await _wordListsCollection.doc(id).delete();
    } catch (e) {
      print('Error deleting word list: $e');
      rethrow;
    }
  }

  /// Get popular word lists
  static Future<List<WordListModel>> getPopularWordLists({int limit = 10}) async {
    try {
      final snapshot = await _wordListsCollection
          .orderBy('usageCount', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs
          .map((doc) => WordListModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting popular word lists: $e');
      return [];
    }
  }

  /// Find existing word list
  static Future<WordListModel?> findExistingWordList(String prompt, String difficulty) async {
    try {
      final snapshot = await _wordListsCollection
          .where('prompt', isEqualTo: prompt)
          .where('difficulty', isEqualTo: difficulty)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return WordListModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error finding existing word list: $e');
      return null;
    }
  }

  /// Test connection (for compatibility)
  static Future<bool> testConnection() async {
    try {
      await _firestore.doc('test/connection').get();
      return true;
    } catch (e) {
      print('Error testing connection: $e');
      return false;
    }
  }

  /// Create game session (for compatibility)
  static Future<GameSessionModel> createGameSession(GameSessionModel gameSession) async {
    try {
      await _gamesCollection.doc(gameSession.gameId.toUpperCase()).set(gameSession.toMap());
      return gameSession;
    } catch (e) {
      print('Error creating game session: $e');
      rethrow;
    }
  }

  /// Delete game session
  static Future<void> deleteGameSession(String gameId) async {
    try {
      await _gamesCollection.doc(gameId.toUpperCase()).delete();
    } catch (e) {
      print('Error deleting game session: $e');
      rethrow;
    }
  }

  /// Update player stats (games played, won, words correct)
  static Future<void> updatePlayerStats({
    required String playerId,
    required int gamesPlayed,
    required int gamesWon,
    required int wordsCorrect,
  }) async {
    try {
      print('📊 Updating stats for player $playerId: +$gamesPlayed games, +$gamesWon wins, +$wordsCorrect words');
      
      // Try to find player in students collection first
      final studentDoc = await _studentsCollection.doc(playerId).get();
      if (studentDoc.exists) {
        await _studentsCollection.doc(playerId).update({
          'gamesPlayed': FieldValue.increment(gamesPlayed),
          'gamesWon': FieldValue.increment(gamesWon),
          'wordsRead': FieldValue.increment(wordsCorrect),
          'lastGameAt': FieldValue.serverTimestamp(),
        });
        print('✅ Updated student stats for $playerId');
        return;
      }

      // Try users collection as fallback
      final userDoc = await _usersCollection.doc(playerId).get();
      if (userDoc.exists) {
        await _usersCollection.doc(playerId).update({
          'gamesPlayed': FieldValue.increment(gamesPlayed),
          'gamesWon': FieldValue.increment(gamesWon),
          'wordsCorrect': FieldValue.increment(wordsCorrect),
          'lastGameAt': FieldValue.serverTimestamp(),
        });
        print('✅ Updated user stats for $playerId');
        return;
      }

      print('⚠️ Player $playerId not found in students or users collections');
    } catch (e) {
      print('❌ Error updating player stats: $e');
      rethrow;
    }
  }
}