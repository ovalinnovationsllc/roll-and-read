/// Content filtering service for child safety in educational apps
/// Filters inappropriate content from prompts and AI responses
class ContentFilterService {
  // Comprehensive inappropriate words list for child safety
  static final Set<String> _inappropriateWords = {
    // Common profanity (4-letter and longer)
    'damn', 'hell', 'crap', 'shit', 'fuck', 'bitch', 'bastard', 'asshole',
    'dickhead', 'bullshit', 'motherfucker', 'goddamn',
    
    // Violence/weapons
    'kill', 'murder', 'death', 'die', 'dead', 'blood', 'gun', 'guns', 'knife', 'weapon', 
    'bomb', 'explode', 'suicide', 'stab', 'shoot', 'violence', 'violent', 'fight',
    'punch', 'kick', 'hurt', 'pain', 'war', 'attack', 'destroy', 'sword', 'rifle',
    'pistol', 'bullet', 'shooting', 'killing', 'beaten', 'slap', 'smash', 'crush',
    
    // Substances
    'drug', 'drugs', 'alcohol', 'beer', 'wine', 'drunk', 'smoke', 'cigarette',
    'tobacco', 'vape', 'weed', 'marijuana', 'cocaine', 'heroin',
    
    // Body/bathroom inappropriate for kids
    'poop', 'pee', 'fart', 'butt', 'ass', 'penis', 'vagina', 'breast', 'boob',
    'naked', 'nude', 'underwear', 'toilet', 'potty', 'bathroom', 'cock', 'dick',
    'balls', 'nuts', 'tit', 'tits', 'boobs', 'bra', 'panties', 'boxers',
    
    // Insults/mean words
    'stupid', 'dumb', 'idiot', 'moron', 'retard', 'loser', 'ugly', 'fat', 'hate',
    'sucks', 'shut up', 'freak', 'weird', 'creep',
    
    // Adult themes
    'sex', 'sexy', 'kiss', 'dating', 'boyfriend', 'girlfriend', 'love', 'marry',
    'pregnant', 'baby', 'adult', 'mature', 'gay', 'lesbian', 'homo', 'queer',
    
    // Too advanced/confusing words for children with reading difficulties
    'avid', 'puff', 'soma', 'pule', 'sway', 'aura', 'slew', 'snap',
    // Complex Long A words that are too advanced
    'apprehensive', 'articulate', 'austere', 'abrasive', 'acquiesce', 'amenable', 
    'aggregate', 'ambivalence', 'accentuate', 'affable', 'aureate', 'accede', 
    'alcove', 'avarice', 'astute', 'ample', 'anserine', 'advance', 'alleviate', 
    'amicable', 'asinine', 'acute', 'abide', 'accolade', 'adequate', 'ameliorate', 
    'aggrandize', 'anodyne', 'acquiescence', 'allure', 'ambiance', 'azure', 
    'affectionate', 'aptitude',
    
    // Scary/inappropriate themes for children
    'ghost', 'zombie', 'monster', 'demon', 'devil', 'satan', 'evil', 'scary',
    'nightmare', 'horror', 'witch', 'magic', 'spell',
    
    // Religious/political (to avoid controversy in educational settings)
    'god', 'jesus', 'christ', 'bible', 'church', 'religion', 'pray', 'prayer',
    'politics', 'election', 'vote', 'government',
    
    // Other inappropriate
    'money', 'rich', 'poor', 'expensive', 'cheap',
    
    // Slang/inappropriate slang
    'pimp', 'ho', 'hoe', 'whore', 'slut', 'douche', 'jerk', 'punk',
    'screw', 'suck', 'blow', 'lick', 'strip', 'bang', 'hump', 'spank',
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
    
    // Check if word contains inappropriate content (only for longer words to avoid false positives)
    for (final badWord in _inappropriateWords) {
      if (badWord.length >= 4 && cleanWord.contains(badWord)) {
        return false;
      }
    }
    
    // Additional safety checks for very short words
    if (cleanWord.length <= 3) {
      // Allow common educational words including sight words
      final allowedShort = {
        // Basic sight words (essential for reading education)
        'a', 'i', 'in', 'is', 'it', 'to', 'me', 'my', 'am', 'on', 'we', 'go', 'up', 'at',
        'be', 'do', 'he', 'or', 'no', 'so', 'of', 'as', 'by',
        // Common educational words
        'cat', 'dog', 'run', 'sun', 'fun', 'red', 'bed', 'car', 'big', 'boy', 'girl',
        'the', 'and', 'for', 'are', 'but', 'not', 'you', 'all', 'can', 'her', 'was',
        'one', 'our', 'out', 'day', 'get', 'has', 'him', 'his', 'how', 'man', 'new',
        'now', 'old', 'see', 'two', 'who', 'boy', 'did', 'its', 'let', 'put', 'say',
        'she', 'too', 'use', 'bat', 'hat', 'mat', 'pat', 'rat', 'sat', 'fat', 'lot',
        'hot', 'pot', 'got', 'not', 'top', 'hop', 'pop', 'mom', 'dad', 'yes', 'win',
        'sky', 'sun', 'moon', 'star', 'blue', 'bird', 'duck', 'frog', 'play', 'jump',
        'tall', 'fast', 'slow', 'pink', 'five', 'four', 'six', 'walk', 'skip', 'good',
        'tree', 'fish', 'cloud', 'rain', 'green', 'orange', 'small', 'short', 'hop',
        // Common 3-letter words safe for children
        'job', 'box', 'fox', 'bus', 'cup', 'pen', 'bag', 'egg', 'leg', 'arm', 'ear',
        'eye', 'toy', 'key', 'ice', 'age', 'art', 'oil', 'air', 'sea', 'tie', 'pie',
        'cow', 'pig', 'bee', 'ant', 'bug', 'web', 'net', 'jet', 'van', 'map', 'cap',
        // Additional animals that are safe 3-letter words
        'owl', 'hen', 'ram', 'yak', 'emu', 'ape', 'bat', 'cod', 'eel', 'elk', 'jay',
        'lap', 'tap', 'zip', 'tip', 'lip', 'hip', 'dip', 'rip', 'nip', 'sip', 'row',
        'low', 'bow', 'cow', 'mow', 'sow', 'tow', 'jaw', 'paw', 'raw', 'saw', 'law',
        'bay', 'way', 'may', 'lay', 'hay', 'pay', 'ray', 'day', 'say', 'try',
        'cry', 'dry', 'fly', 'shy', 'sky', 'spy', 'why', 'buy', 'guy', 'joy', 'toy',
        // Additional sight words and common educational words
        'eat', 'ate', 'ran', 'ten', 'own', 'won', 'son', 'mr', 'mrs',
        'who', 'any', 'how', 'house', 'school', 'father', 'thought', 'whose', 'should',
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
      'cat', 'dog', 'sun', 'moon', 'star', 'tree', 'book', 'ball',
      'fish', 'bird', 'car', 'bus', 'red', 'blue', 'green', 'big',
      'small', 'hot', 'cold', 'happy', 'sad', 'run', 'jump', 'walk',
      'play', 'read', 'sing', 'one', 'two', 'three', 'four', 'five', 'six',
      'apple', 'cake', 'milk', 'egg', 'hand', 'foot', 'head', 'eye',
      'home', 'door', 'chair', 'table', 'water', 'rain', 'snow', 'wind',
      'mom', 'dad', 'baby', 'boy', 'girl', 'friend', 'love', 'hug',
      'mouse', 'duck', 'frog', 'bear', 'lion', 'tiger', 'horse', 'sheep',
      'fast', 'slow', 'tall', 'short', 'old', 'new', 'good', 'nice',
    ];
    
    // Shuffle to avoid predictable patterns
    final shuffledWords = List<String>.from(safeWords)..shuffle();
    
    final replacements = <String>[];
    final usedWords = <String>{};
    
    for (int i = 0; i < count; i++) {
      // Try to avoid duplicates
      String word = shuffledWords[i % shuffledWords.length];
      int attempts = 0;
      while (usedWords.contains(word) && attempts < shuffledWords.length) {
        word = shuffledWords[(i + attempts) % shuffledWords.length];
        attempts++;
      }
      replacements.add(word);
      usedWords.add(word);
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