import 'dart:async';
import 'dart:convert';
import '../data/ufli_word_lists.dart';
import '../models/word_list_model.dart';
import '../services/content_filter_service.dart';

/// Service for importing UFLI word lists from various sources
class UFLIImportService {
  
  /// Import word lists from JSON string
  /// Expected format: {"listId": ["word1", "word2", ...], ...}
  static Future<ImportResult> importFromJson(String jsonString) async {
    try {
      final Map<String, dynamic> data = json.decode(jsonString);
      final Map<String, List<String>> wordLists = {};
      
      for (final entry in data.entries) {
        if (entry.value is List) {
          wordLists[entry.key] = List<String>.from(entry.value);
        }
      }
      
      return await _importWordLists(wordLists);
    } catch (e) {
      return ImportResult(
        success: false,
        message: 'Failed to parse JSON: $e',
        importedLists: [],
        skippedLists: [],
      );
    }
  }
  
  /// Import word lists from CSV data
  /// Expected format: listId,word1,word2,word3,...
  static Future<ImportResult> importFromCsv(String csvData) async {
    try {
      final lines = csvData.split('\n').where((line) => line.trim().isNotEmpty);
      final Map<String, List<String>> wordLists = {};
      
      for (final line in lines) {
        final parts = line.split(',').map((part) => part.trim()).toList();
        if (parts.length >= 2) {
          final listId = parts[0];
          final words = parts.sublist(1).where((word) => word.isNotEmpty).toList();
          wordLists[listId] = words;
        }
      }
      
      return await _importWordLists(wordLists);
    } catch (e) {
      return ImportResult(
        success: false,
        message: 'Failed to parse CSV: $e',
        importedLists: [],
        skippedLists: [],
      );
    }
  }
  
  /// Import word lists from plain text
  /// Expected format: 
  /// [ListID]
  /// word1
  /// word2
  /// ...
  /// [AnotherListID]
  /// word3
  /// word4
  static Future<ImportResult> importFromPlainText(String textData) async {
    try {
      final lines = textData.split('\n').map((line) => line.trim()).toList();
      final Map<String, List<String>> wordLists = {};
      String? currentListId;
      List<String> currentWords = [];
      
      for (final line in lines) {
        if (line.isEmpty) continue;
        
        // Check for list ID marker [ListID]
        if (line.startsWith('[') && line.endsWith(']')) {
          // Save previous list if any
          if (currentListId != null && currentWords.isNotEmpty) {
            wordLists[currentListId] = List.from(currentWords);
          }
          
          // Start new list
          currentListId = line.substring(1, line.length - 1);
          currentWords = [];
        } else if (currentListId != null) {
          // Add word to current list
          final words = line.split(RegExp(r'[,\s]+'));
          for (final word in words) {
            if (word.trim().isNotEmpty) {
              currentWords.add(word.trim());
            }
          }
        }
      }
      
      // Save last list
      if (currentListId != null && currentWords.isNotEmpty) {
        wordLists[currentListId] = currentWords;
      }
      
      return await _importWordLists(wordLists);
    } catch (e) {
      return ImportResult(
        success: false,
        message: 'Failed to parse plain text: $e',
        importedLists: [],
        skippedLists: [],
      );
    }
  }
  
  /// Import individual word list
  static Future<ImportResult> importSingleList(String listId, List<String> words) async {
    return await _importWordLists({listId: words});
  }
  
  /// Internal method to import word lists
  static Future<ImportResult> _importWordLists(Map<String, List<String>> wordLists) async {
    final List<String> imported = [];
    final List<String> skipped = [];
    
    for (final entry in wordLists.entries) {
      final listId = entry.key;
      final rawWords = entry.value;
      
      // Check if list ID is valid
      if (UFLIWordLists.getWordListById(listId) == null) {
        skipped.add('$listId (unknown list ID)');
        continue;
      }
      
      // Filter words for appropriateness
      final safeWords = ContentFilterService.filterWords(rawWords);
      
      if (safeWords.isEmpty) {
        skipped.add('$listId (no safe words after filtering)');
        continue;
      }
      
      // Import the word list
      UFLIWordLists.importWordList(listId, safeWords);
      imported.add('$listId (${safeWords.length} words)');
    }
    
    return ImportResult(
      success: imported.isNotEmpty,
      message: imported.isNotEmpty 
          ? 'Successfully imported ${imported.length} word lists'
          : 'No word lists could be imported',
      importedLists: imported,
      skippedLists: skipped,
    );
  }
  
  /// Get template for manual word list entry
  static String getImportTemplate() {
    final buffer = StringBuffer();
    buffer.writeln('# UFLI Word List Import Template');
    buffer.writeln('# Copy this template and fill in your words');
    buffer.writeln();
    
    final allLists = UFLIWordLists.getAllWordLists();
    for (final wordList in allLists.take(5)) { // Show first 5 as examples
      buffer.writeln('[${wordList.id}]');
      buffer.writeln('# ${wordList.title} - ${wordList.skillFocus}');
      buffer.writeln('# Category: ${wordList.category}');
      buffer.writeln('word1');
      buffer.writeln('word2');
      buffer.writeln('word3');
      buffer.writeln('# ... add more words');
      buffer.writeln();
    }
    
    buffer.writeln('# Available List IDs:');
    for (final wordList in allLists) {
      buffer.writeln('# ${wordList.id} - ${wordList.title}');
    }
    
    return buffer.toString();
  }
  
  /// Generate sample word lists for testing
  static Map<String, List<String>> generateSampleWordLists() {
    return {
      'ufli_k_cvc': [
        'cat', 'bat', 'hat', 'rat', 'mat', 'pat', 'sat', 'fat',
        'can', 'man', 'pan', 'ran', 'tan', 'van', 'fan', 'ban',
        'cup', 'pup', 'up', 'cut', 'but', 'nut', 'hut', 'rut',
        'dog', 'log', 'hog', 'jog', 'fog', 'cog', 'bog'
      ],
      'ufli_1_short_vowels': [
        'apple', 'ant', 'add', 'ask', 'at',
        'egg', 'end', 'elf', 'elk', 'exit',
        'igloo', 'ink', 'ill', 'if', 'it',
        'ox', 'on', 'odd', 'off', 'octopus',
        'up', 'under', 'us', 'umbrella', 'ugly'
      ],
      'ufli_2_cvce': [
        'make', 'take', 'cake', 'lake', 'wake', 'sake', 'bake', 'rake',
        'hope', 'rope', 'note', 'vote', 'rode', 'code', 'mode', 'pole',
        'cute', 'tube', 'cube', 'mute', 'huge', 'tune', 'dune', 'fuse',
        'bike', 'like', 'hike', 'pike', 'mike', 'kite', 'bite', 'site'
      ]
    };
  }
  
  /// Export current word lists to JSON
  static String exportToJson() {
    final Map<String, List<String>> exportData = {};
    
    for (final wordList in UFLIWordLists.getAllWordLists()) {
      if (wordList.words.isNotEmpty) {
        exportData[wordList.id] = wordList.words;
      }
    }
    
    return json.encode(exportData);
  }
  
  /// Get import status summary
  static ImportStatusSummary getImportStatus() {
    final status = UFLIWordLists.getImportStatus();
    final imported = status.values.where((imported) => imported).length;
    final total = status.length;
    
    return ImportStatusSummary(
      totalLists: total,
      importedLists: imported,
      pendingLists: total - imported,
      importStatus: status,
    );
  }
}

/// Result of an import operation
class ImportResult {
  final bool success;
  final String message;
  final List<String> importedLists;
  final List<String> skippedLists;
  
  const ImportResult({
    required this.success,
    required this.message,
    required this.importedLists,
    required this.skippedLists,
  });
  
  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln(message);
    
    if (importedLists.isNotEmpty) {
      buffer.writeln('\nImported:');
      for (final item in importedLists) {
        buffer.writeln('✓ $item');
      }
    }
    
    if (skippedLists.isNotEmpty) {
      buffer.writeln('\nSkipped:');
      for (final item in skippedLists) {
        buffer.writeln('⚠ $item');
      }
    }
    
    return buffer.toString();
  }
}

/// Summary of import status
class ImportStatusSummary {
  final int totalLists;
  final int importedLists;
  final int pendingLists;
  final Map<String, bool> importStatus;
  
  const ImportStatusSummary({
    required this.totalLists,
    required this.importedLists,
    required this.pendingLists,
    required this.importStatus,
  });
  
  double get completionPercentage => totalLists > 0 ? importedLists / totalLists : 0.0;
  
  @override
  String toString() {
    return 'Import Status: $importedLists/$totalLists lists imported (${(completionPercentage * 100).toStringAsFixed(1)}%)';
  }
}