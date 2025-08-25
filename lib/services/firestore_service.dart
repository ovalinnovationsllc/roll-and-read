import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../utils/safe_print.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _usersCollection = _firestore.collection('users');
  
  // Flag to track if Firebase is properly initialized
  static bool _isFirebaseReady = false;
  
  /// Set Firebase ready status (called after successful initialization)
  static void setFirebaseReady(bool ready) {
    _isFirebaseReady = ready;
  }
  
  /// Check if Firebase operations are safe to perform
  static bool get isFirebaseReady => _isFirebaseReady;

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
}