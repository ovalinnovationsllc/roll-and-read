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

    // Ask teacher what type of words they want
    final prompt = await _showWordPatternDialog();
    if (prompt == null) return; // User cancelled
    
    setState(() {
      _isRegenerating = true;
    });

    try {
      // Use the teacher's specified prompt instead of the original game prompt
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
      
      // FIRST: Try pattern-specific fallback words (our phonics word lists)
      print('🔍 Prompt for pattern detection: "$prompt"');
      final patternFallbackWords = _getPatternSpecificFallbacks(prompt, wordsToAvoid);
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
      
      // SECOND: If pattern words aren't enough, try AI generation
      while (candidateWords.length < _selectedWords.length * 2 && attempts < maxAttempts) {
        attempts++;
        print('🎲 AI generation attempt $attempts (after pattern fallbacks)');
        
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
      
      // THIRD: If we still need more words, try related patterns
      if (candidateWords.length < _selectedWords.length) {
        print('⚠️ Still need more words, trying related patterns');
        final relatedWords = _getRelatedPatternWords(prompt, wordsToAvoid.union(candidateWords.toSet()));
        print('🎯 Related pattern words found: $relatedWords');
        
        for (String word in relatedWords) {
          if (!wordsToAvoid.contains(word) && 
              !candidateWords.contains(word) &&
              candidateWords.length < _selectedWords.length) {
            candidateWords.add(word);
            print('🔄 Added related pattern word: "$word"');
          }
        }
      }
      
      // FOURTH: Try one more AI generation attempt with broader prompt
      if (candidateWords.length < _selectedWords.length && attempts < maxAttempts) {
        print('⚠️ Still need more words, trying broader AI generation');
        final broaderPrompt = _createBroaderPrompt(prompt);
        print('🔄 Broader prompt: "$broaderPrompt"');
        
        try {
          final additionalGrid = await AIWordService.generateWordGrid(
            prompt: broaderPrompt,
            difficulty: difficulty,
            gameId: widget.gameSession.gameId,
            gameName: widget.gameSession.gameName,
          );
          
          final additionalWords = additionalGrid.expand((row) => row).toList();
          for (String word in additionalWords) {
            if (!wordsToAvoid.contains(word) && 
                !candidateWords.contains(word) &&
                candidateWords.length < _selectedWords.length) {
              candidateWords.add(word);
              print('🔄 Added from broader generation: "$word"');
            }
          }
        } catch (e) {
          print('⚠️ Broader generation failed: $e');
        }
      }
      
      // FIFTH: Only use generic fallbacks as last resort
      if (candidateWords.length < _selectedWords.length) {
        print('⚠️ All attempts exhausted, using minimal generic fallbacks');
        final genericFallbacks = [
          'good', 'nice', 'fun', 'best', 'great', 'super', 'happy', 'smile'
        ];
        
        for (String word in genericFallbacks) {
          if (!wordsToAvoid.contains(word) && 
              !candidateWords.contains(word) &&
              candidateWords.length < _selectedWords.length) {
            candidateWords.add(word);
            print('🔄 Added minimal generic fallback: "$word"');
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

  Future<String?> _showWordPatternDialog() async {
    final TextEditingController controller = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('What type of words do you want?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Examples:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• "short a words" or "soft a sound"'),
              Text('• "long e words" or "magic e with e"'),
              Text('• "words ending in -ing"'),
              Text('• "3 letter words"'),
              Text('• "CVC words with o"'),
              SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Word pattern or type',
                  hintText: 'e.g., short a words',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    Navigator.of(context).pop(value.trim());
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  Navigator.of(context).pop(text);
                }
              },
              child: Text('Generate'),
            ),
          ],
        );
      },
    );
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
    
    // Detect phonics patterns (with multiple variations)
    // Short/Soft A patterns
    if (lowerPrompt.contains('short a') || lowerPrompt.contains('soft a') || 
        lowerPrompt.contains('a sound') && (lowerPrompt.contains('short') || lowerPrompt.contains('soft')) ||
        lowerPrompt.contains('cvc') && lowerPrompt.contains('a')) {
      print('🎯 Detected short/soft A pattern');
      return _getFallbackWordsForPattern('short_a', existingWords);
    }
    // Short/Soft E patterns  
    else if (lowerPrompt.contains('short e') || lowerPrompt.contains('soft e') ||
        lowerPrompt.contains('e sound') && (lowerPrompt.contains('short') || lowerPrompt.contains('soft')) ||
        lowerPrompt.contains('cvc') && lowerPrompt.contains('e')) {
      print('🎯 Detected short/soft E pattern');
      return _getFallbackWordsForPattern('short_e', existingWords);
    }
    // Short/Soft I patterns
    else if (lowerPrompt.contains('short i') || lowerPrompt.contains('soft i') ||
        lowerPrompt.contains('i sound') && (lowerPrompt.contains('short') || lowerPrompt.contains('soft')) ||
        lowerPrompt.contains('cvc') && lowerPrompt.contains('i')) {
      print('🎯 Detected short/soft I pattern');
      return _getFallbackWordsForPattern('short_i', existingWords);
    }
    // Short/Soft O patterns
    else if (lowerPrompt.contains('short o') || lowerPrompt.contains('soft o') ||
        lowerPrompt.contains('o sound') && (lowerPrompt.contains('short') || lowerPrompt.contains('soft')) ||
        lowerPrompt.contains('cvc') && lowerPrompt.contains('o')) {
      print('🎯 Detected short/soft O pattern');
      return _getFallbackWordsForPattern('short_o', existingWords);
    }
    // Short/Soft U patterns
    else if (lowerPrompt.contains('short u') || lowerPrompt.contains('soft u') ||
        lowerPrompt.contains('u sound') && (lowerPrompt.contains('short') || lowerPrompt.contains('soft')) ||
        lowerPrompt.contains('cvc') && lowerPrompt.contains('u')) {
      print('🎯 Detected short/soft U pattern');
      return _getFallbackWordsForPattern('short_u', existingWords);
    }
    // Long/Hard A patterns
    else if (lowerPrompt.contains('long a') || lowerPrompt.contains('hard a') ||
        lowerPrompt.contains('a sound') && (lowerPrompt.contains('long') || lowerPrompt.contains('hard')) ||
        lowerPrompt.contains('magic e') && lowerPrompt.contains('a') ||
        lowerPrompt.contains('cvce') && lowerPrompt.contains('a')) {
      print('🎯 Detected long/hard A pattern');
      return _getFallbackWordsForPattern('long_a', existingWords);
    }
    // Long/Hard E patterns
    else if (lowerPrompt.contains('long e') || lowerPrompt.contains('hard e') ||
        lowerPrompt.contains('e sound') && (lowerPrompt.contains('long') || lowerPrompt.contains('hard')) ||
        lowerPrompt.contains('magic e') && lowerPrompt.contains('e') ||
        lowerPrompt.contains('cvce') && lowerPrompt.contains('e')) {
      print('🎯 Detected long/hard E pattern');
      return _getFallbackWordsForPattern('long_e', existingWords);
    }
    // Long/Hard I patterns
    else if (lowerPrompt.contains('long i') || lowerPrompt.contains('hard i') ||
        lowerPrompt.contains('i sound') && (lowerPrompt.contains('long') || lowerPrompt.contains('hard')) ||
        lowerPrompt.contains('magic e') && lowerPrompt.contains('i') ||
        lowerPrompt.contains('cvce') && lowerPrompt.contains('i')) {
      print('🎯 Detected long/hard I pattern');
      return _getFallbackWordsForPattern('long_i', existingWords);
    }
    // Long/Hard O patterns
    else if (lowerPrompt.contains('long o') || lowerPrompt.contains('hard o') ||
        lowerPrompt.contains('o sound') && (lowerPrompt.contains('long') || lowerPrompt.contains('hard')) ||
        lowerPrompt.contains('magic e') && lowerPrompt.contains('o') ||
        lowerPrompt.contains('cvce') && lowerPrompt.contains('o')) {
      print('🎯 Detected long/hard O pattern');
      return _getFallbackWordsForPattern('long_o', existingWords);
    }
    // Long/Hard U patterns
    else if (lowerPrompt.contains('long u') || lowerPrompt.contains('hard u') ||
        lowerPrompt.contains('u sound') && (lowerPrompt.contains('long') || lowerPrompt.contains('hard')) ||
        lowerPrompt.contains('magic e') && lowerPrompt.contains('u') ||
        lowerPrompt.contains('cvce') && lowerPrompt.contains('u')) {
      print('🎯 Detected long/hard U pattern');
      return _getFallbackWordsForPattern('long_u', existingWords);
    }
    
    // Detect other common phonics patterns
    if (lowerPrompt.contains('cvc')) {
      print('🎯 Detected CVC pattern');
      // Return a mix of CVC words
      return ['cat', 'dog', 'sun', 'box', 'run', 'hop', 'sit', 'pen', 'bug', 'map', 'leg', 'cup', 'hat', 'bed', 'top'].where((word) => !existingWords.contains(word)).toList();
    }
    
    // Additional common teacher patterns
    if (lowerPrompt.contains('silent e') || lowerPrompt.contains('magic e') || lowerPrompt.contains('cvce')) {
      print('🎯 Detected silent/magic E pattern');
      // Mix of long vowel words with silent e
      List<String> silentEWords = [];
      silentEWords.addAll(_getFallbackWordsForPattern('long_a', existingWords));
      silentEWords.addAll(_getFallbackWordsForPattern('long_i', existingWords));
      silentEWords.addAll(_getFallbackWordsForPattern('long_o', existingWords));
      silentEWords.addAll(_getFallbackWordsForPattern('long_u', existingWords));
      return silentEWords.take(20).toList();
    }
    
    // Pattern for just vowel letters without modifiers
    if (RegExp(r'\b[aeiou]\b').hasMatch(lowerPrompt) && lowerPrompt.length < 10) {
      if (lowerPrompt.contains('a')) {
        print('🎯 Detected simple A pattern (defaulting to short A)');
        return _getFallbackWordsForPattern('short_a', existingWords);
      } else if (lowerPrompt.contains('e')) {
        print('🎯 Detected simple E pattern (defaulting to short E)');
        return _getFallbackWordsForPattern('short_e', existingWords);
      } else if (lowerPrompt.contains('i')) {
        print('🎯 Detected simple I pattern (defaulting to short I)');
        return _getFallbackWordsForPattern('short_i', existingWords);
      } else if (lowerPrompt.contains('o')) {
        print('🎯 Detected simple O pattern (defaulting to short O)');
        return _getFallbackWordsForPattern('short_o', existingWords);
      } else if (lowerPrompt.contains('u')) {
        print('🎯 Detected simple U pattern (defaulting to short U)');
        return _getFallbackWordsForPattern('short_u', existingWords);
      }
    }
    
    // Detect general sound-based patterns (fallback for simple vowel sound requests)
    if (lowerPrompt.contains('sound') || lowerPrompt.contains('phonics')) {
      if (lowerPrompt.contains('o sound') || lowerPrompt.contains('o phonics')) {
        print('🎯 Detected general O sound pattern (defaulting to short O)');
        return _getFallbackWordsForPattern('short_o', existingWords);
      } else if (lowerPrompt.contains('a sound') || lowerPrompt.contains('a phonics')) {
        print('🎯 Detected general A sound pattern (defaulting to short A)');
        return _getFallbackWordsForPattern('short_a', existingWords);
      } else if (lowerPrompt.contains('e sound') || lowerPrompt.contains('e phonics')) {
        print('🎯 Detected general E sound pattern (defaulting to short E)');
        return _getFallbackWordsForPattern('short_e', existingWords);
      } else if (lowerPrompt.contains('i sound') || lowerPrompt.contains('i phonics')) {
        print('🎯 Detected general I sound pattern (defaulting to short I)');
        return _getFallbackWordsForPattern('short_i', existingWords);
      } else if (lowerPrompt.contains('u sound') || lowerPrompt.contains('u phonics')) {
        print('🎯 Detected general U sound pattern (defaulting to short U)');
        return _getFallbackWordsForPattern('short_u', existingWords);
      }
    }
    
    // No specific pattern detected
    return [];
  }
  
  /// Get fallback words for a specific ending pattern
  List<String> _getFallbackWordsForEnding(String ending, Set<String> existingWords) {
    Map<String, List<String>> endingWords = {
      'an': ['can', 'man', 'ran', 'pan', 'fan', 'tan', 'ban', 'van', 'plan', 'than', 'scan', 'span', 'clan', 'gran', 'bran', 'flan', 'dan', 'gan', 'han', 'jan', 'lan', 'nan', 'san', 'wan', 'yan', 'zan', 'blan', 'chan', 'dran', 'fran'],
      'at': ['cat', 'bat', 'hat', 'mat', 'rat', 'sat', 'pat', 'fat', 'vat', 'chat', 'flat', 'that', 'brat', 'scat', 'spat', 'drat', 'splat', 'slat', 'swat', 'gnat', 'zat', 'lat', 'wat', 'dat', 'nat', 'jat', 'yat', 'blat', 'clat', 'grat', 'prat'],
      'in': ['pin', 'win', 'tin', 'bin', 'fin', 'chin', 'thin', 'skin', 'spin', 'grin', 'twin', 'shin', 'din', 'kin', 'sin', 'gin', 'begin', 'within', 'cabin', 'lin', 'min', 'nin', 'rin', 'vin', 'yin', 'zin', 'brin', 'clin', 'drin', 'flin'],
      'un': ['run', 'sun', 'fun', 'bun', 'gun', 'nun', 'pun', 'dun', 'spun', 'stun', 'shun', 'hun', 'tun', 'begun', 'outrun', 'jun', 'kun', 'lun', 'mun', 'vun', 'wun', 'yun', 'zun', 'brun', 'chun', 'drun', 'frun', 'grun', 'plun', 'trun'],
      'it': ['sit', 'hit', 'bit', 'fit', 'kit', 'lit', 'pit', 'wit', 'quit', 'spit', 'knit', 'grit', 'flit', 'slit', 'twit', 'zit', 'split', 'smit', 'whit', 'brit', 'chit', 'dit', 'mit', 'nit', 'rit', 'vit', 'yit', 'jit', 'tit', 'blit', 'crit', 'drit'],
      'et': ['pet', 'get', 'let', 'met', 'net', 'set', 'bet', 'jet', 'wet', 'yet', 'vet', 'fret', 'whet', 'duet', 'cadet', 'beret', 'inlet', 'sunset', 'beget', 'reset', 'det', 'fet', 'het', 'ket', 'ret', 'tet', 'zet', 'blet', 'chet', 'shet', 'tret'],
      'ot': ['hot', 'pot', 'dot', 'got', 'lot', 'not', 'cot', 'jot', 'rot', 'tot', 'shot', 'spot', 'plot', 'knot', 'slot', 'blot', 'clot', 'scot', 'bot', 'mot', 'trot', 'fot', 'kot', 'sot', 'wot', 'yot', 'zot', 'brot', 'drot', 'grot', 'prot'],
      'ut': ['cut', 'but', 'hut', 'nut', 'put', 'gut', 'jut', 'rut', 'shut', 'strut', 'glut', 'tut', 'smut', 'scut', 'mutt', 'butt', 'putt', 'fut', 'lut', 'mut', 'sut', 'wut', 'yut', 'zut', 'brut', 'clut', 'drut', 'flut', 'grut', 'plut', 'stut'],
      'ed': ['red', 'bed', 'fed', 'wed', 'led', 'shed', 'sled', 'fled', 'bred', 'shred', 'bled', 'sped', 'med', 'zed', 'ted', 'ned', 'jed', 'fred', 'ded', 'ged', 'hed', 'ked', 'ped', 'sed', 'ved', 'yed', 'cled', 'dred', 'gred', 'tred'],
      'ay': ['day', 'way', 'say', 'may', 'bay', 'hay', 'lay', 'pay', 'play', 'stay', 'pray', 'gray', 'clay', 'tray', 'spray', 'stray', 'away', 'okay', 'today', 'relay', 'delay', 'sway', 'fray', 'decay', 'array'],
      'en': ['pen', 'ten', 'men', 'hen', 'den', 'when', 'then', 'glen', 'wren', 'yen', 'zen', 'ken', 'ben', 'fen', 'gen', 'jen', 'len', 'nen', 'ren', 'sen', 'ven', 'wen', 'bren', 'chen', 'dren', 'fren', 'gren', 'pren', 'shen', 'tren'],
      'ig': ['big', 'dig', 'fig', 'pig', 'wig', 'jig', 'rig', 'twig', 'brig', 'gig', 'sig', 'zig', 'mig', 'tig', 'whig', 'sprig', 'cig', 'hig', 'kig', 'lig', 'nig', 'vig', 'yig', 'blig', 'crig', 'drig', 'frig', 'grig', 'plig', 'trig'],
      'og': ['dog', 'log', 'hog', 'jog', 'fog', 'bog', 'cog', 'frog', 'clog', 'sog', 'tog', 'grog', 'smog', 'slog', 'flog', 'agog', 'kog', 'mog', 'nog', 'pog', 'rog', 'vog', 'wog', 'yog', 'zog', 'blog', 'drog', 'glog', 'prog', 'trog'],
      'ug': ['bug', 'hug', 'jug', 'mug', 'rug', 'tug', 'dug', 'pug', 'slug', 'drug', 'snug', 'plug', 'chug', 'shrug', 'smug', 'thug', 'fug', 'gug', 'lug', 'nug', 'sug', 'vug', 'wug', 'yug', 'zug', 'brug', 'clug', 'dug', 'frug', 'glug'],
      'ag': ['bag', 'tag', 'lag', 'rag', 'sag', 'wag', 'flag', 'drag', 'snag', 'brag', 'gag', 'hag', 'jag', 'mag', 'nag', 'stag', 'swag', 'crag', 'shag', 'slag', 'dag', 'fag', 'kag', 'pag', 'vag', 'yag', 'zag', 'blag', 'clag', 'frag', 'grag'],
      'eg': ['leg', 'beg', 'peg', 'keg', 'meg', 'egg', 'nutmeg', 'greg', 'veg', 'dreg', 'deg', 'feg', 'heg', 'jeg', 'neg', 'reg', 'seg', 'teg', 'weg', 'yeg', 'zeg', 'bleg', 'cleg', 'dreg', 'fleg', 'gleg', 'preg', 'skeg', 'treg', 'yegg'],
      'ing': ['ring', 'sing', 'king', 'wing', 'bring', 'string', 'spring', 'thing', 'sting', 'swing', 'ding', 'fling', 'cling', 'sling', 'wring', 'bing', 'ging', 'hing', 'jing', 'ling', 'ming', 'ning', 'ping', 'ting', 'ving', 'ying', 'zing', 'bling', 'ching', 'shing'],
      'ong': ['song', 'long', 'gong', 'strong', 'wrong', 'kong', 'dong', 'tong', 'hong', 'jong', 'pong', 'bong', 'along', 'belong', 'prong', 'throng', 'fong', 'mong', 'nong', 'rong', 'vong', 'wong', 'yong', 'zong', 'clong', 'drong', 'flong', 'grong', 'plong', 'trong'],
      'ung': ['lung', 'rung', 'sung', 'hung', 'young', 'swung', 'sprung', 'flung', 'clung', 'wrung', 'strung', 'bung', 'dung', 'gung', 'kung', 'pung', 'tung', 'fung', 'jung', 'mung', 'nung', 'vung', 'wung', 'yung', 'zung', 'brung', 'chung', 'drung', 'grung', 'plung'],
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
  
  /// Get related pattern words when the specific pattern is exhausted
  List<String> _getRelatedPatternWords(String prompt, Set<String> existingWords) {
    final lowerPrompt = prompt.toLowerCase();
    
    // If it's an ending pattern, try related endings
    final endingMatch = RegExp(r'(?:ending|end|ends|that end) (?:in|with) ["\x27]?-?(\w+)["\x27]?').firstMatch(lowerPrompt);
    if (endingMatch != null) {
      final ending = endingMatch.group(1);
      print('🔄 Original ending "$ending" exhausted, trying related endings');
      
      // Define related ending groups
      Map<String, List<String>> relatedEndings = {
        'ig': ['ag', 'eg', 'og', 'ug'], // All short vowel + g
        'ag': ['ig', 'eg', 'og', 'ug'],
        'eg': ['ig', 'ag', 'og', 'ug'],
        'og': ['ig', 'ag', 'eg', 'ug'],
        'ug': ['ig', 'ag', 'eg', 'og'],
        'at': ['it', 'et', 'ot', 'ut'], // All short vowel + t
        'it': ['at', 'et', 'ot', 'ut'],
        'et': ['at', 'it', 'ot', 'ut'],
        'ot': ['at', 'it', 'et', 'ut'],
        'ut': ['at', 'it', 'et', 'ot'],
        'an': ['in', 'en', 'on', 'un'], // All short vowel + n
        'in': ['an', 'en', 'on', 'un'],
        'en': ['an', 'in', 'on', 'un'],
        'un': ['an', 'in', 'en', 'on'],
      };
      
      final related = relatedEndings[ending?.toLowerCase()] ?? [];
      List<String> allRelatedWords = [];
      
      for (final relatedEnding in related) {
        final words = _getFallbackWordsForEnding(relatedEnding, existingWords);
        allRelatedWords.addAll(words);
        if (allRelatedWords.length >= 10) break; // Don't get too many
      }
      
      return allRelatedWords.take(10).toList();
    }
    
    // For other patterns, provide similar pattern words
    return [];
  }

  /// Create a broader prompt for additional word generation
  String _createBroaderPrompt(String originalPrompt) {
    final lowerPrompt = originalPrompt.toLowerCase();
    
    // If it's a specific phonics pattern, broaden it
    if (lowerPrompt.contains('soft o') || lowerPrompt.contains('short o') || lowerPrompt.contains('o sound')) {
      return 'words with short o sound like hot, dog, and box';
    } else if (lowerPrompt.contains('soft a') || lowerPrompt.contains('short a') || lowerPrompt.contains('a sound')) {
      return 'words with short a sound like cat, bat, and can';
    } else if (lowerPrompt.contains('soft e') || lowerPrompt.contains('short e') || lowerPrompt.contains('e sound')) {
      return 'words with short e sound like bed, red, and pet';
    } else if (lowerPrompt.contains('soft i') || lowerPrompt.contains('short i') || lowerPrompt.contains('i sound')) {
      return 'words with short i sound like big, sit, and win';
    } else if (lowerPrompt.contains('soft u') || lowerPrompt.contains('short u') || lowerPrompt.contains('u sound')) {
      return 'words with short u sound like cut, sun, and run';
    }
    
    // If it's an ending pattern, broaden it
    final endingMatch = RegExp(r'(?:ending|end|ends|that end) (?:in|with) ["\x27]?-?(\w+)["\x27]?').firstMatch(lowerPrompt);
    if (endingMatch != null) {
      final ending = endingMatch.group(1);
      return 'simple words ending with $ending';
    }
    
    // If it's a length pattern, broaden it
    final lengthMatch = RegExp(r'(\d+)\s*letter').firstMatch(lowerPrompt);
    if (lengthMatch != null) {
      final length = int.parse(lengthMatch.group(1)!);
      return 'simple $length letter words for children';
    }
    
    // Default: return a more general version of the original prompt
    return 'simple words similar to: $originalPrompt';
  }

  /// Get fallback words for phonics patterns
  List<String> _getFallbackWordsForPattern(String pattern, Set<String> existingWords) {
    Map<String, List<String>> patternWords = {
      'short_a': ['cat', 'bat', 'hat', 'can', 'man', 'ran', 'bag', 'tag', 'nap', 'cap', 'map', 'dad', 'had', 'mad', 'sad', 'bad', 'pad', 'lad', 'wag', 'lag', 'rag', 'sag'],
      'short_e': ['bed', 'red', 'fed', 'net', 'bet', 'get', 'let', 'met', 'pet', 'set', 'wet', 'hen', 'pen', 'ten', 'men', 'den', 'web', 'leg', 'beg', 'peg', 'keg', 'egg'],
      'short_i': ['bit', 'hit', 'sit', 'fit', 'big', 'dig', 'fig', 'pig', 'win', 'pin', 'tin', 'bin', 'fin', 'dim', 'him', 'rim', 'sim', 'vim', 'wig', 'jig', 'rig', 'zip'],
      'short_o': ['hot', 'pot', 'dot', 'got', 'box', 'fox', 'top', 'hop', 'pop', 'cop', 'mop', 'cot', 'lot', 'not', 'rot', 'sob', 'job', 'rob', 'log', 'dog', 'fog', 'hog', 'jog', 'cod', 'rod', 'nod', 'pod', 'sod', 'mom', 'tom', 'bomb', 'song', 'long', 'gong', 'toss', 'loss', 'boss', 'moss', 'cross', 'soft', 'loft', 'cost', 'lost', 'frost'],
      'short_u': ['cut', 'but', 'hut', 'nut', 'run', 'sun', 'fun', 'bun', 'cup', 'pup', 'up', 'bug', 'hug', 'jug', 'mug', 'rug', 'tug', 'dug', 'gun', 'mud', 'bud', 'dud'],
      'long_a': ['cake', 'make', 'take', 'lake', 'game', 'name', 'same', 'came', 'day', 'way', 'say', 'may', 'bay', 'hay', 'lay', 'pay', 'play', 'stay', 'gray', 'pray', 'clay', 'away'],
      'long_e': ['tree', 'free', 'see', 'bee', 'knee', 'feet', 'meet', 'sweet', 'green', 'seen', 'been', 'three', 'wheel', 'feel', 'peel', 'seed', 'feed', 'need', 'weed', 'deed', 'reed', 'keep'],
      'long_i': ['bike', 'like', 'hike', 'time', 'dime', 'lime', 'nine', 'line', 'mine', 'fine', 'pine', 'kite', 'bite', 'site', 'quite', 'white', 'write', 'smile', 'while', 'drive', 'prize', 'slide'],
      'long_o': ['boat', 'coat', 'goat', 'road', 'soap', 'rope', 'hope', 'note', 'home', 'bone', 'cone', 'tone', 'zone', 'phone', 'stone', 'throne', 'alone', 'whole', 'hole', 'pole', 'role', 'stole'],
      'long_u': ['cute', 'tube', 'cube', 'huge', 'tune', 'blue', 'glue', 'true', 'due', 'sue', 'clue', 'mule', 'rule', 'fuel', 'dune', 'june', 'prune', 'flute', 'mute', 'brute', 'fruit', 'juice'],
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