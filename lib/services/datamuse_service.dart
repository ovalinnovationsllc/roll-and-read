import 'package:http/http.dart' as http;
import 'dart:convert';
import 'content_filter_service.dart';

/// Service for fetching words from Datamuse API (free, no API key required)
/// Documentation: https://www.datamuse.com/api/
class DatamuseService {
  static const String _baseUrl = 'https://api.datamuse.com/words';
  
  /// Fetch words based on a spelling pattern
  /// Examples:
  /// - "?at" returns 3-letter words ending in "at" (cat, bat, hat)
  /// - "?????" returns 5-letter words
  /// - "s????" returns 5-letter words starting with "s"
  static Future<List<String>> getWordsByPattern(String pattern, {int maxWords = 100}) async {
    try {
      final uri = Uri.parse('$_baseUrl?sp=$pattern&max=$maxWords');
      print('📚 Datamuse: Fetching pattern: $pattern');
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final words = data
            .map((item) => item['word'].toString().toLowerCase())
            .where((word) => !word.contains('-') && !word.contains(' ') && !word.contains("'"))
            .where((word) => ContentFilterService.isWordSafe(word)) // Filter inappropriate words
            .toList();
        print('📚 Datamuse: Found ${words.length} words for pattern "$pattern"');
        return words;
      }
      return [];
    } catch (e) {
      print('🔴 Datamuse pattern error: $e');
      return [];
    }
  }
  
  /// Fetch words that rhyme with a given word
  static Future<List<String>> getRhymingWords(String word, {int maxWords = 100}) async {
    try {
      final uri = Uri.parse('$_baseUrl?rel_rhy=$word&max=$maxWords');
      print('📚 Datamuse: Getting rhymes for: $word');
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final words = data
            .map((item) => item['word'].toString().toLowerCase())
            .where((word) => !word.contains('-') && !word.contains(' ') && !word.contains("'"))
            .where((word) => ContentFilterService.isWordSafe(word)) // Filter inappropriate words
            .toList();
        print('📚 Datamuse: Found ${words.length} rhyming words');
        return words;
      }
      return [];
    } catch (e) {
      print('🔴 Datamuse rhyme error: $e');
      return [];
    }
  }
  
  /// Fetch words by topic/theme
  static Future<List<String>> getWordsByTopic(String topic, {int maxWords = 100, int? letterCount}) async {
    try {
      String url = '$_baseUrl?topics=$topic&max=$maxWords';
      
      // Add letter count constraint if specified
      if (letterCount != null) {
        final pattern = '?' * letterCount;
        url += '&sp=$pattern';
      }
      
      print('📚 Datamuse: Getting topic words for: $topic (${letterCount ?? "any"} letters)');
      final uri = Uri.parse(url);
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final words = data
            .map((item) => item['word'].toString().toLowerCase())
            .where((word) => !word.contains('-') && !word.contains(' ') && !word.contains("'"))
            .where((word) => ContentFilterService.isWordSafe(word)) // Filter inappropriate words
            .toList();
        print('📚 Datamuse: Found ${words.length} topic words');
        return words;
      }
      return [];
    } catch (e) {
      print('🔴 Datamuse topic error: $e');
      return [];
    }
  }
  
  /// Fetch words with specific sounds (for phonics patterns)
  static Future<List<String>> getWordsWithSound(String sound, {int maxWords = 100}) async {
    try {
      // Extract length requirement from the sound prompt
      int? requiredLength;
      final lengthMatch = RegExp(r'(\d+)\s*letter').firstMatch(sound.toLowerCase());
      if (lengthMatch != null) {
        requiredLength = int.parse(lengthMatch.group(1)!);
        print('📚 Datamuse: Extracted length requirement: $requiredLength from sound prompt');
      }
      
      final lowerSound = sound.toLowerCase();
      
      // Map prompt text to sound type
      String? soundType;
      if (lowerSound.contains('long u')) soundType = 'long_u';
      else if (lowerSound.contains('long a')) soundType = 'long_a';
      else if (lowerSound.contains('long e')) soundType = 'long_e';
      else if (lowerSound.contains('long i')) soundType = 'long_i';
      else if (lowerSound.contains('long o')) soundType = 'long_o';
      else if (lowerSound.contains('short a')) soundType = 'short_a';
      else if (lowerSound.contains('short e')) soundType = 'short_e';
      else if (lowerSound.contains('short i')) soundType = 'short_i';
      else if (lowerSound.contains('short o')) soundType = 'short_o';
      else if (lowerSound.contains('short u')) soundType = 'short_u';
      
      if (soundType != null) {
        return await _getWordsForSound(soundType, requiredLength: requiredLength);
      }
      
      return [];
    } catch (e) {
      print('🔴 Datamuse sound error: $e');
      return [];
    }
  }

  /// Generate rhyming words with flexible length constraints
  static Future<List<String>> _getRhymingWordsWithLength(String rhymeWord, {int? requiredLength}) async {
    List<String> allWords = [];
    
    try {
      // Get rhyming words from Datamuse
      final rhymes = await getRhymingWords(rhymeWord);
      
      // Filter by length if specified
      if (requiredLength != null) {
        allWords = rhymes.where((word) => word.length == requiredLength).toList();
        print('📚 Datamuse: Filtered ${rhymes.length} rhymes to ${allWords.length} with length $requiredLength');
      } else {
        allWords = rhymes;
      }
      
      // If we don't have enough, try pattern-based rhyming
      if (allWords.length < 20 && requiredLength != null) {
        // Extract ending sound from rhyme word and create patterns
        final ending = _extractRhymeEnding(rhymeWord);
        if (ending.isNotEmpty && ending.length < requiredLength) {
          final prefixLength = requiredLength - ending.length;
          final pattern = '${'?' * prefixLength}$ending';
          
          print('📚 Datamuse: Generating rhyme pattern: $pattern for "$rhymeWord"');
          final patternWords = await getWordsByPattern(pattern);
          allWords.addAll(patternWords.where((w) => !allWords.contains(w)));
        }
      }
      
    } catch (e) {
      print('🔴 Datamuse rhyme generation error: $e');
    }
    
    return allWords.toSet().toList();
  }

  /// Extract rhyming ending from a word (simple heuristic)
  static String _extractRhymeEnding(String word) {
    if (word.length <= 2) return word;
    
    // Common rhyme endings
    final vowelSounds = ['ay', 'ee', 'ie', 'ow', 'ue'];
    for (String sound in vowelSounds) {
      if (word.endsWith(sound)) return sound;
    }
    
    // Default to last 2-3 characters
    if (word.length >= 3) return word.substring(word.length - 2);
    return word.substring(word.length - 1);
  }
  
  /// Generate patterns for any sound + length combination
  static List<String> _generateSoundPatterns(String soundType, {int? requiredLength}) {
    List<String> patterns = [];
    
    // Define sound pattern fragments
    Map<String, List<String>> soundPatterns = {
      'long_u': ['oo', 'ue', 'ew', 'u?e', 'ui', 'ou'],
      'long_a': ['a?e', 'ai', 'ay', 'ea'],
      'long_e': ['ee', 'ea', 'e?e', 'ie', 'ei'],
      'long_i': ['i?e', 'igh', 'ie', 'y'],
      'long_o': ['o?e', 'oa', 'ow'],
      'short_a': ['a'],
      'short_e': ['e'],
      'short_i': ['i'],
      'short_o': ['o'],
      'short_u': ['u'],
    };
    
    final fragments = soundPatterns[soundType] ?? [];
    if (fragments.isEmpty) return patterns;
    
    print('📚 Datamuse: Generating patterns for $soundType with length $requiredLength');
    
    for (String fragment in fragments) {
      if (requiredLength != null) {
        // Generate length-constrained patterns
        if (fragment.contains('?')) {
          // Handle patterns like "a?e", "u?e"
          final parts = fragment.split('?');
          if (parts.length == 2 && requiredLength >= parts[0].length + parts[1].length + 1) {
            final middleLength = requiredLength - parts[0].length - parts[1].length;
            final middle = '?' * middleLength;
            patterns.add('${parts[0]}$middle${parts[1]}');
          }
        } else {
          // Handle patterns like "oo", "ai", "igh"
          if (fragment.length < requiredLength) {
            // Try as ending
            final prefixLength = requiredLength - fragment.length;
            patterns.add('${'?' * prefixLength}$fragment');
            
            // Try as beginning (for some patterns)
            patterns.add('$fragment${'?' * prefixLength}');
            
            // Try in middle (for 5+ letter words)
            if (requiredLength >= 5) {
              final remainingLength = requiredLength - fragment.length;
              for (int prefixLen = 1; prefixLen < remainingLength; prefixLen++) {
                final suffixLen = remainingLength - prefixLen;
                patterns.add('${'?' * prefixLen}$fragment${'?' * suffixLen}');
              }
            }
          }
        }
      } else {
        // Generate open-ended patterns
        if (fragment.contains('?')) {
          patterns.add(fragment.replaceAll('?', '*'));
        } else {
          patterns.add('*$fragment*');
          patterns.add('*$fragment');
          patterns.add('$fragment*');
        }
      }
    }
    
    return patterns;
  }

  /// Flexible sound word generation for any sound + length combination
  static Future<List<String>> _getWordsForSound(String soundType, {int? requiredLength}) async {
    List<String> allWords = [];
    
    final patterns = _generateSoundPatterns(soundType, requiredLength: requiredLength);
    print('📚 Datamuse: Using patterns for $soundType: $patterns');
    
    for (String pattern in patterns) {
      try {
        final words = await getWordsByPattern(pattern, maxWords: 50);
        allWords.addAll(words);
        
        // Break early if we have enough words
        if (allWords.length >= 100) break;
      } catch (e) {
        // Continue with other patterns if one fails
        continue;
      }
    }
    
    // Filter by length if specified
    if (requiredLength != null) {
      allWords = allWords.where((word) => word.length == requiredLength).toList();
    }
    
    // Remove duplicates and return
    return allWords.toSet().toList();
  }
  
  /// Parse prompt to determine pattern for Datamuse
  static String? extractPattern(String prompt) {
    final lowerPrompt = prompt.toLowerCase();
    
    // Check for CVC ending patterns
    if (lowerPrompt.contains('cvc')) {
      final endingMatch = RegExp("(?:ending|ends?) (?:in|with) [\"']?(\\w+)[\"']?").firstMatch(lowerPrompt);
      if (endingMatch != null) {
        final ending = endingMatch.group(1);
        return '?$ending'; // 3-letter CVC pattern
      }
      // Generic CVC pattern
      return '???';
    }
    
    // Check for word length + ending pattern
    final lengthMatch = RegExp(r'(\d+)\s*letter').firstMatch(lowerPrompt);
    final endingMatch = RegExp("(?:ending|ends?|that end) (?:in|with) [\"']?(\\w+)[\"']?").firstMatch(lowerPrompt);
    
    if (lengthMatch != null) {
      final length = int.parse(lengthMatch.group(1)!);
      
      if (endingMatch != null) {
        final ending = endingMatch.group(1);
        if (ending != null && ending.length < length) {
          final questionMarks = '?' * (length - ending.length);
          return '$questionMarks$ending';
        }
      } else {
        // Just length constraint
        return '?' * length;
      }
    }
    
    // Check for word family patterns like "-un family" or "words in the -un family"
    final familyMatch = RegExp(r'-(\w+)\s*family').firstMatch(lowerPrompt);
    if (familyMatch != null) {
      final ending = familyMatch.group(1);
      if (lengthMatch != null) {
        final length = int.parse(lengthMatch.group(1)!);
        final questionMarks = '?' * (length - ending!.length);
        return '$questionMarks$ending';
      } else {
        return '*$ending'; // Any length ending with pattern
      }
    }
    
    // Check for just ending pattern
    if (endingMatch != null) {
      final ending = endingMatch.group(1);
      return '*$ending'; // Any length ending with pattern
    }
    
    // Check for starting pattern
    final startMatch = RegExp("(?:starting|starts?|begin) (?:with) [\"']?(\\w+)[\"']?").firstMatch(lowerPrompt);
    if (startMatch != null) {
      final start = startMatch.group(1);
      return '$start*';
    }
    
    return null;
  }
  
  /// Extract topic from prompt
  static String? extractTopic(String prompt) {
    final lowerPrompt = prompt.toLowerCase();
    
    // Common topic keywords
    final topics = {
      'ocean': ['ocean', 'sea', 'marine', 'underwater', 'beach', 'water'],
      'animal': ['animal', 'pet', 'zoo', 'wildlife', 'creature'],
      'food': ['food', 'eat', 'meal', 'snack', 'cooking', 'kitchen'],
      'space': ['space', 'star', 'planet', 'galaxy', 'astronomy', 'moon'],
      'school': ['school', 'classroom', 'education', 'learning', 'student'],
      'family': ['family', 'home', 'parent', 'relative', 'house'],
      'weather': ['weather', 'rain', 'snow', 'sun', 'storm', 'cloud'],
      'color': ['color', 'colour', 'rainbow', 'paint', 'art'],
      'sport': ['sport', 'game', 'play', 'exercise', 'team', 'ball'],
      'music': ['music', 'song', 'instrument', 'rhythm', 'melody', 'sound'],
      'nature': ['nature', 'tree', 'plant', 'flower', 'garden', 'forest'],
      'transportation': ['car', 'vehicle', 'transport', 'travel', 'drive', 'ride'],
    };
    
    for (final entry in topics.entries) {
      for (final keyword in entry.value) {
        if (lowerPrompt.contains(keyword)) {
          return entry.key;
        }
      }
    }
    
    return null;
  }
  
  /// Main function to get words based on a teacher's prompt
  static Future<List<String>> generateWordsFromPrompt(String prompt) async {
    print('📚 Datamuse: Processing prompt: "$prompt"');
    
    List<String> words = [];
    final lowerPrompt = prompt.toLowerCase();
    
    // Check for combined requirements (sound + length)
    bool hasSound = lowerPrompt.contains('sound') || lowerPrompt.contains('long') || lowerPrompt.contains('short');
    bool hasLength = RegExp(r'(\d+)\s*letter').hasMatch(lowerPrompt);
    bool hasEnding = RegExp(r'(?:ending|end|ends|that end) (?:in|with)').hasMatch(lowerPrompt);
    bool hasRhyme = RegExp(r'rhym\w*').hasMatch(lowerPrompt);
    
    print('📚 Datamuse: Requirements detected - Sound: $hasSound, Length: $hasLength, Ending: $hasEnding, Rhyme: $hasRhyme');
    
    // 1. PRIORITY: Sound patterns with length constraints (most specific)
    if (hasSound && hasLength) {
      print('📚 Datamuse: Processing combined sound + length requirement');
      final soundWords = await getWordsWithSound(lowerPrompt);
      
      // Filter by length if specified
      final lengthMatch = RegExp(r'(\d+)\s*letter').firstMatch(lowerPrompt);
      if (lengthMatch != null) {
        final requiredLength = int.parse(lengthMatch.group(1)!);
        final filteredWords = soundWords.where((word) => word.length == requiredLength).toList();
        print('📚 Datamuse: Filtered ${soundWords.length} sound words to ${filteredWords.length} with length $requiredLength');
        words.addAll(filteredWords);
      } else {
        words.addAll(soundWords);
      }
      
      if (words.length >= 36) {
        print('📚 Datamuse: Found sufficient words from sound+length combination');
        return words.take(36).toList();
      }
    }
    
    // 2. Try sound patterns (phonics) alone
    else if (hasSound) {
      print('📚 Datamuse: Processing sound requirement only');
      final soundWords = await getWordsWithSound(lowerPrompt);
      words.addAll(soundWords.where((w) => !words.contains(w)));
      if (words.length >= 36) {
        return words.take(36).toList();
      }
    }
    
    // 3. Try pattern-based search (length + ending)
    else if (hasLength || hasEnding) {
      print('📚 Datamuse: Processing pattern-based requirement');
      final pattern = extractPattern(prompt);
      if (pattern != null) {
        words = await getWordsByPattern(pattern);
        if (words.length >= 36) {
          return words.take(36).toList();
        }
      }
    }
    
    // 4. Try rhyming if specified
    if (hasRhyme) {
      print('📚 Datamuse: Processing rhyme requirement');
      final rhymeMatch = RegExp(r'rhym\w* (?:with |words? |-)(\w+)').firstMatch(lowerPrompt);
      if (rhymeMatch != null) {
        final rhymeWord = rhymeMatch.group(1);
        if (rhymeWord != null) {
          // Extract length for flexible rhyming
          final lengthMatch = RegExp(r'(\d+)\s*letter').firstMatch(lowerPrompt);
          final rhymeLength = lengthMatch != null ? int.parse(lengthMatch.group(1)!) : null;
          
          final rhymes = await _getRhymingWordsWithLength(rhymeWord, requiredLength: rhymeLength);
          words.addAll(rhymes.where((w) => !words.contains(w)));
          if (words.length >= 36) {
            return words.take(36).toList();
          }
        }
      }
    }
    
    // 5. Try topic-based search as fallback
    if (words.length < 36) {
      print('📚 Datamuse: Trying topic-based search as fallback');
      final topic = extractTopic(prompt);
      if (topic != null) {
        // Extract letter count if specified
        final lengthMatch = RegExp(r'(\d+)\s*letter').firstMatch(lowerPrompt);
        final letterCount = lengthMatch != null ? int.parse(lengthMatch.group(1)!) : null;
        
        final topicWords = await getWordsByTopic(topic, letterCount: letterCount);
        words.addAll(topicWords.where((w) => !words.contains(w)));
      }
    }
    
    print('📚 Datamuse: Total words collected: ${words.length}');
    
    // CRITICAL: Filter inappropriate words for children
    final filteredWords = ContentFilterService.filterWords(words);
    final removedCount = words.length - filteredWords.length;
    if (removedCount > 0) {
      print('🚫 Datamuse: Filtered out $removedCount inappropriate words');
    }
    
    return filteredWords;
  }
  
  /// Check if Datamuse can handle this type of request well
  static bool canHandlePrompt(String prompt) {
    final lowerPrompt = prompt.toLowerCase();
    
    // Patterns Datamuse handles well
    return lowerPrompt.contains('letter') ||
           lowerPrompt.contains('ending') ||
           lowerPrompt.contains('ends') ||
           lowerPrompt.contains('rhym') ||
           lowerPrompt.contains('cvc') ||
           lowerPrompt.contains('sound') ||
           lowerPrompt.contains('long') ||
           lowerPrompt.contains('short') ||
           lowerPrompt.contains('start') ||
           extractTopic(prompt) != null;
  }
  
  /// Organize words into a 6x6 grid
  static List<List<String>> organizeIntoGrid(List<String> words) {
    List<List<String>> grid = [];
    
    // Ensure we have exactly 36 words
    while (words.length < 36) {
      // Duplicate existing words if needed
      if (words.isNotEmpty) {
        words.add(words[words.length % words.length]);
      } else {
        words.add('word');
      }
    }
    
    // Create 6 rows of 6 columns
    for (int i = 0; i < 6; i++) {
      List<String> row = [];
      for (int j = 0; j < 6; j++) {
        int index = i * 6 + j;
        if (index < words.length) {
          row.add(words[index]);
        }
      }
      grid.add(row);
    }
    
    return grid;
  }
}