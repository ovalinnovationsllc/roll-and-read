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
      
      // 3. Delete obsolete collections (no longer needed)
      await _deleteCollection('student_games');
      await _deleteCollection('student_player_profiles');
      
      // 4. Delete old kid_ collections
      await _deleteCollection('kid_games');
      await _deleteCollection('kid_player_profiles');
      
      // 5. Keep only: games, gameStates, users, wordLists
      
      // 6. Clean instructional words from word lists
      await cleanInstructionalWordsFromWordLists();
      
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

  /// Clean instructional words from Firebase word lists
  static Future<void> cleanInstructionalWordsFromWordLists() async {
    print('🧹 Starting cleanup of instructional words from Firebase word lists...');
    
    try {
      // Words that are commonly from titles, instructions, or metadata that shouldn't be in student games
      final instructionalWords = {
        // Basic instructional words
        'practice', 'exercise', 'activity', 'homework', 'worksheet',
        'lesson', 'grade', 'level', 'directions', 'instructions',
        'roll', 'read', 'circle', 'write', 'trace', 'spell',
        'match', 'connect', 'draw', 'color', 'cut', 'paste',
        'complete', 'finish', 'review', 'student', 'teacher',
        'name', 'date', 'score', 'page', 'copyright',
        'university', 'ufli', 'foundations', 'roll and read',
        
        // Phonics/linguistic terminology from lesson titles
        'vowel', 'vowels', 'part', 'nasalized', 'advanced', 'spelling', 
        'voiced', 'unvoiced', 'digraphs', 'digraph', 'vce', 'exceptions', 
        'syllables', 'syllable', 'compound', 'open', 'closed', 'controlled', 
        'dipthongs', 'diphthongs', 'doubling', 'signal', 'affixes', 'affix',
        'vc', 'cv', 'cvc', 'cvce', 'ccvc', 'cvcc', 'ccvcc', 'vcc',  // Phonics patterns/abbreviations
        
        // Additional educational terminology  
        'phonics', 'sounds', 'patterns', 'blends', 'consonant', 'consonants',
        'short', 'long', 'silent', 'magic', 'cvce', 'cvc', 'mixed',
        'beginning', 'ending', 'middle', 'final', 'initial',
        'prefix', 'prefixes', 'suffix', 'suffixes', 'root',
        
        // Very common words that might be instructions
        'the', 'and', 'to', 'a', 'in', 'of', 'for', 'with', 'words',
      };

      // Get all word lists from Firebase - check both collections
      final collections = ['wordLists', 'custom_word_lists'];
      
      int totalListsProcessed = 0;
      int totalWordsRemoved = 0;
      
      for (final collectionName in collections) {
        print('🔍 Checking collection: $collectionName');
        final wordListsSnapshot = await _firestore.collection(collectionName).get();
        print('📊 Found ${wordListsSnapshot.docs.length} documents in $collectionName');
        
        int listsProcessed = 0;
        int wordsRemoved = 0;
        
        for (final doc in wordListsSnapshot.docs) {
          final data = doc.data();
          final docId = doc.id;
          
          // Check different possible field names for word data
          List<String>? originalWords;
          String? updateField;
          
          if (data.containsKey('wordGrid') && data['wordGrid'] is List) {
            final List<dynamic> flatWordGrid = data['wordGrid'];
            originalWords = flatWordGrid.cast<String>();
            updateField = 'wordGrid';
          } else if (data.containsKey('words') && data['words'] is List) {
            final List<dynamic> wordsData = data['words'];
            originalWords = wordsData.cast<String>();
            updateField = 'words';
          }
          
          if (originalWords != null && updateField != null) {
            // Filter out instructional words (case insensitive)
            final filteredWords = originalWords.where((word) {
              final lowerWord = word.toLowerCase().trim();
              return !instructionalWords.contains(lowerWord);
            }).toList();
            
            // If words were removed, update the document
            if (originalWords.length != filteredWords.length) {
              final removedWords = originalWords.where((word) {
                final lowerWord = word.toLowerCase().trim();
                return instructionalWords.contains(lowerWord);
              }).toList();
              
              print('📝 $collectionName/${docId}: Removing ${removedWords.length} instructional words: ${removedWords.join(", ")}');
              
              // Update the document with cleaned word grid
              await _firestore.collection(collectionName).doc(docId).update({
                updateField: filteredWords,
              });
              
              wordsRemoved += removedWords.length;
            } else {
              print('✅ $collectionName/${docId}: No instructional words found');
            }
            
            listsProcessed++;
          }
        }
        
        print('📊 $collectionName: Processed $listsProcessed lists, removed $wordsRemoved words');
        totalListsProcessed += listsProcessed;
        totalWordsRemoved += wordsRemoved;
      }
      
      print('🎉 Cleanup complete! Processed $totalListsProcessed total word lists across all collections, removed $totalWordsRemoved total instructional words');
      
    } catch (e) {
      print('❌ Error cleaning instructional words: $e');
      rethrow;
    }
  }
}
