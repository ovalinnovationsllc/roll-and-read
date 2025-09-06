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
        wordsBeingReplaced.add(_currentWordGrid[row][col]);
      }
      
      print('🚫 Words to avoid: ${currentWords.union(wordsBeingReplaced).join(", ")}');
      
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
          if (!currentWords.contains(word) && 
              !wordsBeingReplaced.contains(word) && 
              !candidateWords.contains(word)) {
            candidateWords.add(word);
          }
        }
        
        print('🎯 Found ${candidateWords.length} unique candidate words so far');
      }
      
      // If we still don't have enough unique words, add some fallback words
      if (candidateWords.length < _selectedWords.length) {
        final fallbackWords = [
          'book', 'read', 'learn', 'study', 'write', 'draw', 'play', 'sing',
          'dance', 'jump', 'run', 'walk', 'talk', 'think', 'smile', 'laugh',
          'help', 'kind', 'nice', 'good', 'best', 'great', 'super', 'fun',
          'happy', 'joy', 'peace', 'love', 'hope', 'dream', 'wish', 'try'
        ];
        
        for (String word in fallbackWords) {
          if (!currentWords.contains(word) && 
              !wordsBeingReplaced.contains(word) && 
              !candidateWords.contains(word) &&
              candidateWords.length < _selectedWords.length) {
            candidateWords.add(word);
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
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Regenerated $replacedCount ${replacedCount == 1 ? "word" : "words"} with unique alternatives'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      
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
    
    return Scaffold(
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
                      onPressed: () => Navigator.pop(context),
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
    );
  }
}