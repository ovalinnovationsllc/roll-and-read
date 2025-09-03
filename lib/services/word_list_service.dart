import '../models/word_list_model.dart';
import 'firestore_service.dart';

class WordListService {

  /// Save a new AI-generated word list to local storage
  static Future<WordListModel> saveWordList(WordListModel wordList) async {
    try {
      return await FirestoreService.saveWordList(wordList);
    } catch (e) {
      rethrow;
    }
  }

  /// Get all available word lists, sorted by most recently created
  static Future<List<WordListModel>> getAllWordLists() async {
    try {
      
      if (!FirestoreService.isInitialized) {
        return [];
      }
      
      final wordLists = await FirestoreService.getAllWordLists();
      return wordLists;
    } catch (e) {
      return [];
    }
  }

  /// Get word lists by difficulty level
  static Future<List<WordListModel>> getWordListsByDifficulty(String difficulty) async {
    try {
      return await FirestoreService.getWordListsByDifficulty(difficulty);
    } catch (e) {
      return [];
    }
  }

  /// Search word lists by prompt text
  static Future<List<WordListModel>> searchWordLists(String searchQuery) async {
    try {
      return await FirestoreService.searchWordLists(searchQuery);
    } catch (e) {
      return [];
    }
  }

  /// Get a specific word list by ID
  static Future<WordListModel?> getWordList(String id) async {
    try {
      return await FirestoreService.getWordList(id);
    } catch (e) {
      return null;
    }
  }

  /// Increment the usage count for a word list
  static Future<void> incrementUsageCount(String wordListId) async {
    try {
      await FirestoreService.incrementWordListUsage(wordListId);
    } catch (e) {
      // Don't rethrow - this is not critical
    }
  }

  /// Delete a word list
  static Future<void> deleteWordList(String id) async {
    try {
      await FirestoreService.deleteWordList(id);
    } catch (e) {
      rethrow;
    }
  }

  /// Get the most popular word lists (by usage count)
  static Future<List<WordListModel>> getPopularWordLists({int limit = 10}) async {
    try {
      return await FirestoreService.getPopularWordLists(limit: limit);
    } catch (e) {
      return [];
    }
  }

  /// Check if a word list with the same prompt already exists
  static Future<WordListModel?> findExistingWordList(String prompt, String difficulty) async {
    try {
      return await FirestoreService.findExistingWordList(prompt, difficulty);
    } catch (e) {
      return null;
    }
  }

  /// Test method to check basic local storage connectivity
  static Future<bool> testStorageConnection() async {
    try {
      return await FirestoreService.testConnection();
    } catch (e) {
      return false;
    }
  }
  
  /// Get word lists by tags (filtering by multiple tags)
  static Future<List<WordListModel>> getWordListsByTags(List<String> tags) async {
    try {
      final allLists = await getAllWordLists();
      return allLists.where((list) => 
        list.tags.any((tag) => tags.contains(tag))
      ).toList();
    } catch (e) {
      return [];
    }
  }
  
  /// Get word lists by grade level
  static Future<List<WordListModel>> getWordListsByGrade(String grade) async {
    try {
      final allLists = await getAllWordLists();
      return allLists.where((list) => list.grade == grade).toList();
    } catch (e) {
      return [];
    }
  }
  
  /// Get word lists by subject
  static Future<List<WordListModel>> getWordListsBySubject(String subject) async {
    try {
      final allLists = await getAllWordLists();
      return allLists.where((list) => list.subject == subject).toList();
    } catch (e) {
      return [];
    }
  }
  
  /// Get public word lists (shared by other teachers)
  static Future<List<WordListModel>> getPublicWordLists() async {
    try {
      final allLists = await getAllWordLists();
      return allLists.where((list) => list.isPublic).toList();
    } catch (e) {
      return [];
    }
  }
  
  /// Update the lastUsed timestamp when a word list is used
  static Future<void> updateLastUsed(String wordListId) async {
    try {
      final wordList = await getWordList(wordListId);
      if (wordList != null) {
        final updated = wordList.copyWith(
          lastUsed: DateTime.now(),
          timesUsed: wordList.timesUsed + 1,
        );
        await FirestoreService.updateWordList(updated);
      }
    } catch (e) {
      // Don't rethrow - this is not critical
    }
  }
}