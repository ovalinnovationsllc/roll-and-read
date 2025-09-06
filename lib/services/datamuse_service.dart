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
      // Add md=f for frequency data and topics=children to bias toward kid-friendly words
      final uri = Uri.parse('$_baseUrl?sp=$pattern&md=f&topics=children,school,family,animals,colors&max=${maxWords * 3}');
      print('📚 Datamuse: Fetching pattern: $pattern with frequency filtering');
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        // Sort by frequency score and filter for common, child-appropriate words
        var scoredWords = <Map<String, dynamic>>[];
        
        for (var item in data) {
          final word = item['word'].toString().toLowerCase();
          
          // Skip inappropriate length, compounds, contractions
          if (word.length < 2 || word.length > 6) continue;
          if (word.contains('-') || word.contains(' ') || word.contains("'")) continue;
          if (!ContentFilterService.isWordSafe(word)) continue;
          
          // Calculate score based on frequency and simplicity
          double score = 0.0;
          
          // Check frequency tag
          final tags = item['tags'] as List<dynamic>?;
          if (tags != null) {
            for (var tag in tags) {
              final tagStr = tag.toString();
              if (tagStr.startsWith('f:')) {
                final freq = double.tryParse(tagStr.substring(2)) ?? 0;
                score += freq * 100; // Weight frequency heavily
              }
            }
          }
          
          // Prefer shorter words for children
          score += (7 - word.length) * 10;
          
          // Check topic relevance score (if provided by API)
          final topicScore = item['score'] as num?;
          if (topicScore != null) {
            score += topicScore.toDouble() / 1000;
          }
          
          scoredWords.add({'word': word, 'score': score});
        }
        
        // Sort by score and take top words
        scoredWords.sort((a, b) => b['score'].compareTo(a['score']));
        final words = scoredWords
            .take(maxWords)
            .map((item) => item['word'] as String)
            .toList();
        
        print('📚 Datamuse: Found ${words.length} child-appropriate words for pattern "$pattern"');
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
      // Add md=f to get frequency data, then we can filter for common words
      final uri = Uri.parse('$_baseUrl?rel_rhy=$word&md=f&max=${maxWords * 2}');
      print('📚 Datamuse: Getting rhymes for: $word');
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        // Sort by frequency (if available) and filter for child-appropriate words
        final words = data
            .where((item) {
              final word = item['word'].toString().toLowerCase();
              // Check word length (2-6 letters for children)
              if (word.length < 2 || word.length > 6) return false;
              // Skip compound words and contractions
              if (word.contains('-') || word.contains(' ') || word.contains("'")) return false;
              // Check if safe
              if (!ContentFilterService.isWordSafe(word)) return false;
              
              // Prefer words with frequency data (common words)
              final tags = item['tags'] as List<dynamic>?;
              if (tags != null) {
                // Check if it has frequency data (f:X format where X is frequency)
                final hasFrequency = tags.any((tag) => tag.toString().startsWith('f:'));
                if (hasFrequency) {
                  // Extract frequency value
                  final freqTag = tags.firstWhere((tag) => tag.toString().startsWith('f:'));
                  final freqValue = double.tryParse(freqTag.toString().substring(2)) ?? 0;
                  // Only include words with reasonable frequency (above 0.01)
                  return freqValue > 0.01;
                }
              }
              // Include words without frequency data as fallback
              return true;
            })
            .map((item) => item['word'].toString().toLowerCase())
            .take(maxWords)
            .toList();
        
        print('📚 Datamuse: Found ${words.length} child-appropriate rhyming words');
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
      // Use topics parameter with frequency data for better results
      String url = '$_baseUrl?topics=$topic&md=f&max=${maxWords * 2}';
      
      // Add letter count constraint if specified
      if (letterCount != null) {
        final pattern = '?' * letterCount;
        url += '&sp=$pattern';
      }
      
      print('📚 Datamuse: Getting topic words for: $topic (${letterCount ?? "any"} letters) with frequency filtering');
      final uri = Uri.parse(url);
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        // Filter and score words for child appropriateness
        var scoredWords = <Map<String, dynamic>>[];
        
        for (var item in data) {
          final word = item['word'].toString().toLowerCase();
          
          // Skip inappropriate words
          if (word.length < 2 || word.length > 6) continue;
          if (word.contains('-') || word.contains(' ') || word.contains("'")) continue;
          if (!ContentFilterService.isWordSafe(word)) continue;
          
          double score = 0.0;
          
          // Check frequency - prefer common words
          final tags = item['tags'] as List<dynamic>?;
          if (tags != null) {
            for (var tag in tags) {
              final tagStr = tag.toString();
              if (tagStr.startsWith('f:')) {
                final freq = double.tryParse(tagStr.substring(2)) ?? 0;
                // Skip very rare words (frequency < 0.001)
                if (freq < 0.001) continue;
                score += freq * 100; // Weight frequency heavily
              }
            }
          }
          
          // Topic relevance score
          final topicScore = item['score'] as num?;
          if (topicScore != null) {
            score += topicScore.toDouble() / 100;
          }
          
          // Prefer shorter words for children
          score += (7 - word.length) * 5;
          
          if (score > 0) {
            scoredWords.add({'word': word, 'score': score});
          }
        }
        
        // Sort by score and take top words
        scoredWords.sort((a, b) => b['score'].compareTo(a['score']));
        final words = scoredWords
            .take(maxWords)
            .map((item) => item['word'] as String)
            .toList();
        
        print('📚 Datamuse: Found ${words.length} child-appropriate topic words');
        return words;
      }
      return [];
    } catch (e) {
      print('🔴 Datamuse topic error: $e');
      return [];
    }
  }
  
  /// Helper method to build high-quality phonics word lists from Datamuse
  static Future<List<String>> _buildPhonicsListFromDatamuse(List<String> patterns, {int maxWords = 200}) async {
    Set<String> allWords = {};
    
    for (String pattern in patterns) {
      try {
        // Use our improved pattern fetching with frequency filtering
        final words = await getWordsByPattern(pattern, maxWords: 50);
        
        // Additional filtering for phonics appropriateness
        final filteredWords = words.where((word) {
          // Must be 2-6 letters for children
          if (word.length < 2 || word.length > 6) return false;
          
          // Check for simple CVC (consonant-vowel-consonant) patterns
          // Avoid complex consonant clusters at the beginning
          if (word.length >= 3) {
            final firstTwo = word.substring(0, 2);
            // Skip words starting with complex clusters like 'thr', 'spr', 'str'
            if (RegExp(r'^[bcdfghjklmnpqrstvwxyz]{3,}').hasMatch(word)) {
              return false;
            }
          }
          
          return true;
        }).toList();
        
        allWords.addAll(filteredWords);
        
        // If we have enough words, stop fetching
        if (allWords.length >= maxWords) break;
      } catch (e) {
        print('🔴 Error fetching pattern $pattern: $e');
      }
    }
    
    // Sort by length (shorter first) then alphabetically
    final sortedWords = allWords.toList()
      ..sort((a, b) {
        final lengthCompare = a.length.compareTo(b.length);
        return lengthCompare != 0 ? lengthCompare : a.compareTo(b);
      });
    
    return sortedWords.take(maxWords).toList();
  }
  
  /// Fetch words with specific sounds (for phonics patterns) using dynamic Datamuse queries
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
      
      // Build high-quality word lists dynamically from Datamuse with smart patterns
      List<String> phoneticWords = [];
      
      if (lowerSound.contains('short a')) {
        // Short 'a' patterns: CVC with 'a' in middle
        phoneticWords = await _buildPhonicsListFromDatamuse(
          ['?at', '?ad', '?an', '?am', '?ap', '?ag', '?ab', '?ack', '?and', '?amp'],
          maxWords: 150
        );
      } else if (lowerSound.contains('short e')) {
        // Short 'e' patterns
        phoneticWords = await _buildPhonicsListFromDatamuse(
          ['?ed', '?et', '?en', '?ell', '?ess', '?est', '?eg', '?em', '?ep', '?eck'],
          maxWords: 150
        );
      } else if (lowerSound.contains('short i')) {
        // Short 'i' patterns
        phoneticWords = await _buildPhonicsListFromDatamuse(
          ['?it', '?ig', '?in', '?ip', '?ick', '?ill', '?im', '?id', '?ish', '?ing'],
          maxWords: 150
        );
      } else if (lowerSound.contains('short o')) {
        // Short 'o' patterns
        phoneticWords = await _buildPhonicsListFromDatamuse(
          ['?ot', '?op', '?og', '?ock', '?ob', '?od', '?om', '?oss', '?ong', '?ox'],
          maxWords: 150
        );
      } else if (lowerSound.contains('short u')) {
        // Short 'u' patterns
        phoneticWords = await _buildPhonicsListFromDatamuse(
          ['?ut', '?un', '?up', '?ug', '?uck', '?ub', '?um', '?ump', '?ust', '?uff'],
          maxWords: 150
        );
      } else if (lowerSound.contains('long a')) {
        // Long 'a' patterns: a_e, ai, ay
        phoneticWords = await _buildPhonicsListFromDatamuse(
          ['?ake', '?ame', '?ate', '?ave', '?ade', '?ane', '?ace', '?ay', '?ain', '?ail'],
          maxWords: 150
        );
      } else if (lowerSound.contains('long e')) {
        // Long 'e' patterns: ee, ea, e_e
        phoneticWords = await _buildPhonicsListFromDatamuse(
          ['?ee', '?eet', '?een', '?eep', '?eed', '?ea', '?ead', '?ean', '?each', '?eam'],
          maxWords: 150
        );
      } else if (lowerSound.contains('long i')) {
        // Long 'i' patterns: i_e, igh, ie, y
        phoneticWords = await _buildPhonicsListFromDatamuse(
          ['?ike', '?ine', '?ime', '?ite', '?ide', '?ice', '?ight', '?y', '?ie', '?ire'],
          maxWords: 150
        );
      } else if (lowerSound.contains('long o')) {
        // Long 'o' patterns: o_e, oa, ow
        phoneticWords = await _buildPhonicsListFromDatamuse(
          ['?oke', '?one', '?ope', '?ose', '?ome', '?oat', '?oad', '?ow', '?own', '?old'],
          maxWords: 150
        );
      } else if (lowerSound.contains('long u')) {
        // Long 'u' patterns: u_e, ue, ew
        phoneticWords = await _buildPhonicsListFromDatamuse(
          ['?ute', '?ube', '?une', '?use', '?ue', '?ew', '?ool', '?oom', '?oon', '?oot'],
          maxWords: 150
        );
      }
      
      // If we didn't get enough words from Datamuse, use fallback hardcoded lists
      if (phoneticWords.length < 20) {
        print('⚠️ Datamuse returned only ${phoneticWords.length} words, using fallback lists');
        phoneticWords = _getFallbackPhonicsWords(lowerSound);
      }
      
      print('📚 Datamuse: Generated phonics list for "$sound", found ${phoneticWords.length} words');
      
      // Filter by length if specified
      if (requiredLength != null) {
        phoneticWords = phoneticWords.where((word) => word.length == requiredLength).toList();
        print('📚 Datamuse: Filtered to ${phoneticWords.length} words with length $requiredLength');
      }
      
      // Ensure all words are child-appropriate (they should be since they're curated)
      phoneticWords = phoneticWords.where((word) => word.length >= 2 && word.length <= 6).toList();
      
      return phoneticWords.take(maxWords).toList();
      
    } catch (e) {
      print('🔴 Datamuse sound error: $e');
      return [];
    }
  }
  
  /// Fallback hardcoded lists when Datamuse doesn't return enough words
  static List<String> _getFallbackPhonicsWords(String lowerSound) {
    if (lowerSound.contains('short a')) {
      return ['cat', 'bat', 'hat', 'mat', 'rat', 'sat', 'pat', 'fat', 'can', 'man', 'ran', 'pan', 'fan', 'tan', 'van', 'bad', 'dad', 'had', 'mad', 'sad', 'bag', 'tag', 'nap', 'cap', 'map', 'tap', 'lap', 'gap'];
    } else if (lowerSound.contains('short e')) {
      return ['bed', 'red', 'fed', 'wed', 'net', 'bet', 'get', 'let', 'met', 'pet', 'set', 'wet', 'yet', 'pen', 'ten', 'men', 'hen', 'den', 'bell', 'tell', 'well', 'fell', 'sell', 'yell'];
    } else if (lowerSound.contains('short i')) {
      return ['bit', 'hit', 'sit', 'fit', 'kit', 'lit', 'pit', 'big', 'dig', 'fig', 'pig', 'wig', 'win', 'pin', 'tin', 'bin', 'fin', 'kick', 'lick', 'pick', 'sick', 'tick'];
    } else if (lowerSound.contains('short o')) {
      return ['hot', 'pot', 'dot', 'got', 'lot', 'not', 'cot', 'jot', 'rot', 'box', 'fox', 'top', 'hop', 'pop', 'cop', 'mop', 'shop', 'stop', 'drop', 'chop', 'dog', 'log', 'fog', 'hog', 'jog'];
    } else if (lowerSound.contains('short u')) {
      return ['cut', 'but', 'hut', 'nut', 'shut', 'run', 'sun', 'fun', 'bun', 'gun', 'bus', 'cup', 'pup', 'up', 'tub', 'rub', 'hub', 'duck', 'luck', 'buck', 'stuck', 'truck'];
    } else if (lowerSound.contains('long a')) {
      return ['cake', 'make', 'take', 'lake', 'bake', 'wake', 'game', 'name', 'same', 'came', 'tape', 'cape', 'gate', 'late', 'date', 'rate', 'brave', 'gave', 'save', 'wave', 'day', 'way', 'say', 'may', 'play'];
    } else if (lowerSound.contains('long e')) {
      return ['tree', 'free', 'three', 'see', 'bee', 'knee', 'she', 'he', 'we', 'me', 'be', 'feet', 'meet', 'sweet', 'green', 'seen', 'been', 'clean', 'mean', 'bean', 'dream', 'team'];
    } else if (lowerSound.contains('long i')) {
      return ['bike', 'like', 'hike', 'time', 'dime', 'lime', 'nine', 'line', 'mine', 'fine', 'pine', 'white', 'bite', 'kite', 'fire', 'tire', 'wire', 'pie', 'tie', 'lie', 'fly', 'try', 'dry', 'cry', 'sky'];
    } else if (lowerSound.contains('long o')) {
      return ['boat', 'coat', 'goat', 'road', 'toad', 'soap', 'rope', 'hope', 'note', 'vote', 'home', 'bone', 'cone', 'tone', 'nose', 'rose', 'slow', 'snow', 'grow', 'show', 'know', 'blow', 'flow'];
    } else if (lowerSound.contains('long u')) {
      return ['cute', 'tube', 'cube', 'huge', 'tune', 'blue', 'glue', 'true', 'due', 'sue', 'clue', 'flew', 'grew', 'threw', 'knew', 'blew', 'drew', 'crew', 'chew', 'few', 'new'];
    }
    return [];
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
      final endingMatch = RegExp("(?:ending|ends?) (?:in|with) [\"']?-?(\\w+)[\"']?").firstMatch(lowerPrompt);
      if (endingMatch != null) {
        final ending = endingMatch.group(1);
        return '?$ending'; // 3-letter CVC pattern
      }
      // Generic CVC pattern
      return '???';
    }
    
    // Check for word length + ending pattern
    final lengthMatch = RegExp(r'(\d+)\s*letter').firstMatch(lowerPrompt);
    final endingMatch = RegExp("(?:ending|ends?|that end) (?:in|with) [\"']?-?(\\w+)[\"']?").firstMatch(lowerPrompt);
    
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
  
  /// Main function to get words based on a teacher's prompt with enhanced word collection
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
    
    // Extract specific ending pattern if present
    String? specificEnding;
    final endingMatch = RegExp(r'(?:ending|end|ends|that end) (?:in|with) ["\x27]?-?(\w+)["\x27]?').firstMatch(lowerPrompt);
    if (endingMatch != null) {
      specificEnding = endingMatch.group(1);
      print('📚 Datamuse: Detected specific ending requirement: "$specificEnding"');
    } else {
      print('📚 Datamuse: No specific ending pattern detected in: "$lowerPrompt"');
    }
    
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
    
    // 3. ENHANCED: Pattern-based search with multiple approaches
    else if (hasLength || hasEnding) {
      print('📚 Datamuse: Processing pattern-based requirement with enhanced search');
      
      // Use enhanced search if we have a specific ending
      if (specificEnding != null) {
        print('📚 Datamuse: Calling _getMoreWordsForEnding with ending: "$specificEnding"');
        words = await _getMoreWordsForEnding(specificEnding, targetCount: 50);
        print('📚 Datamuse: _getMoreWordsForEnding returned ${words.length} words');
        
        // Filter by length if also specified
        final lengthMatch = RegExp(r'(\d+)\s*letter').firstMatch(lowerPrompt);
        if (lengthMatch != null) {
          final requiredLength = int.parse(lengthMatch.group(1)!);
          words = words.where((word) => word.length == requiredLength).toList();
          print('📚 Datamuse: Further filtered to ${words.length} words with length $requiredLength');
        }
      } else {
        // Fallback to original pattern method
        final pattern = extractPattern(prompt);
        if (pattern != null) {
          words = await getWordsByPattern(pattern);
        }
      }
      
      if (words.length >= 36) {
        print('📚 Datamuse: Enhanced pattern search found ${words.length} words');
        return words.take(36).toList();
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
    
    // CRITICAL: Filter inappropriate words for children and enforce length limits
    final childAppropriateWords = words
        .where((word) => word.length >= 2 && word.length <= 6) // Child-appropriate length
        .where((word) => ContentFilterService.isWordSafe(word))
        .toList();
    
    final removedCount = words.length - childAppropriateWords.length;
    if (removedCount > 0) {
      print('🚫 Datamuse: Filtered out $removedCount inappropriate/complex words');
    }
    
    print('📚 Datamuse: Returning ${childAppropriateWords.length} child-appropriate words');
    return childAppropriateWords;
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
  
  /// Get more words for ending patterns by trying multiple approaches and adding curated fallbacks
  static Future<List<String>> _getMoreWordsForEnding(String ending, {int targetCount = 50}) async {
    print('📚 Datamuse: _getMoreWordsForEnding called with ending: "$ending", targetCount: $targetCount');
    final allWords = <String>{};
    
    // Start with curated child-appropriate words for common patterns
    final curatedWords = _getCuratedWordsForEnding(ending);
    print('📚 Datamuse: _getCuratedWordsForEnding("$ending") returned: $curatedWords');
    allWords.addAll(curatedWords);
    print('📚 Datamuse: Added ${curatedWords.length} curated words for ending "$ending"');
    
    try {
      // Method 1: Direct pattern matching if we need more words
      if (allWords.length < targetCount) {
        final directWords = await getWordsByPattern('*$ending', maxWords: 100);
        allWords.addAll(directWords);
        print('📚 Datamuse: Direct pattern *$ending found ${directWords.length} additional words');
      }
      
      // Method 2: Try different lengths systematically
      for (int length = 3; length <= 6; length++) {
        if (allWords.length >= targetCount) break;
        
        final pattern = '${'?' * (length - ending.length)}$ending';
        if (length > ending.length) {
          final lengthWords = await getWordsByPattern(pattern, maxWords: 50);
          allWords.addAll(lengthWords);
          print('📚 Datamuse: Length $length pattern $pattern found ${lengthWords.length} words');
        }
      }
      
      // Method 3: If still not enough, try frequency-based fetching
      if (allWords.length < targetCount) {
        print('📚 Datamuse: Trying frequency-based approach for ending "$ending"');
        final uri = Uri.parse('$_baseUrl?sp=*$ending&md=f&max=200');
        final response = await http.get(uri);
        
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          final frequentWords = data
              .where((item) => (item['tags']?.toString().contains('f:') ?? false))
              .map((item) => item['word'].toString().toLowerCase())
              .where((word) => word.length <= 6) // Keep words short for children
              .where((word) => !word.contains('-') && !word.contains(' ') && !word.contains("'"))
              .where((word) => ContentFilterService.isWordSafe(word))
              .toList();
          allWords.addAll(frequentWords);
          print('📚 Datamuse: Frequency-based search added ${frequentWords.length} more words');
        }
      }
      
    } catch (e) {
      print('🔴 Datamuse: Error in enhanced word search: $e');
    }
    
    // Convert to list and ensure child-appropriate
    final finalWords = allWords
        .where((word) => word.length >= 2 && word.length <= 6) // Child-appropriate length
        .toList();
    
    print('📚 Datamuse: Enhanced search for "$ending" returned ${finalWords.length} total words');
    return finalWords;
  }

  /// Get curated child-appropriate words for specific endings
  static List<String> _getCuratedWordsForEnding(String ending) {
    switch (ending.toLowerCase()) {
      case 'un':
        return ['run', 'sun', 'fun', 'bun', 'gun', 'nun', 'pun', 'dun', 'spun', 'stun', 'shun'];
      case 'at':
        return ['cat', 'bat', 'hat', 'mat', 'rat', 'sat', 'pat', 'fat', 'vat', 'chat', 'flat', 'that'];
      case 'it':
        return ['sit', 'hit', 'bit', 'fit', 'kit', 'lit', 'pit', 'wit', 'quit', 'spit', 'knit', 'grit', 'slit', 'flit', 'split'];
      case 'an':
        return ['can', 'man', 'ran', 'pan', 'fan', 'tan', 'ban', 'van', 'plan', 'than', 'scan', 'span'];
      case 'in':
        return ['pin', 'win', 'tin', 'bin', 'fin', 'chin', 'thin', 'skin', 'spin', 'grin', 'twin', 'shin'];
      case 'ot':
        return ['hot', 'pot', 'dot', 'got', 'lot', 'not', 'cot', 'jot', 'rot', 'tot', 'shot', 'spot', 'plot', 'knot', 'slot'];
      case 'ut':
        return ['cut', 'but', 'hut', 'nut', 'put', 'gut', 'jut', 'rut', 'shut'];
      case 'ay':
        return ['day', 'way', 'say', 'may', 'bay', 'hay', 'lay', 'pay', 'play', 'stay', 'pray', 'gray', 'clay', 'tray'];
      case 'ed':
        return ['red', 'bed', 'fed', 'wed', 'led', 'shed', 'sled'];
      case 'et':
        return ['pet', 'get', 'let', 'met', 'net', 'set', 'bet', 'jet', 'wet', 'yet', 'vet'];
      case 'en':
        return ['pen', 'ten', 'men', 'hen', 'den', 'when', 'then'];
      case 'ig':
        return ['big', 'dig', 'fig', 'pig', 'wig', 'jig', 'rig'];
      case 'og':
        return ['dog', 'log', 'hog', 'jog', 'fog', 'bog', 'cog', 'frog'];
      case 'ug':
        return ['bug', 'hug', 'jug', 'mug', 'rug', 'tug', 'dug', 'pug'];
      default:
        return [];
    }
  }

  /// Organize words into a 6x6 grid with intelligent padding using pattern-matching fallbacks
  static List<List<String>> organizeIntoGrid(List<String> words) {
    List<List<String>> grid = [];
    List<String> finalWords = List<String>.from(words);
    
    print('📚 Datamuse: Starting with ${finalWords.length} words for grid organization');
    
    // If we don't have enough words, use pattern-specific fallbacks
    if (finalWords.length < 36) {
      print('📚 Datamuse: Need ${36 - finalWords.length} more words, using intelligent fallbacks');
      
      // Analyze existing words to determine the pattern
      String? detectedPattern = _detectWordPattern(finalWords);
      print('📚 Datamuse: Detected pattern: $detectedPattern');
      
      // Get appropriate fallback words based on the detected pattern
      final fallbackWords = _getPatternSpecificFallbacks(detectedPattern, finalWords);
      
      // Add fallback words until we have enough
      for (final fallbackWord in fallbackWords) {
        if (finalWords.length >= 36) break;
        if (!finalWords.contains(fallbackWord)) {
          finalWords.add(fallbackWord);
        }
      }
      
      // If still not enough, repeat valid words (better than adding numbers)
      final validWordsForRepeating = List<String>.from(finalWords);
      int repeatIndex = 0;
      while (finalWords.length < 36 && validWordsForRepeating.isNotEmpty) {
        finalWords.add(validWordsForRepeating[repeatIndex % validWordsForRepeating.length]);
        repeatIndex++;
      }
      
      // Absolute last resort - use simple default words
      final absoluteDefaults = ['cat', 'dog', 'run', 'sun', 'big', 'red', 'top', 'hop', 'sit', 'hit'];
      int defaultIndex = 0;
      while (finalWords.length < 36) {
        finalWords.add(absoluteDefaults[defaultIndex % absoluteDefaults.length]);
        defaultIndex++;
      }
    }
    
    // Ensure exactly 36 words
    if (finalWords.length > 36) {
      finalWords = finalWords.take(36).toList();
    }
    
    print('📚 Datamuse: Final word count: ${finalWords.length}');
    print('📚 Datamuse: Sample final words: ${finalWords.take(10).join(", ")}');
    
    // Create 6 rows of 6 columns
    for (int i = 0; i < 6; i++) {
      List<String> row = [];
      for (int j = 0; j < 6; j++) {
        int index = i * 6 + j;
        if (index < finalWords.length) {
          row.add(finalWords[index]);
        }
      }
      grid.add(row);
    }
    
    return grid;
  }

  /// Detect the word pattern from existing words
  static String? _detectWordPattern(List<String> words) {
    if (words.isEmpty) return null;
    
    // Check for common ending patterns
    final endingCounts = <String, int>{};
    for (final word in words.take(5)) { // Check first 5 words to detect pattern
      if (word.length >= 2) {
        final ending2 = word.substring(word.length - 2);
        endingCounts[ending2] = (endingCounts[ending2] ?? 0) + 1;
      }
    }
    
    // Find most common 2-letter ending
    final commonEnding = endingCounts.entries
        .where((e) => e.value >= 2)
        .fold<MapEntry<String, int>?>(null, (prev, curr) => 
          prev == null || curr.value > prev.value ? curr : prev);
    
    return commonEnding?.key;
  }

  /// Get pattern-specific fallback words that match the detected pattern
  static List<String> _getPatternSpecificFallbacks(String? pattern, List<String> existingWords) {
    if (pattern == null) {
      return ['cat', 'dog', 'run', 'sun', 'big', 'red', 'top', 'hop', 'sit', 'hit'];
    }
    
    switch (pattern) {
      case 'un':
        return ['run', 'sun', 'fun', 'bun', 'gun', 'nun', 'pun', 'dun', 'spun', 'stun'];
      case 'at':
        return ['cat', 'bat', 'hat', 'mat', 'rat', 'sat', 'pat', 'fat', 'vat', 'chat'];
      case 'it':
        return ['sit', 'hit', 'bit', 'fit', 'kit', 'lit', 'pit', 'wit', 'quit', 'spit'];
      case 'an':
        return ['can', 'man', 'ran', 'pan', 'fan', 'tan', 'ban', 'van', 'plan', 'scan'];
      case 'in':
        return ['pin', 'win', 'tin', 'bin', 'fin', 'chin', 'thin', 'skin', 'spin', 'grin'];
      case 'ot':
        return ['hot', 'pot', 'dot', 'got', 'lot', 'not', 'cot', 'jot', 'rot', 'tot'];
      case 'ut':
        return ['cut', 'but', 'hut', 'nut', 'put', 'gut', 'jut', 'rut', 'shut'];
      case 'ay':
        return ['day', 'way', 'say', 'may', 'bay', 'hay', 'lay', 'pay', 'play', 'stay'];
      case 'ed':
        return ['red', 'bed', 'fed', 'wed', 'led', 'shed', 'sled'];
      case 'et':
        return ['pet', 'get', 'let', 'met', 'net', 'set', 'bet', 'jet', 'wet', 'yet'];
      default:
        // Use generic simple words
        return ['cat', 'dog', 'run', 'sun', 'big', 'red', 'top', 'hop', 'sit', 'hit'];
    }
  }
}