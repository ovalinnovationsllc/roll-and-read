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
      
      if (lowerSound.contains('short a') || lowerSound.contains('soft a')) {
        // /æ/ sound - use CURATED LISTS ONLY, no Datamuse for vowel sounds
        phoneticWords = _getFallbackPhonicsWords(lowerSound);
      } else if (lowerSound.contains('short e') || lowerSound.contains('soft e')) {
        // /ɛ/ sound - use CURATED LISTS ONLY
        phoneticWords = _getFallbackPhonicsWords(lowerSound);
      } else if (lowerSound.contains('short i') || lowerSound.contains('soft i')) {
        // /ɪ/ sound - use CURATED LISTS ONLY
        phoneticWords = _getFallbackPhonicsWords(lowerSound);
      } else if (lowerSound.contains('short o') || lowerSound.contains('soft o')) {
        // /ɑ/ sound - use CURATED LISTS ONLY
        phoneticWords = _getFallbackPhonicsWords(lowerSound);
      } else if (lowerSound.contains('short u') || lowerSound.contains('soft u')) {
        // /ʌ/ sound - use CURATED LISTS ONLY
        phoneticWords = _getFallbackPhonicsWords(lowerSound);
      } else if (lowerSound.contains('long a') || lowerSound.contains('hard a')) {
        // /eɪ/ sound - use CURATED LISTS ONLY
        phoneticWords = _getFallbackPhonicsWords(lowerSound);
      } else if (lowerSound.contains('long e') || lowerSound.contains('hard e')) {
        // /i/ sound - use CURATED LISTS ONLY
        phoneticWords = _getFallbackPhonicsWords(lowerSound);
      } else if (lowerSound.contains('long i') || lowerSound.contains('hard i')) {
        // /aɪ/ sound - use CURATED LISTS ONLY
        phoneticWords = _getFallbackPhonicsWords(lowerSound);
      } else if (lowerSound.contains('long o') || lowerSound.contains('hard o')) {
        // /oʊ/ sound - use CURATED LISTS ONLY
        phoneticWords = _getFallbackPhonicsWords(lowerSound);
      } else if (lowerSound.contains('long u') || lowerSound.contains('hard u')) {
        // /u/ sound - use CURATED LISTS ONLY
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
  
  /// Fallback phonetically accurate lists when Datamuse doesn't return enough words
  /// These lists are CURATED to contain ONLY words with the correct phonetic sound
  static List<String> _getFallbackPhonicsWords(String lowerSound) {
    if (lowerSound.contains('short a') || lowerSound.contains('soft a')) {
      // /æ/ sound ONLY - EXPANDED list of short A words (NOT sky, cloud, pink, orange!)
      return [
        // CVC patterns with /æ/
        'cat', 'bat', 'hat', 'mat', 'rat', 'sat', 'pat', 'fat', 'vat', 'chat', 'flat', 'that',
        'can', 'man', 'ran', 'pan', 'fan', 'tan', 'ban', 'van', 'plan', 'than', 'scan', 'span',
        'bad', 'dad', 'had', 'mad', 'sad', 'pad', 'lad', 'glad',
        'bag', 'tag', 'rag', 'lag', 'sag', 'wag', 'flag', 'drag',
        'cap', 'map', 'tap', 'lap', 'gap', 'nap', 'sap', 'clap', 'snap', 'trap',
        'cab', 'tab', 'lab', 'nab', 'jab', 'crab', 'grab',
        'ham', 'jam', 'ram', 'dam', 'yam', 'clam', 'gram',
        'ax', 'wax', 'tax', 'max'
      ];
    } else if (lowerSound.contains('short e') || lowerSound.contains('soft e')) {
      // /ɛ/ sound ONLY - EXPANDED list of short E words
      return [
        'bed', 'red', 'fed', 'wed', 'led', 'shed', 'sled',
        'net', 'bet', 'get', 'let', 'met', 'pet', 'set', 'wet', 'yet', 'jet', 'vet',
        'pen', 'ten', 'men', 'hen', 'den', 'when', 'then',
        'leg', 'beg', 'peg', 'keg', 'egg',
        'web', 'deb',
        'gem', 'hem', 'stem', 'them',
        'bell', 'cell', 'fell', 'hell', 'sell', 'tell', 'well', 'yell',
        'end', 'bend', 'lend', 'mend', 'send', 'tend'
      ];
    } else if (lowerSound.contains('short i') || lowerSound.contains('soft i')) {
      // /ɪ/ sound ONLY - EXPANDED list of short I words
      return [
        'bit', 'hit', 'sit', 'fit', 'kit', 'lit', 'pit', 'wit', 'quit', 'spit', 'knit', 'grit',
        'big', 'dig', 'fig', 'pig', 'wig', 'jig', 'rig',
        'win', 'pin', 'tin', 'bin', 'fin', 'chin', 'thin', 'skin', 'spin', 'grin', 'twin', 'shin',
        'kid', 'lid', 'bid', 'did', 'hid', 'rid', 'skid',
        'tip', 'zip', 'rip', 'hip', 'lip', 'dip', 'ship', 'chip', 'skip', 'trip',
        'rib', 'bib',
        'rim', 'dim', 'him', 'tim', 'swim', 'slim', 'trim',
        'six', 'mix', 'fix'
      ];
    } else if (lowerSound.contains('short o') || lowerSound.contains('soft o')) {
      // /ɑ/ sound ONLY - EXPANDED list of short O words (NOT "caught" type words!)
      return [
        'hot', 'pot', 'dot', 'lot', 'not', 'cot', 'jot', 'rot', 'tot', 'got',
        'top', 'hop', 'pop', 'cop', 'mop', 'shop', 'stop', 'drop', 'chop',
        'dog', 'log', 'hog', 'jog', 'fog', 'bog', 'cog', 'frog',
        'job', 'rob', 'mob', 'sob', 'bob', 'glob',
        'nod', 'rod', 'cod', 'sod', 'pod',
        'mom', 'tom', 'bomb', 'from',
        'box', 'fox', 'ox', 'sox'
      ];
    } else if (lowerSound.contains('short u') || lowerSound.contains('soft u')) {
      // /ʌ/ sound ONLY - EXPANDED list of short U words
      return [
        'cut', 'but', 'hut', 'nut', 'shut', 'gut', 'jut', 'rut',
        'run', 'sun', 'fun', 'bun', 'gun', 'nun', 'pun', 'spun', 'stun',
        'cup', 'pup', 'up', 'sup',
        'bug', 'hug', 'jug', 'mug', 'rug', 'tug', 'dug', 'pug',
        'mud', 'bud', 'cud', 'dud', 'thud', 'stud',
        'tub', 'rub', 'hub', 'sub', 'club', 'grub',
        'gum', 'hum', 'sum', 'rum', 'drum', 'plum', 'chum',
        'bus', 'plus'
      ];
    } else if (lowerSound.contains('long a') || lowerSound.contains('hard a')) {
      // /eɪ/ sound ONLY - EXPANDED list of long A words
      return [
        // Magic e pattern
        'cake', 'make', 'take', 'lake', 'bake', 'wake', 'fake', 'rake', 'snake', 'shake',
        'game', 'name', 'same', 'came', 'fame', 'tame', 'frame', 'blame', 'flame',
        'tape', 'cape', 'grape', 'shape',
        'gate', 'late', 'date', 'rate', 'hate', 'fate', 'state', 'plate',
        'cave', 'wave', 'gave', 'save', 'brave', 'shave',
        // AI pattern
        'rain', 'main', 'pain', 'gain', 'train', 'brain', 'chain', 'plain', 'stain',
        'wait', 'bait', 'trait',
        // AY pattern
        'day', 'way', 'say', 'may', 'bay', 'hay', 'lay', 'pay', 'play', 'stay', 'pray', 'gray', 'clay', 'tray'
      ];
    } else if (lowerSound.contains('long e') || lowerSound.contains('hard e')) {
      // /i/ sound ONLY - EXPANDED list of long E words
      return [
        // EE pattern
        'see', 'bee', 'tree', 'free', 'knee', 'three', 'agree', 'flee',
        'feet', 'meet', 'greet', 'sweet', 'sheet', 'steel', 'wheel',
        'green', 'seen', 'been', 'queen', 'screen', 'teen',
        'keep', 'deep', 'sleep', 'sheep', 'creep', 'steep', 'sweep',
        // EA pattern
        'read', 'eat', 'meat', 'beat', 'heat', 'seat', 'neat', 'treat',
        'clean', 'mean', 'bean', 'lean', 'dream', 'cream', 'steam', 'team',
        'beach', 'teach', 'reach', 'peach'
      ];
    } else if (lowerSound.contains('long i') || lowerSound.contains('hard i')) {
      // /aɪ/ sound ONLY - EXPANDED list of long I words
      return [
        // Magic e pattern
        'bike', 'like', 'hike', 'mike', 'strike',
        'time', 'dime', 'lime', 'chime', 'crime', 'grime', 'prime',
        'nine', 'line', 'mine', 'fine', 'pine', 'wine', 'dine', 'shine', 'spine', 'whine',
        'bite', 'kite', 'site', 'white', 'quite', 'write',
        'hide', 'ride', 'side', 'wide', 'slide', 'bride', 'guide', 'pride',
        // IGH pattern
        'night', 'light', 'right', 'bright', 'sight', 'fight', 'might', 'tight', 'flight',
        // Y pattern
        'fly', 'try', 'dry', 'cry', 'sky', 'my', 'by', 'shy', 'spy', 'fry'
      ];
    } else if (lowerSound.contains('long o') || lowerSound.contains('hard o')) {
      // /oʊ/ sound ONLY - EXPANDED list of long O words
      return [
        // OA pattern
        'boat', 'coat', 'goat', 'float', 'throat',
        'road', 'toad', 'load',
        'soap', 'loaf',
        // Magic e pattern
        'hope', 'rope', 'slope', 'scope',
        'note', 'vote', 'quote', 'wrote',
        'home', 'dome', 'come', 'some',
        'bone', 'cone', 'tone', 'phone', 'stone', 'throne', 'alone',
        'nose', 'rose', 'hose', 'chose', 'close', 'those',
        'hole', 'pole', 'role', 'whole', 'stole',
        // OW pattern
        'go', 'no', 'so', 'pro',
        'show', 'snow', 'grow', 'slow', 'blow', 'flow', 'glow', 'throw', 'know'
      ];
    } else if (lowerSound.contains('long u') || lowerSound.contains('hard u')) {
      // /u/ sound ONLY - EXPANDED list of long U words
      return [
        // OO pattern (long u)
        'moon', 'soon', 'noon', 'spoon', 'cartoon',
        'room', 'boom', 'zoom', 'broom', 'gloom',
        'cool', 'pool', 'tool', 'school', 'stool', 'drool',
        'food', 'mood', 'good', 'hood', 'wood', 'stood',
        'book', 'look', 'took', 'cook', 'hook', 'brook', 'shook',
        'boot', 'root', 'shoot', 'scoot',
        // UE pattern
        'blue', 'true', 'glue', 'clue', 'due', 'flue',
        // EW pattern
        'new', 'few', 'grew', 'drew', 'knew', 'flew', 'threw', 'crew', 'chew', 'stew'
      ];
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
    bool hasSound = lowerPrompt.contains('sound') || lowerPrompt.contains('long') || lowerPrompt.contains('short') || lowerPrompt.contains('soft') || lowerPrompt.contains('hard');
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
           lowerPrompt.contains('soft') ||
           lowerPrompt.contains('hard') ||
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
      // PHONETICALLY CORRECT METHOD: Instead of using spelling patterns,
      // we'll use specific phonetic patterns that actually sound right
      if (allWords.length < targetCount) {
        final phoneticWords = await _getPhoneticWordsForEnding(ending);
        allWords.addAll(phoneticWords);
        print('📚 Datamuse: Phonetic search for "$ending" found ${phoneticWords.length} words');
      }
      
      // Method 3: Final fallback - use direct spelling pattern but filter phonetically
      if (allWords.length < targetCount) {
        print('📚 Datamuse: Trying filtered spelling pattern as final fallback for ending "$ending"');
        final spellingWords = await getWordsByPattern('*$ending', maxWords: 200);
        
        // Filter to only words that are phonetically similar to our curated words
        final curatedExamples = _getCuratedWordsForEnding(ending);
        if (curatedExamples.isNotEmpty) {
          final phoneticFiltered = spellingWords.where((word) => 
            _isPhoneticallyCompatible(word, ending, curatedExamples)
          ).toList();
          
          allWords.addAll(phoneticFiltered);
          print('📚 Datamuse: Spelling pattern filtered to ${phoneticFiltered.length} phonetically compatible words');
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


  /// Get phonetically correct words for ending using Datamuse rhyme API
  /// This uses rhyming to find words that actually SOUND like the ending
  static Future<List<String>> _getPhoneticWordsForEnding(String ending) async {
    final Set<String> phoneticWords = <String>{};
    
    try {
      // Use a known word with this ending as a rhyme seed
      String? seedWord = _getSeedWordForEnding(ending);
      
      if (seedWord != null) {
        // Get rhyming words - these will have the same phonetic ending
        final rhymeUri = Uri.parse('$_baseUrl?rel_rhy=$seedWord&max=100');
        final response = await http.get(rhymeUri);
        
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          final rhymeWords = data
              .map((item) => item['word'].toString().toLowerCase())
              .where((word) => word.length >= 2 && word.length <= 6)
              .where((word) => !word.contains('-') && !word.contains(' ') && !word.contains("'"))
              .where((word) => ContentFilterService.isWordSafe(word))
              .toList();
          
          phoneticWords.addAll(rhymeWords);
          print('📚 Datamuse: Rhyme search with "$seedWord" found ${rhymeWords.length} phonetic matches');
        }
      }
      
      // Also try multiple seed words if we have them
      final altSeeds = _getAlternateSeedWords(ending);
      for (final altSeed in altSeeds) {
        if (phoneticWords.length >= 50) break;
        
        final rhymeUri = Uri.parse('$_baseUrl?rel_rhy=$altSeed&max=50');
        final response = await http.get(rhymeUri);
        
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          final rhymeWords = data
              .map((item) => item['word'].toString().toLowerCase())
              .where((word) => word.length >= 2 && word.length <= 6)
              .where((word) => !word.contains('-') && !word.contains(' ') && !word.contains("'"))
              .where((word) => ContentFilterService.isWordSafe(word))
              .toList();
          
          phoneticWords.addAll(rhymeWords);
        }
      }
      
    } catch (e) {
      print('❌ Datamuse: Error in phonetic search for "$ending": $e');
    }
    
    return phoneticWords.toList();
  }
  
  /// Get a reliable seed word that definitely has this phonetic ending
  static String? _getSeedWordForEnding(String ending) {
    switch (ending.toLowerCase()) {
      // VOWEL + T endings
      case 'at': return 'cat';  // /æt/ sound
      case 'it': return 'sit';  // /ɪt/ sound  
      case 'ot': return 'pot';  // /ɑt/ sound
      case 'ut': return 'cut';  // /ʌt/ sound
      case 'et': return 'bet';  // /ɛt/ sound
      
      // VOWEL + N endings
      case 'an': return 'can';  // /æn/ sound
      case 'in': return 'win';  // /ɪn/ sound
      case 'on': return 'con';  // /ɑn/ sound (rare, most -on is /ʌn/)
      case 'un': return 'fun';  // /ʌn/ sound
      case 'en': return 'pen';  // /ɛn/ sound
      
      // VOWEL + P endings
      case 'ap': return 'cap';  // /æp/ sound
      case 'ip': return 'tip';  // /ɪp/ sound
      case 'op': return 'top';  // /ɑp/ sound
      case 'up': return 'cup';  // /ʌp/ sound
      case 'ep': return 'step'; // /ɛp/ sound
      
      // VOWEL + G endings
      case 'ag': return 'bag';  // /æg/ sound
      case 'ig': return 'big';  // /ɪg/ sound
      case 'og': return 'dog';  // /ɑg/ sound
      case 'ug': return 'bug';  // /ʌg/ sound
      case 'eg': return 'leg';  // /ɛg/ sound
      
      // VOWEL + D endings
      case 'ad': return 'bad';  // /æd/ sound
      case 'id': return 'kid';  // /ɪd/ sound
      case 'od': return 'nod';  // /ɑd/ sound
      case 'ud': return 'mud';  // /ʌd/ sound
      case 'ed': return 'bed';  // /ɛd/ sound
      
      // VOWEL + B endings
      case 'ab': return 'cab';  // /æb/ sound
      case 'ib': return 'rib';  // /ɪb/ sound
      case 'ob': return 'job';  // /ɑb/ sound
      case 'ub': return 'tub';  // /ʌb/ sound
      case 'eb': return 'web';  // /ɛb/ sound
      
      // VOWEL + M endings
      case 'am': return 'ham';  // /æm/ sound
      case 'im': return 'rim';  // /ɪm/ sound
      case 'om': return 'mom';  // /ɑm/ sound
      case 'um': return 'gum';  // /ʌm/ sound
      case 'em': return 'gem';  // /ɛm/ sound
      
      default: return null;
    }
  }
  
  /// Get alternate seed words for more phonetic matches
  static List<String> _getAlternateSeedWords(String ending) {
    switch (ending.toLowerCase()) {
      // VOWEL + T endings
      case 'at': return ['bat', 'hat', 'mat', 'rat', 'sat', 'pat', 'fat'];
      case 'it': return ['bit', 'hit', 'fit', 'kit', 'lit', 'pit', 'wit'];
      case 'ot': return ['pot', 'dot', 'cot', 'lot', 'hot', 'not', 'jot'];
      case 'ut': return ['but', 'hut', 'nut', 'shut', 'gut', 'rut'];
      case 'et': return ['get', 'let', 'met', 'pet', 'set', 'wet', 'net'];
      
      // VOWEL + N endings
      case 'an': return ['man', 'ran', 'pan', 'fan', 'tan', 'van', 'ban'];
      case 'in': return ['pin', 'tin', 'bin', 'fin', 'chin', 'thin', 'skin'];
      case 'on': return ['con']; // most -on words are /ʌn/ not /ɑn/
      case 'un': return ['run', 'sun', 'bun', 'gun', 'nun', 'pun'];
      case 'en': return ['pen', 'ten', 'men', 'hen', 'den', 'when'];
      
      // VOWEL + P endings
      case 'ap': return ['cap', 'map', 'tap', 'lap', 'gap', 'nap', 'sap'];
      case 'ip': return ['tip', 'zip', 'rip', 'hip', 'lip', 'dip', 'ship'];
      case 'op': return ['top', 'hop', 'pop', 'cop', 'mop', 'shop', 'stop'];
      case 'up': return ['cup', 'pup', 'sup'];
      case 'ep': return ['step', 'prep'];
      
      // VOWEL + G endings
      case 'ag': return ['bag', 'tag', 'rag', 'lag', 'sag', 'wag'];
      case 'ig': return ['big', 'dig', 'fig', 'pig', 'wig', 'jig'];
      case 'og': return ['dog', 'log', 'fog', 'hog', 'jog', 'clog'];
      case 'ug': return ['bug', 'hug', 'mug', 'rug', 'tug', 'jug'];
      case 'eg': return ['leg', 'beg', 'peg', 'keg'];
      
      // VOWEL + D endings
      case 'ad': return ['bad', 'dad', 'had', 'mad', 'sad', 'pad'];
      case 'id': return ['kid', 'lid', 'bid', 'did'];
      case 'od': return ['nod', 'rod', 'cod', 'sod'];
      case 'ud': return ['mud', 'bud', 'cud', 'dud', 'thud'];
      case 'ed': return ['bed', 'red', 'led', 'wed', 'fed'];
      
      // VOWEL + B endings
      case 'ab': return ['cab', 'tab', 'lab', 'nab', 'jab'];
      case 'ib': return ['rib', 'bib'];
      case 'ob': return ['job', 'rob', 'mob', 'sob', 'bob'];
      case 'ub': return ['tub', 'rub', 'hub', 'sub', 'club'];
      case 'eb': return ['web', 'deb'];
      
      // VOWEL + M endings
      case 'am': return ['ham', 'jam', 'ram', 'dam', 'yam'];
      case 'im': return ['rim', 'dim', 'him', 'tim', 'swim'];
      case 'om': return ['mom', 'tom', 'bomb'];
      case 'um': return ['gum', 'hum', 'sum', 'rum', 'drum'];
      case 'em': return ['gem', 'hem', 'stem'];
      
      default: return [];
    }
  }
  
  /// Check if a word is phonetically compatible with the intended ending pattern
  /// This filters out spelling matches that don't sound right
  static bool _isPhoneticallyCompatible(String word, String ending, List<String> examples) {
    final lowerWord = word.toLowerCase();
    final lowerEnding = ending.toLowerCase();
    
    // Basic length check - don't allow words that are too long for children
    if (lowerWord.length > 6) return false;
    
    // COMPLETE PHONETIC FILTERING FOR ALL PATTERNS
    switch (lowerEnding) {
      case 'at':
        // /æt/ sound: cat, bat, hat
        if (lowerWord.endsWith('eat') || // treat, neat, great (/it/ or /eɪt/)
            lowerWord.endsWith('oat') || // boat, coat, float (/oʊt/)
            lowerWord.endsWith('uat') || // squat (/wɑt/)
            lowerWord.contains('ea') ||  // sweat, threat (/ɛt/)
            lowerWord.length > 5) {
          return false;
        }
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[a][bcdfghjklmnpqrstvwxyz]*at$').hasMatch(lowerWord);
        
      case 'it':
        // /ɪt/ sound: sit, bit, hit
        if (lowerWord.endsWith('ait') || // wait, trait (/eɪt/)
            lowerWord.endsWith('uit') || // fruit, suit (/ut/)
            lowerWord.endsWith('eit') || // counterfeit (complex)
            lowerWord.contains('igh') || // fight, light (/aɪt/)
            lowerWord.length > 5) {
          return false;
        }
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[i][bcdfghjklmnpqrstvwxyz]*it$').hasMatch(lowerWord);
        
      case 'ot':
        // /ɑt/ sound: hot, pot, dot  
        if (lowerWord.endsWith('oot') || // boot, root (/ut/)
            lowerWord.endsWith('out') || // shout, scout (/aʊt/)
            lowerWord.endsWith('aught') || // caught, bought (/ɔt/)
            lowerWord.endsWith('ought') || // thought, brought (/ɔt/)
            lowerWord.contains('augh') || lowerWord.contains('ough') ||
            lowerWord.length > 4) {
          return false;
        }
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[o][bcdfghjklmnpqrstvwxyz]*ot$').hasMatch(lowerWord);
        
      case 'ut':
        // /ʌt/ sound: cut, but, hut
        if (lowerWord.endsWith('oot') || // shoot (/ut/)
            lowerWord.endsWith('out') || // about (/aʊt/)
            lowerWord.contains('ough') || // drought (/aʊt/)
            lowerWord.length > 5) {
          return false;
        }
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[u][bcdfghjklmnpqrstvwxyz]*ut$').hasMatch(lowerWord);
        
      case 'et':
        // /ɛt/ sound: bet, get, let
        if (lowerWord.endsWith('eet') || // meet, street (/it/)
            lowerWord.contains('ea') ||  // meat, beat (/it/)
            lowerWord.length > 5) {
          return false;
        }
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[e][bcdfghjklmnpqrstvwxyz]*et$').hasMatch(lowerWord);
        
      case 'an':
        // /æn/ sound: can, man, ran
        if (lowerWord.contains('ea') ||  // bean, mean (/in/)
            lowerWord.endsWith('oan') || // loan (/oʊn/)
            lowerWord.length > 5) {
          return false;
        }
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[a][bcdfghjklmnpqrstvwxyz]*an$').hasMatch(lowerWord);
        
      case 'in':
        // /ɪn/ sound: pin, win, tin
        if (lowerWord.endsWith('ain') || // rain, main (/eɪn/)
            lowerWord.endsWith('oin') || // coin, join (/ɔɪn/)
            lowerWord.contains('igh') || // sign (/aɪn/)
            lowerWord.length > 5) {
          return false;
        }
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[i][bcdfghjklmnpqrstvwxyz]*in$').hasMatch(lowerWord);
        
      case 'on':
        // /ɑn/ sound: con (NOTE: most -on words are actually /ʌn/ like "son")
        if (lowerWord.endsWith('oon') || // moon, spoon (/un/)
            lowerWord.endsWith('own') || // down, town (/aʊn/)
            lowerWord.length > 4) {
          return false;
        }
        return true;
        
      case 'un':
        // /ʌn/ sound: fun, run, sun
        if (lowerWord.endsWith('oun') || // noun, found (/aʊn/)
            lowerWord.endsWith('oon') || // moon, soon (/un/)
            lowerWord.length > 5) {
          return false;
        }
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[u][bcdfghjklmnpqrstvwxyz]*un$').hasMatch(lowerWord);
        
      case 'en':
        // /ɛn/ sound: pen, ten, men
        if (lowerWord.contains('ea') ||  // bean, mean (/in/)
            lowerWord.endsWith('een') || // seen, green (/in/)
            lowerWord.length > 5) {
          return false;
        }
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[e][bcdfghjklmnpqrstvwxyz]*en$').hasMatch(lowerWord);
        
      case 'ap':
        // /æp/ sound: cap, map, tap
        if (lowerWord.endsWith('eap') || // heap, leap (/ip/)
            lowerWord.endsWith('oop') || // loop, hoop (/up/)
            lowerWord.length > 5) {
          return false;
        }
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[a][bcdfghjklmnpqrstvwxyz]*ap$').hasMatch(lowerWord);
        
      case 'ip':
        // /ɪp/ sound: tip, zip, rip
        if (lowerWord.endsWith('eep') || // deep, keep (/ip/)
            lowerWord.endsWith('oop') || // loop, hoop (/up/)
            lowerWord.length > 5) {
          return false;
        }
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[i][bcdfghjklmnpqrstvwxyz]*ip$').hasMatch(lowerWord);
        
      case 'op':
        // /ɑp/ sound: top, hop, pop
        if (lowerWord.endsWith('oop') || // loop, hoop (/up/)
            lowerWord.endsWith('eep') || // deep, keep (/ip/)
            lowerWord.length > 4) {
          return false;
        }
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[o][bcdfghjklmnpqrstvwxyz]*op$').hasMatch(lowerWord);
        
      case 'up':
        // /ʌp/ sound: cup, pup, up
        if (lowerWord.endsWith('oup') || // soup, group (/up/)
            lowerWord.endsWith('eep') || // deep, keep (/ip/)
            lowerWord.length > 5) {
          return false;
        }
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[u][bcdfghjklmnpqrstvwxyz]*up$').hasMatch(lowerWord);
        
      case 'ep':
        // /ɛp/ sound: step (rare ending)
        if (lowerWord.endsWith('eep') || // deep, keep (/ip/)
            lowerWord.length > 5) {
          return false;
        }
        return true;
        
      // VOWEL + G endings
      case 'ag':
        // /æg/ sound: bag, tag, rag
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[a][bcdfghjklmnpqrstvwxyz]*ag$').hasMatch(lowerWord) && lowerWord.length <= 5;
      case 'ig':
        // /ɪg/ sound: big, dig, fig
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[i][bcdfghjklmnpqrstvwxyz]*ig$').hasMatch(lowerWord) && lowerWord.length <= 5;
      case 'og':
        // /ɑg/ sound: dog, log, fog
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[o][bcdfghjklmnpqrstvwxyz]*og$').hasMatch(lowerWord) && lowerWord.length <= 5;
      case 'ug':
        // /ʌg/ sound: bug, hug, jug
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[u][bcdfghjklmnpqrstvwxyz]*ug$').hasMatch(lowerWord) && lowerWord.length <= 5;
      case 'eg':
        // /ɛg/ sound: leg, beg, peg
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[e][bcdfghjklmnpqrstvwxyz]*eg$').hasMatch(lowerWord) && lowerWord.length <= 5;
        
      // VOWEL + D endings
      case 'ad':
        // /æd/ sound: bad, dad, had
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[a][bcdfghjklmnpqrstvwxyz]*ad$').hasMatch(lowerWord) && lowerWord.length <= 5;
      case 'id':
        // /ɪd/ sound: kid, lid, bid
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[i][bcdfghjklmnpqrstvwxyz]*id$').hasMatch(lowerWord) && lowerWord.length <= 5;
      case 'od':
        // /ɑd/ sound: nod, rod, cod
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[o][bcdfghjklmnpqrstvwxyz]*od$').hasMatch(lowerWord) && lowerWord.length <= 5;
      case 'ud':
        // /ʌd/ sound: mud, bud, cud
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[u][bcdfghjklmnpqrstvwxyz]*ud$').hasMatch(lowerWord) && lowerWord.length <= 5;
      case 'ed':
        // /ɛd/ sound: bed, red, led (NOT "used", "moved" which have /d/ sound)
        if (lowerWord.endsWith('eed') || // need, feed (/id/)
            lowerWord.endsWith('ood') || // good, food (/ud/)
            lowerWord.endsWith('ised') || lowerWord.endsWith('used') || // past tense /d/
            lowerWord.length > 5) {
          return false;
        }
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[e][bcdfghjklmnpqrstvwxyz]*ed$').hasMatch(lowerWord);
        
      // VOWEL + B endings
      case 'ab':
        // /æb/ sound: cab, tab, lab
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[a][bcdfghjklmnpqrstvwxyz]*ab$').hasMatch(lowerWord) && lowerWord.length <= 5;
      case 'ib':
        // /ɪb/ sound: rib, bib
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[i][bcdfghjklmnpqrstvwxyz]*ib$').hasMatch(lowerWord) && lowerWord.length <= 5;
      case 'ob':
        // /ɑb/ sound: job, rob, mob
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[o][bcdfghjklmnpqrstvwxyz]*ob$').hasMatch(lowerWord) && lowerWord.length <= 5;
      case 'ub':
        // /ʌb/ sound: tub, rub, hub
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[u][bcdfghjklmnpqrstvwxyz]*ub$').hasMatch(lowerWord) && lowerWord.length <= 5;
      case 'eb':
        // /ɛb/ sound: web, deb
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[e][bcdfghjklmnpqrstvwxyz]*eb$').hasMatch(lowerWord) && lowerWord.length <= 5;
        
      // VOWEL + M endings
      case 'am':
        // /æm/ sound: ham, jam, ram
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[a][bcdfghjklmnpqrstvwxyz]*am$').hasMatch(lowerWord) && lowerWord.length <= 5;
      case 'im':
        // /ɪm/ sound: rim, dim, him
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[i][bcdfghjklmnpqrstvwxyz]*im$').hasMatch(lowerWord) && lowerWord.length <= 5;
      case 'om':
        // /ɑm/ sound: mom, tom, bomb
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[o][bcdfghjklmnpqrstvwxyz]*om$').hasMatch(lowerWord) && lowerWord.length <= 5;
      case 'um':
        // /ʌm/ sound: gum, hum, sum
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[u][bcdfghjklmnpqrstvwxyz]*um$').hasMatch(lowerWord) && lowerWord.length <= 5;
      case 'em':
        // /ɛm/ sound: gem, hem, stem
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*[e][bcdfghjklmnpqrstvwxyz]*em$').hasMatch(lowerWord) && lowerWord.length <= 5;
        
      // Long vowel patterns
      case 'ay':
        // /eɪ/ sound: day, way, say (NOT "buy" which is /aɪ/)
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*ay$').hasMatch(lowerWord) && lowerWord.length <= 6;
      case 'ee':
        // /i/ sound: see, bee, tree
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*ee$').hasMatch(lowerWord) && lowerWord.length <= 6;
      case 'ie':
        // /i/ sound: tie, pie, lie (but many -ie words have /aɪ/ like "fly")
        if (lowerWord.endsWith('y')) return true; // fly, try, cry have /aɪ/
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*ie$').hasMatch(lowerWord) && lowerWord.length <= 5;
      case 'oa':
        // /oʊ/ sound: boat, coat, goat
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*oa[bcdfghjklmnpqrstvwxyz]*$').hasMatch(lowerWord) && lowerWord.length <= 6;
      case 'ow':
        // /oʊ/ sound: show, snow, grow (NOT "cow", "how" which are /aʊ/)
        if (lowerWord.endsWith('ow') && (lowerWord.startsWith('c') || lowerWord.startsWith('h') || lowerWord.startsWith('n'))) {
          // cow, how, now have /aʊ/ sound
          return false;
        }
        return RegExp(r'^[bcdfghjklmnpqrstvwxyz]*ow$').hasMatch(lowerWord) && lowerWord.length <= 6;
        
      default:
        // Basic length filter for unspecified patterns
        return lowerWord.length <= 5;
    }
  }

  /// Get curated child-appropriate words for specific phonetic endings
  /// CRITICAL: This returns words that SOUND like the ending, not just spell like it
  static List<String> _getCuratedWordsForEnding(String ending) {
    final lowerEnding = ending.toLowerCase();
    
    // COMPLETE PHONETIC MAPPING: Words that actually have these sound endings
    switch (lowerEnding) {
      // VOWEL + T endings
      case 'at':
        // /æt/ sound: cat, bat, hat (NOT "treat", "neat", "float")
        return ['cat', 'bat', 'hat', 'mat', 'rat', 'sat', 'pat', 'fat', 'vat', 'chat', 'flat', 'that'];
      case 'it':
        // /ɪt/ sound: sit, bit, hit (NOT "wait", "fruit", "fight")
        return ['sit', 'hit', 'bit', 'fit', 'kit', 'lit', 'pit', 'wit', 'quit', 'spit', 'knit', 'grit'];
      case 'ot':
        // /ɑt/ sound: hot, pot, dot (NOT "caught", "bought", "taught")
        return ['hot', 'pot', 'dot', 'lot', 'not', 'cot', 'jot', 'rot', 'tot'];
      case 'ut':
        // /ʌt/ sound: cut, but, hut (NOT "shoot", "about")
        return ['cut', 'but', 'hut', 'nut', 'shut', 'gut', 'jut', 'rut'];
      case 'et':
        // /ɛt/ sound: bet, get, let (NOT "meet", "beat")
        return ['pet', 'get', 'let', 'met', 'net', 'set', 'bet', 'jet', 'wet', 'yet', 'vet'];
        
      // VOWEL + N endings
      case 'an':
        // /æn/ sound: can, man, ran (NOT "bean", "loan")
        return ['can', 'man', 'ran', 'pan', 'fan', 'tan', 'ban', 'van', 'plan', 'than', 'scan', 'span'];
      case 'in':
        // /ɪn/ sound: pin, win, tin (NOT "rain", "coin", "sign")
        return ['pin', 'win', 'tin', 'bin', 'fin', 'chin', 'thin', 'skin', 'spin', 'grin', 'twin', 'shin'];
      case 'on':
        // /ɑn/ sound: con (RARE - most -on words are /ʌn/)
        return ['con'];
      case 'un':
        // /ʌn/ sound: fun, run, sun (NOT "noun", "moon")
        return ['run', 'sun', 'fun', 'bun', 'gun', 'nun', 'pun', 'spun', 'stun'];
      case 'en':
        // /ɛn/ sound: pen, ten, men (NOT "seen", "bean")
        return ['pen', 'ten', 'men', 'hen', 'den', 'when', 'then'];
        
      // VOWEL + P endings
      case 'ap':
        // /æp/ sound: cap, map, tap (NOT "heap", "loop")
        return ['cap', 'map', 'tap', 'lap', 'gap', 'nap', 'sap', 'clap', 'snap', 'trap'];
      case 'ip':
        // /ɪp/ sound: tip, zip, rip (NOT "deep", "loop")
        return ['tip', 'zip', 'rip', 'hip', 'lip', 'dip', 'ship', 'chip', 'skip', 'trip'];
      case 'op':
        // /ɑp/ sound: top, hop, pop (NOT "loop", "deep")
        return ['top', 'hop', 'pop', 'cop', 'mop', 'shop', 'stop', 'drop', 'chop'];
      case 'up':
        // /ʌp/ sound: cup, pup, up (NOT "soup", "deep")
        return ['cup', 'pup', 'up', 'sup'];
      case 'ep':
        // /ɛp/ sound: step (RARE - NOT "deep", "keep")
        return ['step', 'prep'];
        
      // VOWEL + G endings
      case 'ag':
        // /æg/ sound: bag, tag, rag
        return ['bag', 'tag', 'rag', 'lag', 'sag', 'wag', 'flag', 'drag'];
      case 'ig':
        // /ɪg/ sound: big, dig, fig
        return ['big', 'dig', 'fig', 'pig', 'wig', 'jig', 'rig'];
      case 'og':
        // /ɑg/ sound: dog, log, fog
        return ['dog', 'log', 'hog', 'jog', 'fog', 'bog', 'cog', 'frog'];
      case 'ug':
        // /ʌg/ sound: bug, hug, jug
        return ['bug', 'hug', 'jug', 'mug', 'rug', 'tug', 'dug', 'pug'];
      case 'eg':
        // /ɛg/ sound: leg, beg, peg
        return ['leg', 'beg', 'peg', 'keg', 'egg'];
        
      // VOWEL + D endings
      case 'ad':
        // /æd/ sound: bad, dad, had
        return ['bad', 'dad', 'had', 'mad', 'sad', 'pad', 'lad', 'glad'];
      case 'id':
        // /ɪd/ sound: kid, lid, bid
        return ['kid', 'lid', 'bid', 'did', 'hid', 'rid', 'skid'];
      case 'od':
        // /ɑd/ sound: nod, rod, cod
        return ['nod', 'rod', 'cod', 'sod', 'pod'];
      case 'ud':
        // /ʌd/ sound: mud, bud, cud
        return ['mud', 'bud', 'cud', 'dud', 'thud', 'stud'];
      case 'ed':
        // /ɛd/ sound: bed, red, led (same as 'et' but different spelling)
        return ['red', 'bed', 'fed', 'wed', 'led', 'shed', 'sled'];
        
      // VOWEL + B endings
      case 'ab':
        // /æb/ sound: cab, tab, lab
        return ['cab', 'tab', 'lab', 'nab', 'jab', 'crab', 'grab'];
      case 'ib':
        // /ɪb/ sound: rib, bib
        return ['rib', 'bib'];
      case 'ob':
        // /ɑb/ sound: job, rob, mob
        return ['job', 'rob', 'mob', 'sob', 'bob', 'glob'];
      case 'ub':
        // /ʌb/ sound: tub, rub, hub
        return ['tub', 'rub', 'hub', 'sub', 'club', 'grub'];
      case 'eb':
        // /ɛb/ sound: web, deb
        return ['web', 'deb'];
        
      // VOWEL + M endings
      case 'am':
        // /æm/ sound: ham, jam, ram
        return ['ham', 'jam', 'ram', 'dam', 'yam', 'clam', 'gram'];
      case 'im':
        // /ɪm/ sound: rim, dim, him
        return ['rim', 'dim', 'him', 'tim', 'swim', 'slim', 'trim'];
      case 'om':
        // /ɑm/ sound: mom, tom, bomb
        return ['mom', 'tom', 'bomb', 'from'];
      case 'um':
        // /ʌm/ sound: gum, hum, sum
        return ['gum', 'hum', 'sum', 'rum', 'drum', 'plum', 'chum'];
      case 'em':
        // /ɛm/ sound: gem, hem, stem
        return ['gem', 'hem', 'stem', 'them'];
        
      // Long vowel patterns (common in phonics)
      case 'ay':
        // /eɪ/ sound: day, way, say
        return ['day', 'way', 'say', 'may', 'bay', 'hay', 'lay', 'pay', 'play', 'stay', 'pray', 'gray'];
      case 'ee':
        // /i/ sound: see, bee, tree
        return ['see', 'bee', 'tree', 'free', 'three', 'knee', 'flee', 'agree'];
      case 'ie':
        // /i/ sound: tie, pie, lie
        return ['tie', 'pie', 'lie', 'die', 'fly', 'try', 'cry', 'dry'];
      case 'oa':
        // /oʊ/ sound: boat, coat, goat
        return ['boat', 'coat', 'goat', 'road', 'toad', 'soap', 'loaf'];
      case 'ow':
        // /oʊ/ sound: show, snow, grow
        return ['show', 'snow', 'grow', 'blow', 'flow', 'glow', 'slow'];
        
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
        // /ɑt/ sound ONLY - excluding any that might rhyme with 'aught' patterns  
        return ['hot', 'pot', 'dot', 'lot', 'not', 'cot', 'jot', 'rot', 'tot'];
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