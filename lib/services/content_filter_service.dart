/// Content filtering service for child safety in educational apps
/// Filters inappropriate content from prompts and AI responses
class ContentFilterService {
  // Comprehensive inappropriate words list for child safety
  static final Set<String> _inappropriateWords = {
    // Common profanity (4-letter and longer)
    'damn', 'hell', 'crap', 'shit', 'fuck', 'bitch', 'bastard', 'asshole',
    'dickhead', 'bullshit', 'motherfucker', 'goddamn',
    
    // Violence/weapons
    'kill', 'murder', 'death', 'die', 'dead', 'blood', 'gun', 'knife', 'weapon', 
    'bomb', 'explode', 'suicide', 'stab', 'shoot', 'violence', 'violent', 'fight',
    'punch', 'kick', 'hurt', 'pain', 'war', 'attack', 'destroy',
    
    // Substances
    'drug', 'drugs', 'alcohol', 'beer', 'wine', 'drunk', 'smoke', 'cigarette',
    'tobacco', 'vape', 'weed', 'marijuana', 'cocaine', 'heroin',
    
    // Body/bathroom inappropriate for kids
    'poop', 'pee', 'fart', 'butt', 'ass', 'penis', 'vagina', 'breast', 'boob',
    'naked', 'nude', 'underwear', 'toilet', 'potty', 'bathroom',
    
    // Insults/mean words
    'stupid', 'dumb', 'idiot', 'moron', 'retard', 'loser', 'ugly', 'fat', 'hate',
    'sucks', 'shut up', 'freak', 'weird', 'creep',
    
    // Adult themes
    'sex', 'sexy', 'kiss', 'dating', 'boyfriend', 'girlfriend', 'love', 'marry',
    'pregnant', 'baby', 'adult', 'mature',
    
    // Scary/inappropriate themes for children
    'ghost', 'zombie', 'monster', 'demon', 'devil', 'satan', 'evil', 'scary',
    'nightmare', 'horror', 'witch', 'magic', 'spell',
    
    // Religious/political (to avoid controversy in educational settings)
    'god', 'jesus', 'christ', 'bible', 'church', 'religion', 'pray', 'prayer',
    'politics', 'election', 'vote', 'government',
    
    // Other inappropriate
    'money', 'rich', 'poor', 'buy', 'sell', 'expensive', 'cheap',
    'work', 'job', 'boss', 'fire', 'quit',
  };
  
  // Common profanity variations and leetspeak
  static final Set<String> _profanityVariations = {
    'sh1t', 's**t', 's---', 'f***', 'f**k', 'f---', 'b***h', 'b----',
    'd***', 'h***', 'a**', 'a--', '****', '---',
  };
  
  /// Check if a prompt contains inappropriate content
  static bool hasInappropriateContent(String text) {
    final lowerText = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    final words = lowerText.split(RegExp(r'\s+'));
    
    // Check each word
    for (final word in words) {
      if (word.isEmpty) continue;
      
      // Direct match
      if (_inappropriateWords.contains(word)) {
        return true;
      }
      
      // Check variations
      if (_profanityVariations.contains(word)) {
        return true;
      }
      
      // Check if word contains inappropriate content
      for (final badWord in _inappropriateWords) {
        if (word.contains(badWord)) {
          return true;
        }
      }
    }
    
    return false;
  }
  
  /// Filter inappropriate words from a list
  static List<String> filterWords(List<String> words) {
    final safeWords = <String>[];
    
    for (final word in words) {
      if (isWordSafe(word)) {
        safeWords.add(word);
      }
    }
    
    return safeWords;
  }
  
  /// Check if a single word is safe
  static bool isWordSafe(String word) {
    final cleanWord = word.toLowerCase().trim().replaceAll(RegExp(r'[^a-z]'), '');
    
    if (cleanWord.isEmpty) return false;
    
    // Check against inappropriate words
    if (_inappropriateWords.contains(cleanWord)) {
      return false;
    }
    
    // Check variations
    if (_profanityVariations.contains(cleanWord)) {
      return false;
    }
    
    // Check if word contains inappropriate content
    for (final badWord in _inappropriateWords) {
      if (cleanWord.contains(badWord)) {
        return false;
      }
    }
    
    // Additional safety checks for very short words
    if (cleanWord.length <= 3) {
      // Allow common educational words
      final allowedShort = {
        'cat', 'dog', 'run', 'sun', 'fun', 'red', 'bed', 'car', 'big', 'boy', 'girl',
        'the', 'and', 'for', 'are', 'but', 'not', 'you', 'all', 'can', 'her', 'was',
        'one', 'our', 'out', 'day', 'get', 'has', 'him', 'his', 'how', 'man', 'new',
        'now', 'old', 'see', 'two', 'who', 'boy', 'did', 'its', 'let', 'put', 'say',
        'she', 'too', 'use', 'bat', 'hat', 'mat', 'pat', 'rat', 'sat', 'fat', 'lot',
        'hot', 'pot', 'got', 'not', 'top', 'hop', 'pop', 'mom', 'dad', 'yes', 'win',
        'sky', 'sun', 'moon', 'star', 'blue', 'bird', 'duck', 'frog', 'play', 'jump',
        'tall', 'fast', 'slow', 'pink', 'five', 'four', 'six', 'walk', 'skip', 'good',
        'tree', 'fish', 'cloud', 'rain', 'green', 'orange', 'small', 'short', 'hop',
      };
      
      if (!allowedShort.contains(cleanWord)) {
        return false; // Be conservative with short words
      }
    }
    
    return true;
  }
  
  /// Get safe replacement words when filtering
  static List<String> getSafeReplacements(int count) {
    final safeWords = [
      'book', 'tree', 'ball', 'desk', 'chair', 'door', 'window', 'table',
      'apple', 'orange', 'grape', 'banana', 'flower', 'garden', 'house', 'school',
      'happy', 'smile', 'laugh', 'play', 'learn', 'read', 'write', 'draw',
      'bird', 'fish', 'bunny', 'puppy', 'kitten', 'duck', 'frog', 'bear',
    ];
    
    final replacements = <String>[];
    for (int i = 0; i < count; i++) {
      replacements.add(safeWords[i % safeWords.length]);
    }
    return replacements;
  }
  
  /// Generate a safe educational word grid for fallback
  static List<List<String>> getSafeWordGrid() {
    return [
      ['cat', 'dog', 'bird', 'fish', 'frog', 'duck'],
      ['sun', 'moon', 'star', 'sky', 'cloud', 'rain'],
      ['red', 'blue', 'green', 'yellow', 'pink', 'orange'],
      ['one', 'two', 'three', 'four', 'five', 'six'],
      ['run', 'jump', 'skip', 'hop', 'walk', 'play'],
      ['big', 'small', 'tall', 'short', 'fast', 'slow']
    ];
  }
}