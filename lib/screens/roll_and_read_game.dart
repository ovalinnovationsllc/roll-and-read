import 'package:flutter/material.dart';
import 'dart:math';
import '../widgets/animated_dice.dart';

class RollAndReadGame extends StatefulWidget {
  const RollAndReadGame({super.key});

  @override
  State<RollAndReadGame> createState() => _RollAndReadGameState();
}

class _RollAndReadGameState extends State<RollAndReadGame> {
  final Random _random = Random();
  int _diceValue = 1;
  bool _isRolling = false;
  bool _canRoll = true;
  
  // Track which cells have been selected/completed
  final Set<String> _completedCells = {};
  
  // Grid content - 6 columns (for dice 1-6) x 6 rows
  final List<List<String>> gridContent = [
    ['cat', 'dog', 'pig', 'cow', 'hen', 'fox'],
    ['run', 'hop', 'sit', 'jump', 'walk', 'skip'],
    ['red', 'blue', 'green', 'pink', 'yellow', 'orange'],
    ['mom', 'dad', 'sister', 'brother', 'baby', 'family'],
    ['one', 'two', 'three', 'four', 'five', 'six'],
    ['sun', 'moon', 'star', 'cloud', 'rain', 'snow'],
  ];

  void _rollDice() {
    if (!_canRoll) return;

    setState(() {
      _canRoll = false;
      _isRolling = true;
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      setState(() {
        _diceValue = _random.nextInt(6) + 1;
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
    if (col + 1 != _diceValue || _isRolling) return;
    
    final cellKey = '$row-$col';
    setState(() {
      if (_completedCells.contains(cellKey)) {
        _completedCells.remove(cellKey);
      } else {
        _completedCells.add(cellKey);
      }
    });
  }

  void _resetGame() {
    setState(() {
      _diceValue = 1;
      _isRolling = false;
      _canRoll = true;
      _completedCells.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Mrs Elson's Roll and Read",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
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
              color: Colors.green.shade50,
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
            if (!_isRolling && _diceValue > 0)
              Container(
                padding: const EdgeInsets.all(10),
                color: Colors.amber.shade100,
                child: Text(
                  'You rolled a $_diceValue! Find a word in column $_diceValue',
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
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
                        color: Colors.blue.shade100,
                        border: Border.all(color: Colors.blue.shade300, width: 2),
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
                                      ? BorderSide(color: Colors.blue.shade300, width: 1)
                                      : BorderSide.none,
                                  ),
                                  color: _diceValue == i && !_isRolling
                                    ? Colors.yellow.shade300
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
                          border: Border.all(color: Colors.blue.shade300, width: 2),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(10),
                            bottomRight: Radius.circular(10),
                          ),
                        ),
                        child: Column(
                          children: [
                            for (int row = 0; row < 6; row++)
                              Expanded(
                                child: Row(
                                  children: [
                                    for (int col = 0; col < 6; col++)
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => _toggleCell(row, col),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              border: Border(
                                                right: col < 5 
                                                  ? BorderSide(color: Colors.grey.shade300, width: 1)
                                                  : BorderSide.none,
                                                bottom: row < 5
                                                  ? BorderSide(color: Colors.grey.shade300, width: 1)
                                                  : BorderSide.none,
                                              ),
                                              color: _completedCells.contains('$row-$col')
                                                ? Colors.green.shade100
                                                : (_diceValue == col + 1 && !_isRolling
                                                  ? Colors.yellow.shade50
                                                  : Colors.white),
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
                                                        ? Colors.green.shade800
                                                        : Colors.black87,
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
                                                      color: Colors.amber.shade600,
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
              color: Colors.grey.shade200,
              child: Center(
                child: Text(
                  'Built by: Oval Innovations, LLC',
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 12,
                    color: Colors.grey.shade700,
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
    final dotColor = Colors.black87;
    
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
        color: Colors.white,
        border: Border.all(color: Colors.black87, width: 2),
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