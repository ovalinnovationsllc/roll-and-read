import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/student_model.dart';
import '../models/game_session_model.dart';
import '../models/game_state_model.dart';
import '../models/word_list_model.dart';
import '../models/player_colors.dart';
import '../utils/safe_print.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _usersCollection = _firestore.collection('users');
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

  /// Get user by Firebase UID (for Firebase Auth integration)
  static Future<UserModel?> getUserById(String uid) async {
    if (!_isFirebaseReady) {
      safePrint('Firebase not ready, returning null for getUserById');
      return null;
    }

    try {
      safePrint('🔍 FirestoreService: Looking for user with UID: "$uid"');
      
      final doc = await _usersCollection.doc(uid).get();
      
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        safePrint('🔍 FirestoreService: User found by UID - ${data['displayName']} (${data['emailAddress']})');
        return UserModel.fromMap(data);
      }
      
      safePrint('🔍 FirestoreService: No user found with UID: "$uid"');
      return null;
    } catch (e) {
      safePrint('Error getting user by UID: ${e.runtimeType} - ${e.toString()}');
      return null;
    }
  }

  /// Create a new teacher with Firebase UID (requires Firebase Auth account)
  static Future<UserModel?> createTeacherWithFirebaseUID({
    required String firebaseUID,
    required String email,
    required String displayName,
  }) async {
    try {
      safePrint('🔄 Creating teacher with Firebase UID: $firebaseUID');
      final docRef = _usersCollection.doc(firebaseUID);
      
      final user = UserModel.createTeacher(
        id: firebaseUID,
        displayName: displayName,
        emailAddress: email.toLowerCase().trim(),
        pin: null, // No PIN needed for Firebase Auth teachers
      );

      safePrint('📝 Writing teacher data to Firestore: ${user.toMap()}');
      await docRef.set(user.toMap());
      safePrint('✅ Successfully created teacher in Firestore');
      return user;
    } catch (e) {
      safePrint('❌ Error creating teacher in Firestore: $e');
      rethrow; // Re-throw the error so the caller can handle it
    }
  }

  /// Create a new user (legacy method - deprecated, use createTeacherWithFirebaseUID)
  static Future<UserModel?> createUser({
    required String email,
    required String displayName,
    required String pin,
    bool isAdmin = false,
  }) async {
    try {
      final docRef = _usersCollection.doc();
      
      final user = UserModel.createTeacher(
        id: docRef.id,
        displayName: displayName,
        emailAddress: email.toLowerCase().trim(),
        pin: pin,
      );

      await docRef.set(user.toMap());
      return user;
    } catch (e) {
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
      await _firestore.runTransaction((transaction) async {
        final docRef = _usersCollection.doc(userId);
        final doc = await transaction.get(docRef);
        
        if (doc.exists) {
          final currentWordsCorrect = (doc.data() as Map<String, dynamic>)['wordsCorrect'] ?? 0;
          transaction.update(docRef, {
            'wordsCorrect': currentWordsCorrect + 1,
          });
        } else {
        }
      });
    } catch (e) {
    }
  }

  // Update all players' statistics when game completes
  static Future<void> updatePlayersGameStats({
    required List<String> playerIds,
    required Map<String, int> playerWordCounts,
    required String? winnerId,
  }) async {
    try {

      await _firestore.runTransaction((transaction) async {
        for (final playerId in playerIds) {
          final docRef = _usersCollection.doc(playerId);
          final doc = await transaction.get(docRef);
          
          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            final currentWordsCorrect = data['wordsCorrect'] ?? 0;
            final currentGamesWon = data['gamesWon'] ?? 0;
            final wordsToAdd = playerWordCounts[playerId] ?? 0;
            
            
            final updates = <String, dynamic>{
              'wordsCorrect': currentWordsCorrect + wordsToAdd,
            };
            
            // Increment games won for the winner
            if (playerId == winnerId) {
              updates['gamesWon'] = currentGamesWon + 1;
            }
            
            transaction.update(docRef, updates);
          } else {
          }
        }
      });
      
    } catch (e) {
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
    }
  }

  // Batch update multiple users' games played (when a game starts)
  static Future<void> incrementGamesPlayedForUsers(List<String> userIds) async {
    try {
      final batch = _firestore.batch();
      
      for (String userId in userIds) {
        final docRef = _usersCollection.doc(userId);
        // We can't read in a batch, so we'll use FieldValue.increment
        batch.update(docRef, {
          'gamesPlayed': FieldValue.increment(1),
        });
      }
      
      await batch.commit();
    } catch (e) {
    }
  }

  // Set user words correct to exact count (for final game statistics)
  static Future<void> updateUserWordsCorrect(String userId, int totalWords) async {
    try {
      await _usersCollection.doc(userId).update({
        'wordsCorrect': FieldValue.increment(totalWords),
      });
    } catch (e) {
    }
  }

  // ========== STUDENT MANAGEMENT ==========
  
  /// Get all active students (for simple tap-to-play) - now from users collection
  static Future<List<StudentModel>> getAllActiveStudents() async {
    try {
      final QuerySnapshot snapshot = await _usersCollection
          .where('isAdmin', isEqualTo: false)  // Students are non-admin users
          .orderBy('displayName')
          .get();
      
      return snapshot.docs
          .map((doc) {
            try {
              final userData = doc.data() as Map<String, dynamic>;
              final user = UserModel.fromMap(userData);
              // Convert UserModel to StudentModel for backward compatibility
              return StudentModel(
                studentId: user.id,
                teacherId: user.teacherId ?? '',
                displayName: user.displayName,
                avatarUrl: user.avatarUrl ?? '🙂',
                playerColor: user.playerColor ?? Colors.blue,
                createdAt: user.createdAt,
                lastPlayedAt: user.lastPlayedAt ?? user.createdAt,
                gamesPlayed: user.gamesPlayed,
                gamesWon: user.gamesWon,
                wordsRead: user.wordsRead,
              );
            } catch (e) {
              safePrint('❌ Error converting document ${doc.id} to StudentModel in getAllActiveStudents: $e');
              // Return null to filter out invalid documents
              return null;
            }
          })
          .where((student) => student != null)
          .cast<StudentModel>()
          .toList();
    } catch (e) {
      safePrint('❌ Error in getAllActiveStudents: $e');
      return [];
    }
  }

  /// Create a new student (now creates only in users collection)
  static Future<StudentModel?> createStudent({
    required String teacherId,
    required String displayName,
    required String avatarUrl,
    required Color playerColor,
    bool enforceUniqueness = true,
  }) async {
    try {
      // Check for uniqueness if enforced
      if (enforceUniqueness) {
        final existingStudents = await getStudentsForTeacher(teacherId);
        
        // Check for duplicate color
        final colorExists = existingStudents.any((student) => 
          student.playerColor?.value == playerColor.value);
        if (colorExists) {
          return null; // Color already taken
        }
        
        // Check for duplicate avatar
        final avatarExists = existingStudents.any((student) => 
          student.avatarUrl == avatarUrl);
        if (avatarExists) {
          return null; // Avatar already taken
        }
      }
      
      // Generate new ID for the student
      final docRef = _usersCollection.doc();
      final now = DateTime.now();
      
      // Create user document directly (no more students collection)
      final user = UserModel.createStudent(
        id: docRef.id,
        displayName: displayName,
        teacherId: teacherId,
        playerColor: playerColor,
        avatarUrl: avatarUrl,
      );
      
      await _usersCollection.doc(docRef.id).set(user.toMap());
      
      // Return a StudentModel for backward compatibility
      final student = StudentModel(
        studentId: docRef.id,
        teacherId: teacherId,
        displayName: displayName,
        avatarUrl: avatarUrl,
        playerColor: playerColor,
        createdAt: now,
        lastPlayedAt: now,
      );
      
      return student;
    } catch (e) {
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
        final docRef = _usersCollection.doc(studentId);
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
    }
  }

  /// Get available (unused) colors for a teacher's students
  static Future<List<Color>> getAvailableColors(String teacherId) async {
    final existingStudents = await getStudentsForTeacher(teacherId);
    
    // Check if teacher has reached the maximum student limit
    if (existingStudents.length >= PlayerColors.maxStudentsPerTeacher) {
      return []; // No more students allowed
    }
    
    final usedColors = existingStudents
        .where((student) => student.playerColor != null)
        .map((student) => student.playerColor!)
        .toSet();
    
    // Return colors from PlayerColors up to the configured limit that aren't used
    final availableColorsForStudents = PlayerColors.getAvailableColorsForStudents();
    final allColors = availableColorsForStudents.map((pc) => pc.color).toList();
    return allColors.where((color) => !usedColors.contains(color)).toList();
  }
  
  /// Get available (unused) avatars for a teacher's students
  static Future<List<String>> getAvailableAvatars(String teacherId) async {
    final existingStudents = await getStudentsForTeacher(teacherId);
    final usedAvatars = existingStudents
        .where((student) => student.avatarUrl != null)
        .map((student) => student.avatarUrl!)
        .toSet();
    
    // Common avatar emojis - 30 total to match color limit
    const allAvatars = [
      // Animals (8)
      '🐱', '🐶', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', 
      // Symbols (8)
      '⭐', '💖', '🦋', '☀️', '🌙', '🌈', '🎯', '🎨',
      // Food (8)
      '🍎', '🍊', '🍋', '🍇', '🍓', '🥝', '🍪', '🎂',
      // Additional 6 avatars
      '🚀', '🎭', '🎪', '🎲', '🎸', '⚽'
    ];
    
    return allAvatars.where((avatar) => !usedAvatars.contains(avatar)).toList();
  }

  /// Get students for a specific teacher - now from users collection
  static Future<List<StudentModel>> getStudentsForTeacher(String teacherId) async {
    try {
      final QuerySnapshot snapshot = await _usersCollection
          .where('teacherId', isEqualTo: teacherId)
          .where('isAdmin', isEqualTo: false)  // Students are non-admin users
          .orderBy('displayName')
          .get();
      
      return snapshot.docs
          .map((doc) {
            final userData = doc.data() as Map<String, dynamic>;
            final user = UserModel.fromMap(userData);
            // Convert UserModel to StudentModel for backward compatibility
            // Skip students without proper color assignment (shouldn't happen with new system)
            if (user.playerColor == null) {
              safePrint('⚠️ Student ${user.displayName} has no color assigned, skipping');
              return null;
            }
            
            return StudentModel(
              studentId: user.id,
              teacherId: user.teacherId ?? '',
              displayName: user.displayName,
              avatarUrl: user.avatarUrl ?? '🙂',
              playerColor: user.playerColor!,
              createdAt: user.createdAt,
              lastPlayedAt: user.lastPlayedAt ?? user.createdAt,
              gamesPlayed: user.gamesPlayed,
              gamesWon: user.gamesWon,
              wordsRead: user.wordsRead,
            );
          })
          .where((student) => student != null)
          .map((student) => student!)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Listen to active students for a specific teacher (real-time) - now from users collection
  static Stream<List<StudentModel>> listenToActiveStudents({String? teacherId}) {
    // Simplified query - just get all non-admin users and filter client-side to avoid index issues
    Query query = _usersCollection.where('isAdmin', isEqualTo: false).orderBy('displayName');
    
    return query.snapshots().map((snapshot) {
      try {
        final allStudents = snapshot.docs
            .map((doc) {
              try {
                final userData = doc.data() as Map<String, dynamic>;
                final user = UserModel.fromMap(userData);
                // Convert UserModel to StudentModel for backward compatibility
                return StudentModel(
                  studentId: user.id,
                  teacherId: user.teacherId ?? '',
                  displayName: user.displayName,
                  avatarUrl: user.avatarUrl ?? '🙂',
                  playerColor: user.playerColor ?? Colors.blue,
                  createdAt: user.createdAt,
                  lastPlayedAt: user.lastPlayedAt ?? user.createdAt,
                  gamesPlayed: user.gamesPlayed,
                  gamesWon: user.gamesWon,
                  wordsRead: user.wordsRead,
                );
              } catch (e) {
                safePrint('❌ Error converting document ${doc.id} to StudentModel: $e');
                // Return null to filter out invalid documents
                return null;
              }
            })
            .where((student) => student != null)
            .map((student) => student!)
            .toList();
            
        // Client-side filter by teacherId if specified
        if (teacherId != null) {
          return allStudents.where((student) => student.teacherId == teacherId).toList();
        }
        
        return allStudents;
      } catch (e) {
        safePrint('❌ Error in listenToActiveStudents stream: $e');
        return <StudentModel>[];
      }
    });
  }

  /// NEW: Listen to students from users collection (consolidated approach)
  static Stream<List<UserModel>> listenToStudentsFromUsers({String? teacherId}) {
    Query query = _usersCollection.where('isAdmin', isEqualTo: false);
    
    if (teacherId != null) {
      query = query.where('teacherId', isEqualTo: teacherId);
    }
    
    query = query.orderBy('displayName');
    
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  /// Delete student - now updates users collection
  static Future<bool> deleteStudent(String studentId) async {
    try {
      // Since users collection doesn't have isActive, we actually delete the document
      await _usersCollection.doc(studentId).delete();
      return true;
    } catch (e) {
      return false;
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
      return null;
    }
  }

  /// Update game session
  static Future<void> updateGameSession(GameSessionModel gameSession) async {
    try {
      await _gamesCollection.doc(gameSession.gameId.toUpperCase()).set(gameSession.toMap());
    } catch (e) {
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
      return [];
    }
  }

  /// Get active games stream (real-time updates)
  static Stream<List<GameSessionModel>> listenToActiveGames({String? teacherId}) {
    
    Query query = _gamesCollection;
    
    if (teacherId != null) {
      query = query.where('createdBy', isEqualTo: teacherId);
    }
    
    // Server-side filter for active games only
    final statusFilters = [
      GameStatus.waitingForPlayers.toString(),
      GameStatus.inProgress.toString(),
    ];
    query = query.where('status', whereIn: statusFilters);
    
    // Order by creation time (newest first) and limit for performance  
    query = query.orderBy('createdAt', descending: true).limit(10);
    
    return query.snapshots().map((snapshot) {
      final games = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return GameSessionModel.fromMap(data);
          })
          .toList();
      return games;
    });
  }

  /// Listen to a specific game session (real-time updates)
  static Stream<GameSessionModel?> listenToGameSession(String gameId) {
    final upperGameId = gameId.toUpperCase();
    
    return _gamesCollection
        .doc(upperGameId)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            final game = GameSessionModel.fromMap(doc.data() as Map<String, dynamic>);
            return game;
          }
          return null;
        });
  }

  /// Get completed games from the past 5 days
  static Future<List<GameSessionModel>> getCompletedGames({String? teacherId}) async {
    try {
      // Calculate date 5 days ago
      final fiveDaysAgo = DateTime.now().subtract(const Duration(days: 5));
      final fiveDaysAgoTimestamp = Timestamp.fromDate(fiveDaysAgo);
      
      Query query = _gamesCollection;
      
      if (teacherId != null) {
        query = query.where('createdBy', isEqualTo: teacherId);
      }
      
      // Filter for completed games only
      query = query.where('status', isEqualTo: GameStatus.completed.toString());
      
      // Don't filter by endedAt initially - let's see all completed games first
      // query = query.where('endedAt', isGreaterThan: fiveDaysAgoTimestamp);
      
      // Order by creation time (newest first) since endedAt might not be indexed
      query = query.orderBy('createdAt', descending: true);
      
      final snapshot = await query.get();
      final allGames = snapshot.docs
          .map((doc) => GameSessionModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
      
      // Filter in memory for games completed in the last 5 days
      final recentGames = allGames.where((game) {
        if (game.endedAt == null) return false;
        return game.endedAt!.isAfter(fiveDaysAgo);
      }).toList();
      
      // Sort by endedAt in memory
      recentGames.sort((a, b) => (b.endedAt ?? b.createdAt).compareTo(a.endedAt ?? a.createdAt));
      
      return recentGames;
    } catch (e) {
      return [];
    }
  }

  // ========== GAME STATE METHODS ==========
  
  /// Save game state
  static Future<void> saveGameState(GameStateModel gameState) async {
    try {
      await _gameStatesCollection.doc(gameState.gameId.toUpperCase()).set(gameState.toMap());
    } catch (e) {
      rethrow;
    }
  }

  /// Get game state
  static Future<GameStateModel?> getGameState(String gameId) async {
    try {
      final doc = await _gameStatesCollection.doc(gameId.toUpperCase()).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data();
        if (data is Map<String, dynamic>) {
          return GameStateModel.fromMap(data);
        } else {
          print('⚠️ Game state data is not a Map<String, dynamic>: ${data.runtimeType}');
          return null;
        }
      }
      return null;
    } catch (e) {
      print('⚠️ Error getting game state: $e');
      return null;
    }
  }

  /// Update game state
  static Future<void> updateGameState(GameStateModel gameState) async {
    try {
      final gameStateMap = gameState.toMap();
      
      await _gameStatesCollection.doc(gameState.gameId.toUpperCase()).set(gameStateMap);
    } catch (e) {
      rethrow;
    }
  }

  /// Delete game state
  static Future<void> deleteGameState(String gameId) async {
    try {
      await _gameStatesCollection.doc(gameId.toUpperCase()).delete();
    } catch (e) {
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
    }
  }

  /// Delete word list
  static Future<void> deleteWordList(String id) async {
    try {
      await _wordListsCollection.doc(id).delete();
    } catch (e) {
      rethrow;
    }
  }
  
  /// Update word list
  static Future<void> updateWordList(WordListModel wordList) async {
    try {
      await _wordListsCollection.doc(wordList.id).update(wordList.toMap());
    } catch (e) {
      rethrow;
    }
  }

  /// Update student color
  static Future<void> updateStudentColor(String studentId, Color newColor) async {
    try {
      await _usersCollection.doc(studentId).update({
        'playerColor': newColor.value,
      });
    } catch (e) {
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
      return null;
    }
  }

  /// Test connection (for compatibility)
  static Future<bool> testConnection() async {
    try {
      await _firestore.doc('test/connection').get();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Create game session (for compatibility)
  static Future<GameSessionModel> createGameSession(GameSessionModel gameSession) async {
    try {
      await _gamesCollection.doc(gameSession.gameId.toUpperCase()).set(gameSession.toMap());
      return gameSession;
    } catch (e) {
      rethrow;
    }
  }

  /// Delete game session
  static Future<void> deleteGameSession(String gameId) async {
    try {
      final gameDocId = gameId.toUpperCase();
      final gameDoc = _gamesCollection.doc(gameDocId);
      
      // Delete all subcollections first
      await _deleteSubcollections(gameDoc);
      
      // Also delete the corresponding gameState if it exists
      try {
        await _gameStatesCollection.doc(gameDocId).delete();
        print('🗑️ Deleted gameState for game: $gameDocId');
      } catch (e) {
        print('⚠️ No gameState to delete for game: $gameDocId');
        // Continue - not all games have gameStates
      }
      
      // Then delete the main game document
      await gameDoc.delete();
      print('🗑️ Deleted game session: $gameDocId');
    } catch (e) {
      print('❌ Error deleting game session: $e');
      rethrow;
    }
  }
  
  /// Helper method to delete all subcollections of a game document
  static Future<void> _deleteSubcollections(DocumentReference gameDoc) async {
    try {
      // List of subcollections to delete
      final subcollectionNames = ['word_generation_logs', 'analytics'];
      
      for (final collectionName in subcollectionNames) {
        try {
          final subcollection = gameDoc.collection(collectionName);
          
          // Get all documents in the subcollection
          final snapshot = await subcollection.get();
          
          if (snapshot.docs.isNotEmpty) {
            print('🗑️ Deleting ${snapshot.docs.length} documents from $collectionName');
            
            // Delete each document in the subcollection
            for (final doc in snapshot.docs) {
              await doc.reference.delete();
            }
            
            print('✅ Deleted all documents from $collectionName');
          } else {
            print('📝 No documents found in $collectionName subcollection');
          }
        } catch (e) {
          print('⚠️ Error deleting $collectionName subcollection: $e');
          // Continue with other subcollections
        }
      }
    } catch (e) {
      print('⚠️ Error deleting subcollections: $e');
      // Don't rethrow - we want to continue with deleting the main document
    }
  }

  /// Clean up completed games older than 5 days
  static Future<void> cleanupOldCompletedGames() async {
    try {
      safePrint('🧹 Starting cleanup of old completed games...');
      
      // Cleanup running without Firebase Auth (pre-migration mode)
      safePrint('🔐 Cleanup running in pre-migration mode (no Firebase Auth required)');
      final fiveDaysAgo = DateTime.now().subtract(const Duration(days: 5));
      final cutoffTimestamp = Timestamp.fromDate(fiveDaysAgo);
      safePrint('🗓️ Cleaning games completed before: ${fiveDaysAgo.toString()}');
      
      // Get completed games older than 5 days
      final snapshot = await _gamesCollection
          .where('status', isEqualTo: GameStatus.completed.toString())
          .where('endedAt', isLessThan: cutoffTimestamp)
          .get();
      
      safePrint('📊 Found ${snapshot.docs.length} old completed games to clean up');
      
      if (snapshot.docs.isEmpty) {
        safePrint('✨ No old games to clean up');
        return;
      }
      
      // Delete in batches (Firestore limit is 500 operations per batch)
      const batchSize = 400; // Leave some margin
      final docs = snapshot.docs;
      int totalDeleted = 0;
      
      for (int i = 0; i < docs.length; i += batchSize) {
        final batch = _firestore.batch();
        final endIndex = (i + batchSize < docs.length) ? i + batchSize : docs.length;
        
        for (int j = i; j < endIndex; j++) {
          final doc = docs[j];
          batch.delete(doc.reference);
          
          // Also clean up corresponding game state if it exists
          final gameStateRef = _gameStatesCollection.doc(doc.id);
          batch.delete(gameStateRef);
        }
        
        await batch.commit();
        totalDeleted += (endIndex - i);
        safePrint('🗑️ Deleted batch ${(i ~/ batchSize) + 1}: ${totalDeleted}/${docs.length} games cleaned');
      }
      
      safePrint('✅ Successfully cleaned up $totalDeleted old games and their states');
      
    } catch (e) {
      safePrint('❌ Error during game cleanup: ${e.toString()}');
    }
  }

  /// Clean up all old data (games, game states)
  static Future<void> performMaintenanceCleanup() async {
    try {
      safePrint('🚀 Starting maintenance cleanup...');
      final stopwatch = Stopwatch()..start();
      
      await Future.wait([
        cleanupOldCompletedGames(),
        _cleanupOrphanedGameStates(),
      ]);
      
      stopwatch.stop();
      safePrint('⏱️ Maintenance cleanup completed in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      safePrint('❌ Error during maintenance cleanup: ${e.toString()}');
    }
  }


  /// Clean up game states that no longer have corresponding games
  static Future<void> _cleanupOrphanedGameStates() async {
    try {
      safePrint('🔍 Checking for orphaned game states...');
      
      // Cleanup running without Firebase Auth (pre-migration mode)
      safePrint('🔐 Cleanup running in pre-migration mode (no Firebase Auth required)');
      final gameStatesSnapshot = await _gameStatesCollection.get();
      safePrint('📊 Found ${gameStatesSnapshot.docs.length} total game states to check');
      
      if (gameStatesSnapshot.docs.isEmpty) {
        safePrint('✨ No game states found');
        return;
      }
      
      const batchSize = 400;
      final docs = gameStatesSnapshot.docs;
      int totalOrphaned = 0;
      int totalChecked = 0;
      
      for (int i = 0; i < docs.length; i += batchSize) {
        final batch = _firestore.batch();
        final endIndex = (i + batchSize < docs.length) ? i + batchSize : docs.length;
        int orphanedInBatch = 0;
        
        for (int j = i; j < endIndex; j++) {
          final gameStateDoc = docs[j];
          final gameId = gameStateDoc.id;
          
          // Check if corresponding game exists
          final gameDoc = await _gamesCollection.doc(gameId).get();
          if (!gameDoc.exists) {
            // Game doesn't exist, delete the orphaned game state
            batch.delete(gameStateDoc.reference);
            orphanedInBatch++;
          }
          totalChecked++;
        }
        
        if (orphanedInBatch > 0) {
          await batch.commit();
          totalOrphaned += orphanedInBatch;
          safePrint('🗑️ Cleaned $orphanedInBatch orphaned states in batch ${(i ~/ batchSize) + 1}');
        }
      }
      
      if (totalOrphaned > 0) {
        safePrint('✅ Successfully cleaned up $totalOrphaned orphaned game states (checked $totalChecked total)');
      } else {
        safePrint('✨ No orphaned game states found (checked $totalChecked states)');
      }
    } catch (e) {
      safePrint('❌ Error during orphaned game states cleanup: ${e.toString()}');
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
      
      // Update user in users collection
      final userDoc = await _usersCollection.doc(playerId).get();
      if (userDoc.exists) {
        await _usersCollection.doc(playerId).update({
          'gamesPlayed': FieldValue.increment(gamesPlayed),
          'gamesWon': FieldValue.increment(gamesWon),
          'wordsCorrect': FieldValue.increment(wordsCorrect),
          'lastGameAt': FieldValue.serverTimestamp(),
        });
        return;
      }

    } catch (e) {
      rethrow;
    }
  }
}