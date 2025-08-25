import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../utils/safe_print.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _usersCollection = 'users';
  
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
      final QuerySnapshot querySnapshot = await _firestore
          .collection(_usersCollection)
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
      
      final QuerySnapshot querySnapshot = await _firestore
          .collection(_usersCollection)
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
      final docRef = _firestore.collection(_usersCollection).doc();
      
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
      await _firestore
          .collection(_usersCollection)
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
    return _firestore
        .collection(_usersCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return UserModel.fromMap(data);
      }).toList();
    });
  }

  /// Delete user (admin only)
  static Future<bool> deleteUser(String userId) async {
    try {
      await _firestore
          .collection(_usersCollection)
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
      final QuerySnapshot snapshot = await _firestore
          .collection(_usersCollection)
          .get();

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
}