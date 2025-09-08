// Demo AI service for testing without API keys
// In production, replace this with AIWordService using real AI APIs

import 'content_filter_service.dart';

class DemoAIService {
  static Map<String, List<List<String>>> _demoResponses = {
    'cvc_at': [
      ['cat', 'bat', 'rat', 'mat', 'sat', 'hat'],
      ['fat', 'pat', 'vat', 'tat', 'flat', 'chat'],
      ['cat', 'bat', 'rat', 'mat', 'sat', 'hat'],
      ['fat', 'pat', 'vat', 'tat', 'flat', 'chat'],
      ['cat', 'bat', 'rat', 'mat', 'sat', 'hat'],
      ['fat', 'pat', 'vat', 'tat', 'flat', 'chat'],
    ],
    'cvc_it': [
      ['sit', 'hit', 'bit', 'fit', 'kit', 'lit'],
      ['pit', 'wit', 'spit', 'quit', 'knit', 'grit'],
      ['sit', 'hit', 'bit', 'fit', 'kit', 'lit'],
      ['pit', 'wit', 'spit', 'quit', 'knit', 'grit'],
      ['sit', 'hit', 'bit', 'fit', 'kit', 'lit'],
      ['pit', 'wit', 'spit', 'quit', 'knit', 'grit'],
    ],
    'cvc_et': [
      ['pet', 'get', 'let', 'met', 'net', 'set'],
      ['bet', 'jet', 'wet', 'yet', 'vet', 'fret'],
      ['pet', 'get', 'let', 'met', 'net', 'set'],
      ['bet', 'jet', 'wet', 'yet', 'vet', 'fret'],
      ['pet', 'get', 'let', 'met', 'net', 'set'],
      ['bet', 'jet', 'wet', 'yet', 'vet', 'fret'],
    ],
    'cvc_ot': [
      ['hot', 'pot', 'dot', 'got', 'lot', 'not'],
      ['cot', 'jot', 'rot', 'tot', 'shot', 'spot'],
      ['hot', 'pot', 'dot', 'got', 'lot', 'not'],
      ['cot', 'jot', 'rot', 'tot', 'shot', 'spot'],
      ['hot', 'pot', 'dot', 'got', 'lot', 'not'],
      ['cot', 'jot', 'rot', 'tot', 'shot', 'spot'],
    ],
    'cvc_ut': [
      ['cut', 'but', 'hut', 'nut', 'put', 'gut'],
      ['jut', 'rut', 'shut', 'strut', 'mutt', 'tut'],
      ['cut', 'but', 'hut', 'nut', 'put', 'gut'],
      ['jut', 'rut', 'shut', 'strut', 'mutt', 'tut'],
      ['cut', 'but', 'hut', 'nut', 'put', 'gut'],
      ['jut', 'rut', 'shut', 'strut', 'mutt', 'tut'],
    ],
    'animals': [
      ['cat', 'dog', 'fish', 'bird', 'frog', 'bear'],
      ['lion', 'tiger', 'wolf', 'fox', 'deer', 'owl'],
      ['cow', 'pig', 'goat', 'duck', 'hen', 'sheep'],
      ['mouse', 'rat', 'bat', 'ant', 'bee', 'fly'],
      ['snake', 'turtle', 'crab', 'whale', 'shark', 'seal'],
      ['horse', 'zebra', 'rabbit', 'squirrel', 'skunk', 'otter'],
    ],
    'colors': [
      ['red', 'blue', 'green', 'yellow', 'white', 'purple'],
      ['pink', 'brown', 'black', 'white', 'gray', 'gold'],
      ['silver', 'coral', 'teal', 'lime', 'navy', 'maroon'],
      ['tan', 'beige', 'ivory', 'peach', 'mint', 'rose'],
      ['crimson', 'azure', 'jade', 'amber', 'bronze', 'ruby'],
      ['indigo', 'violet', 'scarlet', 'emerald', 'pearl', 'copper'],
    ],
    'food': [
      ['apple', 'banana', 'mango', 'grape', 'berry', 'peach'],
      ['bread', 'milk', 'cheese', 'butter', 'egg', 'meat'],
      ['rice', 'pasta', 'pizza', 'soup', 'salad', 'cake'],
      ['cookie', 'candy', 'ice cream', 'juice', 'water', 'tea'],
      ['carrot', 'potato', 'tomato', 'onion', 'pepper', 'corn'],
      ['fish', 'chicken', 'beef', 'pork', 'beans', 'nuts'],
    ],
    'ocean': [
      ['whale', 'dolphin', 'shark', 'octopus', 'squid', 'jellyfish'],
      ['crab', 'lobster', 'shrimp', 'clam', 'oyster', 'mussel'],
      ['starfish', 'seahorse', 'eel', 'ray', 'turtle', 'seal'],
      ['coral', 'seaweed', 'kelp', 'plankton', 'algae', 'sponge'],
      ['wave', 'tide', 'current', 'deep', 'blue', 'salty'],
      ['beach', 'shore', 'sand', 'shell', 'pearl', 'treasure'],
    ],
    'space': [
      ['sun', 'moon', 'star', 'planet', 'earth', 'mars'],
      ['rocket', 'shuttle', 'satellite', 'comet', 'meteor', 'galaxy'],
      ['astronaut', 'alien', 'orbit', 'crater', 'space', 'void'],
      ['bright', 'dark', 'cold', 'hot', 'far', 'near'],
      ['telescope', 'mission', 'launch', 'landing', 'explore', 'discover'],
      ['jupiter', 'saturn', 'uranus', 'neptune', 'venus', 'mercury'],
    ],
    'long vowel': [
      ['cake', 'make', 'take', 'bake', 'wake', 'lake'],
      ['bee', 'see', 'tree', 'free', 'knee', 'three'],
      ['bike', 'like', 'time', 'nine', 'five', 'kite'],
      ['bone', 'cone', 'tone', 'home', 'rope', 'hope'],
      ['cute', 'tube', 'cube', 'huge', 'tune', 'blue'],
      ['pie', 'tie', 'lie', 'die', 'cry', 'my'],
    ],
    'family': [
      ['mom', 'dad', 'sister', 'brother', 'baby', 'grandma'],
      ['grandpa', 'aunt', 'uncle', 'cousin', 'nephew', 'niece'],
      ['mother', 'father', 'parent', 'child', 'son', 'daughter'],
      ['family', 'home', 'love', 'care', 'hug', 'kiss'],
      ['together', 'happy', 'fun', 'play', 'laugh', 'smile'],
      ['birthday', 'holiday', 'dinner', 'story', 'bedtime', 'dream'],
    ],
  };

  /// Generate words based on the prompt
  static Future<List<List<String>>> generateWordGrid({
    required String prompt,
    String difficulty = 'elementary',
  }) async {
    // Simulate AI processing delay
    await Future.delayed(const Duration(seconds: 1));

    final lowerPrompt = prompt.toLowerCase();
    
    // Check for CVC ending patterns first
    if (lowerPrompt.contains('cvc') || lowerPrompt.contains('ending')) {
      // Check for specific endings
      if (lowerPrompt.contains('at')) {
        return _filterWordGrid(_demoResponses['cvc_at']!);
      } else if (lowerPrompt.contains('it')) {
        return _filterWordGrid(_demoResponses['cvc_it']!);
      } else if (lowerPrompt.contains('et')) {
        return _filterWordGrid(_demoResponses['cvc_et']!);
      } else if (lowerPrompt.contains('ot')) {
        return _filterWordGrid(_demoResponses['cvc_ot']!);
      } else if (lowerPrompt.contains('ut')) {
        return _filterWordGrid(_demoResponses['cvc_ut']!);
      }
    }

    // Find the best match for the prompt
    String bestMatch = 'animals'; // default
    double bestScore = 0.0;

    for (String key in _demoResponses.keys) {
      // Skip CVC patterns in general matching
      if (key.startsWith('cvc_')) continue;
      
      double score = _calculateSimilarity(lowerPrompt, key);
      if (score > bestScore) {
        bestScore = score;
        bestMatch = key;
      }
    }

    // Get the matched word grid and apply content filtering
    final rawGrid = _demoResponses[bestMatch] ?? _demoResponses['animals']!;
    return _filterWordGrid(rawGrid);
  }

  /// Simple similarity calculation based on keyword matching
  static double _calculateSimilarity(String prompt, String category) {
    double score = 0.0;

    switch (category) {
      case 'animals':
        if (prompt.contains('animal') || prompt.contains('pet') || 
            prompt.contains('zoo') || prompt.contains('wild')) {
          score += 1.0;
        }
        break;
      case 'colors':
        if (prompt.contains('color') || prompt.contains('paint') ||
            prompt.contains('rainbow') || prompt.contains('bright')) {
          score += 1.0;
        }
        break;
      case 'food':
        if (prompt.contains('food') || prompt.contains('eat') ||
            prompt.contains('kitchen') || prompt.contains('meal') ||
            prompt.contains('hungry') || prompt.contains('cook')) {
          score += 1.0;
        }
        break;
      case 'ocean':
        if (prompt.contains('ocean') || prompt.contains('sea') ||
            prompt.contains('water') || prompt.contains('beach') ||
            prompt.contains('marine') || prompt.contains('underwater')) {
          score += 1.0;
        }
        break;
      case 'space':
        if (prompt.contains('space') || prompt.contains('star') ||
            prompt.contains('planet') || prompt.contains('astronaut') ||
            prompt.contains('galaxy') || prompt.contains('universe')) {
          score += 1.0;
        }
        break;
      case 'long vowel':
        if (prompt.contains('vowel') || prompt.contains('long') ||
            prompt.contains('sound') || prompt.contains('phonics')) {
          score += 1.0;
        }
        break;
      case 'family':
        if (prompt.contains('family') || prompt.contains('parent') ||
            prompt.contains('home') || prompt.contains('relative')) {
          score += 1.0;
        }
        break;
    }

    // Add partial matches for common words
    List<String> promptWords = prompt.split(' ');
    for (String word in promptWords) {
      if (category.contains(word) || word.contains(category)) {
        score += 0.5;
      }
    }

    return score;
  }

  /// Get available demo topics
  static List<String> getDemoTopics() {
    return _demoResponses.keys.toList();
  }

  /// Generate column words (for specific dice roll)
  static Future<List<String>> generateColumnWords({
    required String prompt,
    required int column,
    String difficulty = 'elementary',
  }) async {
    final grid = await generateWordGrid(prompt: prompt, difficulty: difficulty);
    return grid.map((row) => row[column - 1]).toList();
  }

  /// Filter word grid for child safety
  static List<List<String>> _filterWordGrid(List<List<String>> rawGrid) {
    final filteredGrid = <List<String>>[];
    
    for (final row in rawGrid) {
      // Filter each row for inappropriate content
      final safeWords = ContentFilterService.filterWords(row);
      
      // Ensure we have exactly 6 words per row
      final paddedRow = <String>[];
      paddedRow.addAll(safeWords.take(6));
      
      // If we don't have enough safe words, pad with safe replacements
      if (paddedRow.length < 6) {
        final replacements = ContentFilterService.getSafeReplacements(6 - paddedRow.length);
        paddedRow.addAll(replacements);
      }
      
      filteredGrid.add(paddedRow.take(6).toList());
    }
    
    // Ensure we have exactly 6 rows
    while (filteredGrid.length < 6) {
      final safeRow = ContentFilterService.getSafeReplacements(6);
      filteredGrid.add(safeRow);
    }
    
    return filteredGrid.take(6).toList();
  }
}