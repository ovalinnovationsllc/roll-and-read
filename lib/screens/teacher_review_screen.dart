import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/user_model.dart';
import '../models/game_session_model.dart';
import '../services/ai_word_service.dart';
import '../services/game_session_service.dart';
import '../services/game_state_service.dart';

class TeacherReviewScreen extends StatefulWidget {
  final GameSessionModel gameSession;
  final UserModel adminUser;

  const TeacherReviewScreen({
    super.key,
    required this.gameSession,
    required this.adminUser,
  });

  @override
  State<TeacherReviewScreen> createState() => _TeacherReviewScreenState();
}

class _TeacherReviewScreenState extends State<TeacherReviewScreen> {
  // Track selected words for regeneration
  final Set<String> _selectedWords = {};
  bool _isRegenerating = false;
  late List<List<String>> _currentWordGrid;
  
  // Track all words that have been replaced throughout all regenerations
  final Set<String> _allReplacedWords = {};

  @override
  void initState() {
    super.initState();
    // Create a copy of the word grid that we can modify
    _currentWordGrid = widget.gameSession.wordGrid?.map((row) => List<String>.from(row)).toList() ?? [];
    
    // If no word grid, create default
    if (_currentWordGrid.isEmpty) {
      _currentWordGrid = [
        ['cat', 'dog', 'pig', 'cow', 'hen', 'fox'],
        ['run', 'hop', 'sit', 'jump', 'walk', 'skip'],
        ['red', 'blue', 'green', 'pink', 'yellow', 'white'],
        ['mom', 'dad', 'sister', 'brother', 'baby', 'family'],
        ['one', 'two', 'three', 'four', 'five', 'six'],
        ['sun', 'moon', 'star', 'cloud', 'rain', 'snow'],
      ];
    }
  }

  void _toggleWordSelection(int row, int col) {
    final wordKey = '$row-$col';
    setState(() {
      if (_selectedWords.contains(wordKey)) {
        _selectedWords.remove(wordKey);
      } else {
        _selectedWords.add(wordKey);
      }
    });
  }

  Future<void> _regenerateSelectedWords() async {
    if (_selectedWords.isEmpty || _isRegenerating) return;

    setState(() {
      _isRegenerating = true;
    });

    try {
      // Generate new words using the same prompt and settings
      final prompt = widget.gameSession.aiPrompt ?? 'Educational words for students';
      final difficulty = widget.gameSession.difficulty ?? 'elementary';
      
      print('🔄 Regenerating ${_selectedWords.length} selected words');
      print('📝 Using prompt: "$prompt"');
      
      // Get all current words (including ones we're keeping)
      final currentWords = _currentWordGrid.expand((row) => row).toSet();
      
      // Get the specific words we're replacing
      final wordsBeingReplaced = <String>{};
      for (String wordKey in _selectedWords) {
        final parts = wordKey.split('-');
        final row = int.parse(parts[0]);
        final col = int.parse(parts[1]);
        final wordBeingReplaced = _currentWordGrid[row][col];
        wordsBeingReplaced.add(wordBeingReplaced);
        // Add to persistent tracking
        _allReplacedWords.add(wordBeingReplaced);
      }
      
      // Create comprehensive avoid list including all previously replaced words
      final wordsToAvoid = currentWords.union(wordsBeingReplaced).union(_allReplacedWords);
      print('🚫 Words to avoid (including all previously replaced): ${wordsToAvoid.join(", ")}');
      
      // Generate multiple grids to get more word options
      List<String> candidateWords = [];
      int attempts = 0;
      const maxAttempts = 3;
      
      while (candidateWords.length < _selectedWords.length * 2 && attempts < maxAttempts) {
        attempts++;
        print('🎲 Generation attempt $attempts');
        
        final newGrid = await AIWordService.generateWordGrid(
          prompt: prompt,
          difficulty: difficulty,
          gameId: widget.gameSession.gameId,
          gameName: widget.gameSession.gameName,
        );
        
        // Extract new words and filter out duplicates/existing words
        final newWords = newGrid.expand((row) => row).toList();
        for (String word in newWords) {
          if (!wordsToAvoid.contains(word) && 
              !candidateWords.contains(word)) {
            candidateWords.add(word);
          }
        }
        
        print('🎯 Found ${candidateWords.length} unique candidate words so far');
      }
      
      // If we still don't have enough unique words, generate pattern-specific fallback words
      if (candidateWords.length < _selectedWords.length) {
        print('⚠️ Need ${_selectedWords.length - candidateWords.length} more words, trying pattern-specific fallbacks');
        print('🔍 Prompt for pattern detection: "$prompt"');
        
        // Detect the pattern from the original prompt
        final patternFallbackWords = _getPatternSpecificFallbacks(prompt, wordsToAvoid.union(candidateWords.toSet()));
        print('🎯 Pattern fallback words found: $patternFallbackWords');
        
        for (String word in patternFallbackWords) {
          if (!wordsToAvoid.contains(word) && 
              !candidateWords.contains(word) &&
              candidateWords.length < _selectedWords.length) {
            candidateWords.add(word);
            print('🔄 Added pattern-specific fallback: "$word"');
          } else {
            print('🚫 Skipped "$word" - already exists in current words, previously replaced, or being replaced');
          }
        }
        
        // Only use generic fallbacks if pattern-specific ones aren't enough
        if (candidateWords.length < _selectedWords.length) {
          print('⚠️ Pattern fallbacks insufficient, using generic fallbacks');
          final genericFallbacks = [
            'book', 'read', 'learn', 'study', 'write', 'draw', 'play', 'sing',
            'dance', 'jump', 'run', 'walk', 'talk', 'think', 'smile', 'laugh',
            'help', 'kind', 'nice', 'good', 'best', 'great', 'super', 'fun',
            'happy', 'joy', 'peace', 'love', 'hope', 'dream', 'wish', 'try'
          ];
          
          for (String word in genericFallbacks) {
            if (!wordsToAvoid.contains(word) && 
                !candidateWords.contains(word) &&
                candidateWords.length < _selectedWords.length) {
              candidateWords.add(word);
              print('🔄 Added generic fallback: "$word"');
            }
          }
        }
      }
      
      // Replace selected words with unique new ones
      int replacementIndex = 0;
      final replacedCount = _selectedWords.length;
      
      for (String wordKey in _selectedWords) {
        final parts = wordKey.split('-');
        final row = int.parse(parts[0]);
        final col = int.parse(parts[1]);
        
        if (replacementIndex < candidateWords.length) {
          final newWord = candidateWords[replacementIndex];
          _currentWordGrid[row][col] = newWord;
          currentWords.add(newWord); // Update our tracking set
          replacementIndex++;
          print('🔄 Replaced "${wordsBeingReplaced.elementAt(replacementIndex - 1)}" with "$newWord"');
        }
      }
      
      // Clear selection
      setState(() {
        _selectedWords.clear();
        _isRegenerating = false;
      });
      
      // Toast removed per user request - regeneration is visually obvious from grid changes
      
    } catch (e) {
      setState(() {
        _isRegenerating = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error regenerating words: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _cancelAndCleanup() async {
    try {
      print('🗑️ TEACHER REVIEW: Canceling and deleting orphaned game session ${widget.gameSession.gameId}');
      
      // Delete the game session since teacher is canceling
      await GameSessionService.deleteGameSession(widget.gameSession.gameId);
      
      print('✅ TEACHER REVIEW: Successfully deleted orphaned game session');
      
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('❌ TEACHER REVIEW: Error deleting game session: $e');
      
      // Still navigate back even if deletion failed
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  /// Get fallback words that match the pattern from the original prompt
  List<String> _getPatternSpecificFallbacks(String prompt, Set<String> existingWords) {
    final lowerPrompt = prompt.toLowerCase();
    print('🔍 Pattern detection for prompt: "$lowerPrompt"');
    
    // Detect ending patterns
    final endingMatch = RegExp(r'(?:ending|end|ends|that end) (?:in|with) ["\x27]?-?(\w+)["\x27]?').firstMatch(lowerPrompt);
    if (endingMatch != null) {
      final ending = endingMatch.group(1);
      print('🎯 Detected ending pattern: "$ending"');
      if (ending != null) {
        final words = _getFallbackWordsForEnding(ending, existingWords);
        print('📝 Available fallback words for ending "$ending": $words');
        return words;
      }
    } else {
      print('❌ No ending pattern detected');
    }
    
    // Detect length patterns
    final lengthMatch = RegExp(r'(\d+)\s*letter').firstMatch(lowerPrompt);
    if (lengthMatch != null) {
      final length = int.parse(lengthMatch.group(1)!);
      print('🎯 Detected length pattern: $length letters');
      final words = _getFallbackWordsForLength(length, existingWords);
      print('📝 Available fallback words for $length letters: $words');
      return words;
    }
    
    // Detect phonics patterns
    if (lowerPrompt.contains('short a')) {
      return _getFallbackWordsForPattern('short_a', existingWords);
    } else if (lowerPrompt.contains('short e')) {
      return _getFallbackWordsForPattern('short_e', existingWords);
    } else if (lowerPrompt.contains('short i')) {
      return _getFallbackWordsForPattern('short_i', existingWords);
    } else if (lowerPrompt.contains('short o')) {
      return _getFallbackWordsForPattern('short_o', existingWords);
    } else if (lowerPrompt.contains('short u')) {
      return _getFallbackWordsForPattern('short_u', existingWords);
    } else if (lowerPrompt.contains('long a')) {
      return _getFallbackWordsForPattern('long_a', existingWords);
    } else if (lowerPrompt.contains('long e')) {
      return _getFallbackWordsForPattern('long_e', existingWords);
    } else if (lowerPrompt.contains('long i')) {
      return _getFallbackWordsForPattern('long_i', existingWords);
    } else if (lowerPrompt.contains('long o')) {
      return _getFallbackWordsForPattern('long_o', existingWords);
    } else if (lowerPrompt.contains('long u')) {
      return _getFallbackWordsForPattern('long_u', existingWords);
    }
    
    // No specific pattern detected
    return [];
  }
  
  /// Get fallback words for a specific ending pattern
  List<String> _getFallbackWordsForEnding(String ending, Set<String> existingWords) {
    Map<String, List<String>> endingWords = {
      'an': ['can', 'man', 'ran', 'pan', 'fan', 'tan', 'ban', 'van', 'plan', 'than', 'scan', 'span', 'clan', 'gran', 'bran', 'flan'],
      'at': ['cat', 'bat', 'hat', 'mat', 'rat', 'sat', 'pat', 'fat', 'vat', 'chat', 'flat', 'that', 'brat', 'scat', 'spat', 'stat'],
      'in': ['pin', 'win', 'tin', 'bin', 'fin', 'chin', 'thin', 'skin', 'spin', 'grin', 'twin', 'shin', 'din', 'kin', 'sin', 'gin'],
      'un': ['run', 'sun', 'fun', 'bun', 'gun', 'nun', 'pun', 'dun', 'spun', 'stun', 'shun', 'hun', 'tun'],
      'it': ['sit', 'hit', 'bit', 'fit', 'kit', 'lit', 'pit', 'wit', 'quit', 'spit', 'knit', 'grit', 'flit', 'slit', 'twit', 'zit'],
      'et': ['pet', 'get', 'let', 'met', 'net', 'set', 'bet', 'jet', 'wet', 'yet', 'vet', 'fret', 'debt'],
      'ot': ['hot', 'pot', 'dot', 'got', 'lot', 'not', 'cot', 'jot', 'rot', 'tot', 'shot', 'spot', 'plot', 'knot', 'slot', 'blot', 'clot', 'scot', 'bot', 'mot', 'trot'],
      'ut': ['cut', 'but', 'hut', 'nut', 'put', 'gut', 'jut', 'rut', 'shut', 'strut', 'glut'],
      'ed': ['red', 'bed', 'fed', 'wed', 'led', 'shed', 'sled', 'fled', 'bred', 'shred'],
      'ay': ['day', 'way', 'say', 'may', 'bay', 'hay', 'lay', 'pay', 'play', 'stay', 'pray', 'gray', 'clay', 'tray', 'spray', 'stray'],
      'en': ['pen', 'ten', 'men', 'hen', 'den', 'when', 'then', 'glen', 'wren'],
      'ig': ['big', 'dig', 'fig', 'pig', 'wig', 'jig', 'rig', 'twig', 'brig'],
      'og': ['dog', 'log', 'hog', 'jog', 'fog', 'bog', 'cog', 'frog', 'clog'],
      'ug': ['bug', 'hug', 'jug', 'mug', 'rug', 'tug', 'dug', 'pug', 'slug', 'drug', 'snug', 'plug'],
    };
    
    final words = endingWords[ending.toLowerCase()] ?? [];
    return words.where((word) => !existingWords.contains(word)).toList();
  }
  
  /// Get fallback words for specific word lengths
  List<String> _getFallbackWordsForLength(int length, Set<String> existingWords) {
    Map<int, List<String>> lengthWords = {
      3: ['cat', 'dog', 'sun', 'car', 'run', 'fun', 'big', 'red', 'hot', 'box', 'cup', 'hat', 'bag', 'pen', 'bus', 'egg', 'leg', 'arm', 'eye', 'ear'],
      4: ['book', 'tree', 'home', 'play', 'moon', 'hand', 'fish', 'bird', 'cake', 'game', 'ball', 'door', 'food', 'good', 'love', 'help', 'walk', 'talk', 'look', 'read'],
      5: ['house', 'water', 'happy', 'green', 'brown', 'black', 'white', 'plant', 'music', 'chair', 'table', 'light', 'paper', 'start', 'smile', 'laugh', 'learn', 'teach', 'words', 'sound'],
      6: ['school', 'family', 'friend', 'animal', 'garden', 'flower', 'orange', 'purple', 'yellow', 'pencil', 'window', 'bright', 'simple', 'little', 'middle', 'change', 'create', 'health', 'growth', 'spring'],
    };
    
    final words = lengthWords[length] ?? [];
    return words.where((word) => !existingWords.contains(word)).toList();
  }
  
  /// Get fallback words for phonics patterns
  List<String> _getFallbackWordsForPattern(String pattern, Set<String> existingWords) {
    Map<String, List<String>> patternWords = {
      'short_a': ['cat', 'bat', 'hat', 'can', 'man', 'ran', 'bag', 'tag', 'nap', 'cap', 'map'],
      'short_e': ['bed', 'red', 'fed', 'net', 'bet', 'get', 'let', 'met', 'pet', 'set', 'wet'],
      'short_i': ['bit', 'hit', 'sit', 'fit', 'big', 'dig', 'fig', 'pig', 'win', 'pin', 'tin'],
      'short_o': ['hot', 'pot', 'dot', 'got', 'box', 'fox', 'top', 'hop', 'pop', 'cop', 'mop'],
      'short_u': ['cut', 'but', 'hut', 'nut', 'run', 'sun', 'fun', 'bun', 'cup', 'pup', 'up'],
      'long_a': ['cake', 'make', 'take', 'lake', 'game', 'name', 'same', 'came', 'day', 'way', 'say'],
      'long_e': ['tree', 'free', 'see', 'bee', 'knee', 'feet', 'meet', 'sweet', 'green', 'seen', 'been'],
      'long_i': ['bike', 'like', 'hike', 'time', 'dime', 'lime', 'nine', 'line', 'mine', 'fine', 'pine'],
      'long_o': ['boat', 'coat', 'goat', 'road', 'soap', 'rope', 'hope', 'note', 'home', 'bone', 'cone'],
      'long_u': ['cute', 'tube', 'cube', 'huge', 'tune', 'blue', 'glue', 'true', 'due', 'sue', 'clue'],
    };
    
    final words = patternWords[pattern] ?? [];
    return words.where((word) => !existingWords.contains(word)).toList();
  }

  Future<void> _startGame() async {
    try {
      print('🎓 TEACHER REVIEW: Starting game ${widget.gameSession.gameId}');
      print('🎓 TEACHER REVIEW: Current status: ${widget.gameSession.status}');
      
      // First update the game session with the reviewed word grid
      final updatedGameSession = widget.gameSession.copyWith(
        wordGrid: _currentWordGrid,
      );
      await GameSessionService.updateGameSession(updatedGameSession);
      
      // Don't change status to inProgress yet - keep it as waitingForPlayers so students can join
      // The game will start automatically when players join or teacher manually starts it
      print('🎓 TEACHER REVIEW: Game published and ready for students to join');
      // Just save the updated game session with the reviewed word grid
      
      // Game state will be initialized when the first player joins
      print('⚠️ Game published without players - game state will be initialized when first player joins');
      
      final publishedGame = updatedGameSession;
      
      // Navigate to the success screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: Text('Game: ${publishedGame.gameName}'),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.school, size: 64, color: AppColors.success),
                    const SizedBox(height: 16),
                    Text(
                      'Game Published!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Game Code',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            publishedGame.gameId,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Students can now join using this game code.\nThe game will start automatically when enough players join.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Back to Dashboard'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error starting game: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _cancelAndCleanup();
        }
      },
      child: Scaffold(
      backgroundColor: AppColors.gameBackground,
      appBar: AppBar(
        title: Text('Review: ${widget.gameSession.gameName}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_selectedWords.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ElevatedButton.icon(
                onPressed: _isRegenerating ? null : _regenerateSelectedWords,
                icon: _isRegenerating 
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh, size: 20),
                label: Text(_isRegenerating ? 'Regenerating...' : 'Regenerate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.mediumBlue.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.info, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap words to select them for regeneration. Selected words will be replaced with new ones using the same prompt.',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: isTablet ? 16 : 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Word Grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Grid
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.lightGray, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            for (int row = 0; row < _currentWordGrid.length; row++)
                              Expanded(
                                child: Row(
                                  children: [
                                    for (int col = 0; col < _currentWordGrid[row].length; col++)
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => _toggleWordSelection(row, col),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              border: Border(
                                                right: col < _currentWordGrid[row].length - 1
                                                  ? BorderSide(color: AppColors.lightGray, width: 1)
                                                  : BorderSide.none,
                                                bottom: row < _currentWordGrid.length - 1
                                                  ? BorderSide(color: AppColors.lightGray, width: 1)
                                                  : BorderSide.none,
                                              ),
                                              color: _selectedWords.contains('$row-$col')
                                                ? AppColors.warning.withOpacity(0.3)
                                                : Colors.white,
                                            ),
                                            child: Center(
                                              child: Text(
                                                _currentWordGrid[row][col],
                                                style: TextStyle(
                                                  fontSize: isTablet ? 18 : 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: _selectedWords.contains('$row-$col')
                                                    ? AppColors.warning
                                                    : AppColors.textPrimary,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Selection info
                    if (_selectedWords.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.warning),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_box, color: AppColors.warning),
                            const SizedBox(width: 8),
                            Text(
                              '${_selectedWords.length} ${_selectedWords.length == 1 ? "word" : "words"} selected for regeneration',
                              style: TextStyle(
                                color: AppColors.warning,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => setState(() => _selectedWords.clear()),
                              child: Text(
                                'Clear Selection',
                                style: TextStyle(color: AppColors.warning),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Bottom buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _cancelAndCleanup(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: BorderSide(color: AppColors.lightGray),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _startGame,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Game'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}