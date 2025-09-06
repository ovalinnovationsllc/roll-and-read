import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import '../config/app_colors.dart';
import '../widgets/animated_dice.dart';
import '../services/datamuse_service.dart';
import '../models/user_model.dart';
import '../models/game_session_model.dart';
import '../services/sound_service.dart';
import '../utils/tts_helper.dart';

class RollAndReadGame extends StatefulWidget {
  final UserModel? user;
  final GameSessionModel? gameSession;
  final String? gameName;
  final List<List<String>>? wordGrid;
  final bool isTeacherMode;
  
  const RollAndReadGame({
    super.key,
    this.user,
    this.gameSession,
    this.gameName,
    this.wordGrid,
    this.isTeacherMode = false,
  });

  @override
  State<RollAndReadGame> createState() => _RollAndReadGameState();
}

class _RollAndReadGameState extends State<RollAndReadGame> {
  final Random _random = Random();
  int _diceValue = 1;
  bool _isRolling = false;
  bool _canRoll = true;
  bool _hasRolled = false;
  bool _hasSelectedThisTurn = false; // Track if player has selected a square this turn
  bool _isLoadingWords = false;
  late FlutterTts _flutterTts;
  
  // Track which cells have been selected/completed
  final Set<String> _completedCells = {};
  
  // Grid content - 6 columns (for dice 1-6) x 6 rows
  late List<List<String>> gridContent;
  
  @override
  void initState() {
    super.initState();
    _initializeGrid();
    _initializeTts();
    // Only load long U words if we're not using AI-generated words
    if (widget.gameSession == null || !widget.gameSession!.useAIWords) {
      _loadLongUWords();
    }
  }

  Future<void> _initializeTts() async {
    try {
      _flutterTts = FlutterTts();
      await _flutterTts.setLanguage("en-US");
      
      // Set a specific voice that sounds more natural on iOS
      if (Platform.isIOS) {
        // Use the helper to set iOS voice with multiple fallbacks
        await TTSHelper.setIOSVoice(_flutterTts);
        
        // Uncomment the line below to debug and see available voices
        // await TTSHelper.logAvailableVoices();
      }
      
      await _flutterTts.setSpeechRate(0.5); // Slower speech for young learners
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
    } catch (e) {
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _speakWord(String word) async {
    try {
      await _flutterTts.speak(word);
    } catch (e) {
    }
  }

  void _initializeGrid() {
    // Priority order: custom wordGrid > gameSession wordGrid > default
    if (widget.wordGrid != null) {
      gridContent = widget.wordGrid!;
    } else if (widget.gameSession?.wordGrid != null) {
      gridContent = widget.gameSession!.wordGrid!;
    } else {
      // Default word grid
      gridContent = [
        ['cat', 'dog', 'pig', 'cow', 'hen', 'fox'],
        ['run', 'hop', 'sit', 'jump', 'walk', 'skip'],
        ['red', 'blue', 'green', 'pink', 'yellow', 'white'],
        ['mom', 'dad', 'sister', 'brother', 'baby', 'family'],
        ['one', 'two', 'three', 'four', 'five', 'six'],
        ['sun', 'moon', 'star', 'cloud', 'rain', 'snow'],
      ];
    }
  }
  
  Future<void> _loadLongUWords() async {
    setState(() {
      _isLoadingWords = true;
    });
    
    try {
      // Use the new Datamuse API to get words with long u sound
      List<String> words = await DatamuseService.generateWordsFromPrompt("words with long u sound");
      List<List<String>> newGrid = DatamuseService.organizeIntoGrid(words);
      
      setState(() {
        gridContent = newGrid;
        _isLoadingWords = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingWords = false;
      });
    }
  }

  void _rollDice() {
    if (!_canRoll) return;

    setState(() {
      _canRoll = false;
      _isRolling = true;
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      setState(() {
        _diceValue = _random.nextInt(6) + 1;
        _hasRolled = true;
        _hasSelectedThisTurn = false; // Reset selection flag for new turn
      });

      Future.delayed(const Duration(milliseconds: 200), () {
        setState(() {
          _isRolling = false;
          _canRoll = true;
        });
      });
    });
  }

  void _toggleCell(int row, int col) {
    // Only allow marking cells in the column that matches the current dice value
    // and only after the user has rolled at least once
    if (col + 1 != _diceValue || _isRolling || !_hasRolled) return;
    
    final cellKey = '$row-$col';
    
    // If the cell is already completed, allow deselection
    if (_completedCells.contains(cellKey)) {
      // Play word selection sound
      SoundService.playWordSelect();
      setState(() {
        _completedCells.remove(cellKey);
        _hasSelectedThisTurn = false; // Allow another selection this turn
      });
      return;
    }
    
    // Don't allow new selections if player has already selected a square this turn
    if (_hasSelectedThisTurn) return;
    
    // Play word selection sound
    SoundService.playWordSelect();
    
    setState(() {
      _completedCells.add(cellKey);
      _hasSelectedThisTurn = true; // Mark that player has selected a square this turn
    });
  }

  void _resetGame() {
    setState(() {
      _diceValue = 1;
      _isRolling = false;
      _canRoll = true;
      _hasRolled = false;
      _hasSelectedThisTurn = false;
      _completedCells.clear();
    });
    _loadLongUWords(); // Reload words on reset
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      backgroundColor: AppColors.gameBackground,
      appBar: AppBar(
        title: Text(
          widget.gameName ?? widget.gameSession?.gameName ?? "Mrs. Elson's Roll and Read",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: AppColors.gamePrimary,
        foregroundColor: AppColors.onPrimary,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetGame,
            tooltip: 'Reset Game',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Dice rolling section
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              color: AppColors.gameBackground,
              child: Center(
                child: AnimatedDice(
                  value: _diceValue,
                  isRolling: _isRolling,
                  size: isTablet ? 120 : 100,
                  onTap: _rollDice,
                ),
              ),
            ),
            
            // Result display
            if (!_isRolling && _hasRolled)
              Container(
                padding: const EdgeInsets.all(10),
                color: AppColors.mediumBlue.withOpacity(0.1),
                child: Text(
                  'You rolled a $_diceValue! Pick a word to read in column $_diceValue',
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkBlue,
                  ),
                ),
              ),
            
            // Grid section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    // Header row with dice
                    Container(
                      height: isTablet ? 70 : 60,
                      decoration: BoxDecoration(
                        color: AppColors.gamePrimary.withOpacity(0.1),
                        border: Border.all(color: AppColors.gamePrimary.withOpacity(0.3), width: 2),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10),
                        ),
                      ),
                      child: Row(
                        children: [
                          for (int i = 1; i <= 6; i++)
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: i < 6 
                                      ? BorderSide(color: AppColors.gamePrimary.withOpacity(0.3), width: 1)
                                      : BorderSide.none,
                                  ),
                                  color: _diceValue == i && !_isRolling
                                    ? AppColors.mediumBlue.withOpacity(0.3)
                                    : Colors.transparent,
                                ),
                                child: Center(
                                  child: _buildDiceIcon(i, isTablet ? 40 : 35),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    // Grid rows
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.gamePrimary.withOpacity(0.3), width: 2),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(10),
                            bottomRight: Radius.circular(10),
                          ),
                        ),
                        child: _isLoadingWords
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    color: AppColors.gamePrimary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Loading long u words...',
                                    style: TextStyle(
                                      fontSize: isTablet ? 18 : 16,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                          children: [
                            for (int row = 0; row < 6; row++)
                              Expanded(
                                child: Row(
                                  children: [
                                    for (int col = 0; col < 6; col++)
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => _toggleCell(row, col),
                                          onLongPress: () => _speakWord(gridContent[row][col]),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              border: Border(
                                                right: col < 5 
                                                  ? BorderSide(color: AppColors.lightGray, width: 1)
                                                  : BorderSide.none,
                                                bottom: row < 5
                                                  ? BorderSide(color: AppColors.lightGray, width: 1)
                                                  : BorderSide.none,
                                              ),
                                              color: _completedCells.contains('$row-$col')
                                                ? (widget.user?.playerColor?.withOpacity(0.3) ?? AppColors.gamePrimary.withOpacity(0.1))
                                                : (_diceValue == col + 1 && !_isRolling
                                                  ? AppColors.mediumBlue.withOpacity(0.1)
                                                  : AppColors.white),
                                            ),
                                            child: Stack(
                                              children: [
                                                Center(
                                                  child: Text(
                                                    gridContent[row][col],
                                                    style: TextStyle(
                                                      fontSize: isTablet ? 18 : 14,
                                                      fontWeight: FontWeight.w600,
                                                      color: _completedCells.contains('$row-$col')
                                                        ? (widget.user?.playerColor?.withOpacity(1.0) ?? AppColors.gamePrimary)
                                                        : AppColors.textPrimary,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                                // Star indicator for completed cells
                                                if (_completedCells.contains('$row-$col'))
                                                  Positioned(
                                                    top: 2,
                                                    right: 2,
                                                    child: Icon(
                                                      Icons.star,
                                                      size: isTablet ? 20 : 16,
                                                      color: AppColors.mediumBlue,
                                                    ),
                                                  ),
                                              ],
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
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: AppColors.lightGray.withOpacity(0.3),
              child: Center(
                child: Text(
                  'Built by: Oval Innovations, LLC',
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 12,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDiceIcon(int value, double size) {
    final dotSize = size * 0.15;
    final dotColor = AppColors.textPrimary;
    
    Widget dot() => Container(
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(
        color: dotColor,
        shape: BoxShape.circle,
      ),
    );

    Widget empty() => SizedBox(width: dotSize, height: dotSize);

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.15),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.textPrimary, width: 2),
        borderRadius: BorderRadius.circular(size * 0.15),
      ),
      child: _getDicePattern(value, dot, empty),
    );
  }
  
  Widget _getDicePattern(int value, Widget Function() dot, Widget Function() empty) {
    switch (value) {
      case 1:
        return Center(child: dot());
      case 2:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [dot()],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [dot()],
            ),
          ],
        );
      case 3:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [dot()],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [dot()],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [dot()],
            ),
          ],
        );
      case 4:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [dot(), dot()],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [dot(), dot()],
            ),
          ],
        );
      case 5:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [dot(), dot()],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [dot()],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [dot(), dot()],
            ),
          ],
        );
      case 6:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [dot(), dot()],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [dot(), dot()],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [dot(), dot()],
            ),
          ],
        );
      default:
        return const SizedBox();
    }
  }
}