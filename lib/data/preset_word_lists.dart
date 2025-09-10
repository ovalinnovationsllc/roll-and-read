import 'dart:math';
import '../services/content_filter_service.dart';
import '../services/custom_word_list_service.dart';

class PresetWordLists {

  static List<List<String>> getRandomWordsForGrid(String gradeLevel, {int totalWords = 36}) {
    // Preset lists have been removed - use safe replacements
    final safeWords = ContentFilterService.getSafeReplacements(totalWords);
    
    final List<List<String>> grid = [];
    for (int i = 0; i < 6; i++) {
      final row = <String>[];
      for (int j = 0; j < 6; j++) {
        final index = i * 6 + j;
        if (index < safeWords.length) {
          row.add(safeWords[index]);
        }
      }
      if (row.length == 6) {
        grid.add(row);
      }
    }
    
    return grid;
  }

  static String getGradeLevelDescription(String gradeLevel) {
    // Basic grade descriptions removed - only UFLI categories remain
    return 'Word List';
  }
  
  /// Get available word list types from Firebase
  static Future<List<String>> getAvailableWordListTypes() async {
    try {
      print('🔍 Fetching shared word lists from Firebase...');
      // Get shared word lists from Firebase
      final sharedLists = await CustomWordListService.getSharedWordListsOnce();
      print('📊 Found ${sharedLists.length} shared word lists');
      final titles = sharedLists.map((list) => list.title).toList();
      print('📝 Word list titles: $titles');
      return titles;
    } catch (e) {
      print('❌ Error fetching word lists: $e');
      // Return some default options if Firebase fails
      return ['No shared word lists found'];
    }
  }
  
  /// Get available word list categories from Firebase
  static Future<List<String>> getAvailableCategories() async {
    // Get grade levels from shared word lists in Firebase
    final sharedLists = await CustomWordListService.getSharedWordListsOnce();
    final categories = sharedLists
        .map((list) => list.gradeLevel ?? 'Other')
        .where((grade) => grade.isNotEmpty)
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }
  
  /// Get word grid based on Firebase word list selection
  static Future<List<List<String>>> getWordGridByType(String type, {int totalWords = 36}) async {
    try {
      // Get the word list from Firebase by title
      final sharedLists = await CustomWordListService.getSharedWordListsOnce();
      final wordList = sharedLists.firstWhere(
        (list) => list.title == type,
      );
      
      // Use the actual words from Firebase
      return _createWordGridFromList(wordList.words, totalWords: totalWords);
    } catch (e) {
      // Fallback to default if word list not found
      return getRandomWordsForGrid('default', totalWords: totalWords);
    }
  }
  
  /// Create word grid from Firebase word list
  static List<List<String>> _createWordGridFromList(List<String> words, {int totalWords = 36}) {
    // Apply content filtering
    final safeWords = ContentFilterService.filterWords(words);
    
    if (safeWords.isEmpty) {
      // Fallback if no safe words
      final fallbackWords = ContentFilterService.getSafeReplacements(totalWords);
      return _createGridFromWords(fallbackWords);
    }
    
    final selectedWords = <String>[];
    
    // If we have enough words, use them all then randomly duplicate
    if (safeWords.length >= totalWords) {
      safeWords.shuffle();
      selectedWords.addAll(safeWords.take(totalWords));
    } else {
      // Add all available words first
      selectedWords.addAll(safeWords);
      
      // Randomly duplicate words from the same list to reach totalWords
      final random = Random();
      while (selectedWords.length < totalWords) {
        final randomWord = safeWords[random.nextInt(safeWords.length)];
        selectedWords.add(randomWord);
      }
    }
    
    // Final shuffle to mix originals with duplicates
    selectedWords.shuffle();
    
    return _createGridFromWords(selectedWords);
  }
  
  /// Check if Firebase word lists are available
  static Future<bool> areFirebaseListsAvailable() async {
    try {
      final sharedLists = await CustomWordListService.getSharedWordListsOnce();
      return sharedLists.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Get description for Firebase word list type
  static Future<String> getWordListTypeDescription(String type) async {
    try {
      final sharedLists = await CustomWordListService.getSharedWordListsOnce();
      final wordList = sharedLists.firstWhere(
        (list) => list.title == type,
      );
      return wordList.description ?? 'Word practice list';
    } catch (e) {
      return 'Word practice list';
    }
  }
  
  /// Helper method to create grid from word list
  static List<List<String>> _createGridFromWords(List<String> words) {
    final List<List<String>> grid = [];
    for (int i = 0; i < 6; i++) {
      final row = <String>[];
      for (int j = 0; j < 6; j++) {
        final index = i * 6 + j;
        if (index < words.length) {
          row.add(words[index]);
        }
      }
      if (row.length == 6) {
        grid.add(row);
      }
    }
    return grid;
  }

}