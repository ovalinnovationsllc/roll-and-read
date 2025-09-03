import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseCleanup {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Clean up ALL duplicate collections and standardize naming
  static Future<void> cleanupAllDuplicateCollections() async {
    
    try {
      // 1. Handle gameStates vs game_states
      await _consolidateCollections('game_states', 'gameStates', 'Game States');
      
      // 2. Handle wordLists vs word_lists  
      await _consolidateCollections('word_lists', 'wordLists', 'Word Lists');
      
      // 3. Delete obsolete student-specific collections (now using unified 'games' collection)
      await _deleteCollection('student_games');
      await _deleteCollection('student_player_profiles');
      
      // 4. Delete old kid_ collections
      await _deleteCollection('kid_games');
      await _deleteCollection('kid_player_profiles');
      
      // 5. Keep only: games, gameStates, students, users, wordLists
      
    } catch (e) {
      rethrow;
    }
  }

  /// Migrates data from obsolete kid_ collections to new student_ collections
  static Future<void> migrateObsoleteCollections() async {
    
    try {
      // Check and migrate kid_games -> student_games
      await _migrateKidGames();
      
      // Check and migrate kid_player_profiles -> student_player_profiles  
      await _migrateKidPlayerProfiles();
      
    } catch (e) {
      rethrow;
    }
  }

  /// Migrate kid_games collection to student_games
  static Future<void> _migrateKidGames() async {
    
    try {
      final kidGamesSnapshot = await _firestore.collection('kid_games').get();
      
      if (kidGamesSnapshot.docs.isEmpty) {
        return;
      }

      
      // Batch write for efficiency
      final batch = _firestore.batch();
      
      for (final doc in kidGamesSnapshot.docs) {
        // Create new document in student_games with same ID
        final newDocRef = _firestore.collection('student_games').doc(doc.id);
        batch.set(newDocRef, doc.data());
        
      }
      
      // Commit the batch
      await batch.commit();
      
      // Delete old collection documents
      await _deleteCollection('kid_games');
      
    } catch (e) {
      throw e;
    }
  }

  /// Migrate kid_player_profiles collection to student_player_profiles
  static Future<void> _migrateKidPlayerProfiles() async {
    
    try {
      final kidProfilesSnapshot = await _firestore.collection('kid_player_profiles').get();
      
      if (kidProfilesSnapshot.docs.isEmpty) {
        return;
      }

      
      // Batch write for efficiency
      final batch = _firestore.batch();
      
      for (final doc in kidProfilesSnapshot.docs) {
        // Create new document in student_player_profiles with same ID
        final newDocRef = _firestore.collection('student_player_profiles').doc(doc.id);
        batch.set(newDocRef, doc.data());
        
      }
      
      // Commit the batch
      await batch.commit();
      
      // Delete old collection documents
      await _deleteCollection('kid_player_profiles');
      
    } catch (e) {
      throw e;
    }
  }

  /// Consolidate two collections - migrate from oldCollection to newCollection, then delete old
  static Future<void> _consolidateCollections(String oldCollection, String newCollection, String displayName) async {
    
    try {
      final oldSnapshot = await _firestore.collection(oldCollection).get();
      final newSnapshot = await _firestore.collection(newCollection).get();
      
      
      // If old collection has more or equal data, migrate to new
      if (oldSnapshot.docs.length >= newSnapshot.docs.length && oldSnapshot.docs.isNotEmpty) {
        
        final batch = _firestore.batch();
        for (final doc in oldSnapshot.docs) {
          batch.set(_firestore.collection(newCollection).doc(doc.id), doc.data());
        }
        await batch.commit();
      }
      
      // Delete old collection
      if (oldSnapshot.docs.isNotEmpty) {
        await _deleteCollection(oldCollection);
      }
      
    } catch (e) {
      throw e;
    }
  }

  /// Safely delete all documents in a collection
  static Future<void> _deleteCollection(String collectionName) async {
    
    try {
      final snapshot = await _firestore.collection(collectionName).get();
      
      if (snapshot.docs.isEmpty) {
        return;
      }
      
      // Delete in batches to avoid hitting Firestore limits
      final batch = _firestore.batch();
      int deleteCount = 0;
      
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
        deleteCount++;
        
        // Firestore batch limit is 500 operations
        if (deleteCount >= 400) {
          await batch.commit();
          deleteCount = 0;
        }
      }
      
      // Commit remaining deletions
      if (deleteCount > 0) {
        await batch.commit();
      }
      
    } catch (e) {
      throw e;
    }
  }

  /// Dry run - check what collections exist and what would be migrated
  static Future<void> checkObsoleteCollections() async {
    
    try {
      // Check kid_games
      final kidGamesSnapshot = await _firestore.collection('kid_games').limit(1).get();
      if (kidGamesSnapshot.docs.isNotEmpty) {
        final fullSnapshot = await _firestore.collection('kid_games').get();
      } else {
      }
      
      // Check kid_player_profiles
      final kidProfilesSnapshot = await _firestore.collection('kid_player_profiles').limit(1).get();
      if (kidProfilesSnapshot.docs.isNotEmpty) {
        final fullSnapshot = await _firestore.collection('kid_player_profiles').get();
      } else {
      }
      
      // Check current student collections
      final studentGamesSnapshot = await _firestore.collection('student_games').limit(1).get();
      if (studentGamesSnapshot.docs.isNotEmpty) {
        final fullSnapshot = await _firestore.collection('student_games').get();
      } else {
      }
      
      final studentProfilesSnapshot = await _firestore.collection('student_player_profiles').limit(1).get();
      if (studentProfilesSnapshot.docs.isNotEmpty) {
        final fullSnapshot = await _firestore.collection('student_player_profiles').get();
      } else {
      }
      
    } catch (e) {
      rethrow;
    }
  }
}
