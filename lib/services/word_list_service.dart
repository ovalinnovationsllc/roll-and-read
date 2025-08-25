import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/word_list_model.dart';

class WordListService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _wordListsCollection = _firestore.collection('word_lists');

  /// Save a new AI-generated word list to Firebase
  static Future<WordListModel> saveWordList(WordListModel wordList) async {
    try {
      final docRef = await _wordListsCollection.add(wordList.toMap());
      return wordList.copyWith(id: docRef.id);
    } catch (e) {
      print('Error saving word list: $e');
      rethrow;
    }
  }

  /// Get all available word lists, sorted by most recently created
  static Future<List<WordListModel>> getAllWordLists() async {
    try {
      final querySnapshot = await _wordListsCollection
          .orderBy('createdAt', descending: true)
          .get();
      
      return querySnapshot.docs
          .map((doc) => WordListModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting word lists: $e');
      return [];
    }
  }

  /// Get word lists by difficulty level
  static Future<List<WordListModel>> getWordListsByDifficulty(String difficulty) async {
    try {
      final querySnapshot = await _wordListsCollection
          .where('difficulty', isEqualTo: difficulty)
          .orderBy('createdAt', descending: true)
          .get();
      
      return querySnapshot.docs
          .map((doc) => WordListModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting word lists by difficulty: $e');
      return [];
    }
  }

  /// Search word lists by prompt text
  static Future<List<WordListModel>> searchWordLists(String searchQuery) async {
    try {
      final querySnapshot = await _wordListsCollection
          .orderBy('createdAt', descending: true)
          .get();
      
      // Filter by prompt containing search query (case insensitive)
      final searchLower = searchQuery.toLowerCase();
      return querySnapshot.docs
          .map((doc) => WordListModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .where((wordList) => wordList.prompt.toLowerCase().contains(searchLower))
          .toList();
    } catch (e) {
      print('Error searching word lists: $e');
      return [];
    }
  }

  /// Get a specific word list by ID
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

  /// Increment the usage count for a word list
  static Future<void> incrementUsageCount(String wordListId) async {
    try {
      await _wordListsCollection.doc(wordListId).update({
        'timesUsed': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error incrementing usage count: $e');
      // Don't rethrow - this is not critical
    }
  }

  /// Delete a word list
  static Future<void> deleteWordList(String id) async {
    try {
      await _wordListsCollection.doc(id).delete();
    } catch (e) {
      print('Error deleting word list: $e');
      rethrow;
    }
  }

  /// Get the most popular word lists (by usage count)
  static Future<List<WordListModel>> getPopularWordLists({int limit = 10}) async {
    try {
      final querySnapshot = await _wordListsCollection
          .orderBy('timesUsed', descending: true)
          .limit(limit)
          .get();
      
      return querySnapshot.docs
          .map((doc) => WordListModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting popular word lists: $e');
      return [];
    }
  }

  /// Check if a word list with the same prompt already exists
  static Future<WordListModel?> findExistingWordList(String prompt, String difficulty) async {
    try {
      final querySnapshot = await _wordListsCollection
          .where('prompt', isEqualTo: prompt)
          .where('difficulty', isEqualTo: difficulty)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return WordListModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error finding existing word list: $e');
      return null;
    }
  }
}