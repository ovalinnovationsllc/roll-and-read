import '../models/word_list_model.dart';
import 'firestore_service.dart';

class WordListService {

  /// Save a new AI-generated word list to local storage
  static Future<WordListModel> saveWordList(WordListModel wordList) async {
    try {
      return await FirestoreService.saveWordList(wordList);
    } catch (e) {
      print('Error saving word list: $e');
      rethrow;
    }
  }

  /// Get all available word lists, sorted by most recently created
  static Future<List<WordListModel>> getAllWordLists() async {
    try {
      print('📚 WordListService: Starting to fetch all word lists...');
      print('📚 WordListService: Local storage ready: ${FirestoreService.isInitialized}');
      
      if (!FirestoreService.isInitialized) {
        print('📚 WordListService: Local storage not ready, returning empty list');
        return [];
      }
      
      final wordLists = await FirestoreService.getAllWordLists();
      print('📚 WordListService: Successfully loaded ${wordLists.length} word lists');
      return wordLists;
    } catch (e) {
      print('📚 WordListService: Error getting word lists: $e');
      print('📚 WordListService: Error type: ${e.runtimeType}');
      return [];
    }
  }

  /// Get word lists by difficulty level
  static Future<List<WordListModel>> getWordListsByDifficulty(String difficulty) async {
    try {
      return await FirestoreService.getWordListsByDifficulty(difficulty);
    } catch (e) {
      print('Error getting word lists by difficulty: $e');
      return [];
    }
  }

  /// Search word lists by prompt text
  static Future<List<WordListModel>> searchWordLists(String searchQuery) async {
    try {
      return await FirestoreService.searchWordLists(searchQuery);
    } catch (e) {
      print('Error searching word lists: $e');
      return [];
    }
  }

  /// Get a specific word list by ID
  static Future<WordListModel?> getWordList(String id) async {
    try {
      return await FirestoreService.getWordList(id);
    } catch (e) {
      print('Error getting word list: $e');
      return null;
    }
  }

  /// Increment the usage count for a word list
  static Future<void> incrementUsageCount(String wordListId) async {
    try {
      await FirestoreService.incrementWordListUsage(wordListId);
    } catch (e) {
      print('Error incrementing usage count: $e');
      // Don't rethrow - this is not critical
    }
  }

  /// Delete a word list
  static Future<void> deleteWordList(String id) async {
    try {
      await FirestoreService.deleteWordList(id);
    } catch (e) {
      print('Error deleting word list: $e');
      rethrow;
    }
  }

  /// Get the most popular word lists (by usage count)
  static Future<List<WordListModel>> getPopularWordLists({int limit = 10}) async {
    try {
      return await FirestoreService.getPopularWordLists(limit: limit);
    } catch (e) {
      print('Error getting popular word lists: $e');
      return [];
    }
  }

  /// Check if a word list with the same prompt already exists
  static Future<WordListModel?> findExistingWordList(String prompt, String difficulty) async {
    try {
      return await FirestoreService.findExistingWordList(prompt, difficulty);
    } catch (e) {
      print('Error finding existing word list: $e');
      return null;
    }
  }

  /// Test method to check basic local storage connectivity
  static Future<bool> testStorageConnection() async {
    try {
      print('🔧 Testing local storage connection...');
      return await FirestoreService.testConnection();
    } catch (e) {
      print('🔧 Local storage connection failed: $e');
      return false;
    }
  }
}