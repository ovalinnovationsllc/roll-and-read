import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/student_game_model.dart';
import '../models/student_player_profile.dart';
import '../services/student_game_service.dart';
import '../services/student_player_service.dart';
import 'student_game_lobby_page.dart';

class StudentPlayerSetupPage extends StatefulWidget {
  final StudentGameModel game;
  final String gameCode;

  const StudentPlayerSetupPage({
    super.key,
    required this.game,
    required this.gameCode,
  });

  @override
  State<StudentPlayerSetupPage> createState() => _StudentPlayerSetupPageState();
}

class _StudentPlayerSetupPageState extends State<StudentPlayerSetupPage> {
  final _nameController = TextEditingController();
  String _selectedColor = 'blue';
  String _selectedIcon = 'star';
  bool _isJoining = false;
  String? _errorMessage;

  // Available colors for students to choose
  final List<Map<String, dynamic>> _colorOptions = [
    {'color': 'red', 'value': Colors.red, 'name': 'Red'},
    {'color': 'blue', 'value': Colors.blue, 'name': 'Blue'},
    {'color': 'green', 'value': Colors.green, 'name': 'Green'},
    {'color': 'yellow', 'value': Colors.orange, 'name': 'Yellow'},
    {'color': 'purple', 'value': Colors.purple, 'name': 'Purple'},
    {'color': 'pink', 'value': Colors.pink, 'name': 'Pink'},
    {'color': 'teal', 'value': Colors.teal, 'name': 'Teal'},
    {'color': 'orange', 'value': Colors.deepOrange, 'name': 'Orange'},
  ];

  // Available icons for students
  final List<Map<String, dynamic>> _iconOptions = [
    {'icon': 'star', 'iconData': Icons.star, 'name': 'Star'},
    {'icon': 'heart', 'iconData': Icons.favorite, 'name': 'Heart'},
    {'icon': 'cat', 'iconData': Icons.pets, 'name': 'Cat'},
    {'icon': 'dog', 'iconData': Icons.pets, 'name': 'Dog'},
    {'icon': 'sun', 'iconData': Icons.wb_sunny, 'name': 'Sun'},
    {'icon': 'moon', 'iconData': Icons.nights_stay, 'name': 'Moon'},
    {'icon': 'flower', 'iconData': Icons.local_florist, 'name': 'Flower'},
    {'icon': 'butterfly', 'iconData': Icons.flutter_dash, 'name': 'Butterfly'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Color _getColorValue(String colorName) {
    return _colorOptions.firstWhere(
      (opt) => opt['color'] == colorName,
      orElse: () => {'color': 'blue', 'value': Colors.blue, 'name': 'Blue'},
    )['value'] as Color;
  }

  IconData _getIconData(String iconName) {
    return _iconOptions.firstWhere(
      (opt) => opt['icon'] == iconName,
      orElse: () => {'icon': 'star', 'iconData': Icons.star, 'name': 'Star'},
    )['iconData'] as IconData;
  }

  Future<void> _joinGame() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your name';
      });
      return;
    }

    setState(() {
      _isJoining = true;
      _errorMessage = null;
    });

    try {
      // Create or update player profile
      final profile = await StudentPlayerService.createProfile(
        playerName: name,
        avatarColor: _selectedColor,
        avatarIcon: _selectedIcon,
        teacherId: widget.game.teacherId,
      );
      
      if (profile == null) {
        setState(() {
          _errorMessage = 'Could not create player profile. Please try again.';
          _isJoining = false;
        });
        return;
      }

      // Add player to game with custom name and appearance
      final result = await StudentGameService.addPlayerToGame(
        gameCode: widget.gameCode,
        playerName: name,
        avatarColor: _selectedColor,
        avatarIcon: _selectedIcon,
      );

      if (result != null && result['game'] != null && result['playerId'] != null) {
        final updatedGame = result['game'] as StudentGameModel;
        final playerId = result['playerId'] as String;
        
        // Show the PIN to the player for future logins
        if (mounted && profile.simplePin != null) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Text('Remember Your PIN!'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Your secret PIN is:'),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.gamePrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.gamePrimary, width: 2),
                    ),
                    child: Text(
                      profile.simplePin!,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        color: AppColors.gamePrimary,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Write it down to join games faster next time!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Got it!'),
                ),
              ],
            ),
          );
        }
        
        // Navigate to game lobby
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => StudentGameLobbyPage(
                game: updatedGame,
                playerId: playerId,
              ),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Could not join game. Please try again.';
          _isJoining = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
        _isJoining = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.gameBackground,
      appBar: AppBar(
        title: Text('Join Game: ${widget.gameCode}'),
        backgroundColor: AppColors.gamePrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isTablet ? 32 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Player setup card
              Container(
                padding: EdgeInsets.all(isTablet ? 24 : 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gamePrimary.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Create Your Player',
                      style: TextStyle(
                        fontSize: isTablet ? 28 : 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.gamePrimary,
                      ),
                    ),
                    
                    SizedBox(height: isTablet ? 24 : 20),
                    
                    // Name input
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      style: TextStyle(fontSize: isTablet ? 20 : 18),
                      decoration: InputDecoration(
                        labelText: 'Your Name',
                        hintText: 'Enter your name',
                        prefixIcon: Icon(Icons.person, size: isTablet ? 28 : 24),
                        filled: true,
                        fillColor: AppColors.lightGray.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: AppColors.gamePrimary, width: 2),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: isTablet ? 24 : 20),
                    
                    // Color selection
                    Text(
                      'Choose Your Color',
                      style: TextStyle(
                        fontSize: isTablet ? 20 : 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _colorOptions.map((colorOption) {
                        final isSelected = _selectedColor == colorOption['color'];
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedColor = colorOption['color'];
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: isTablet ? 70 : 60,
                            height: isTablet ? 70 : 60,
                            decoration: BoxDecoration(
                              color: colorOption['value'],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? Colors.black : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: (colorOption['value'] as Color).withOpacity(0.5),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ] : null,
                            ),
                            child: isSelected 
                                ? Icon(Icons.check, color: Colors.white, size: isTablet ? 32 : 28)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    
                    SizedBox(height: isTablet ? 24 : 20),
                    
                    // Icon selection
                    Text(
                      'Choose Your Icon',
                      style: TextStyle(
                        fontSize: isTablet ? 20 : 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _iconOptions.map((iconOption) {
                        final isSelected = _selectedIcon == iconOption['icon'];
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedIcon = iconOption['icon'];
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: isTablet ? 70 : 60,
                            height: isTablet ? 70 : 60,
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? _getColorValue(_selectedColor)
                                  : Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? Colors.black : Colors.grey,
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                            child: Icon(
                              iconOption['iconData'],
                              size: isTablet ? 32 : 28,
                              color: isSelected ? Colors.white : Colors.grey.shade600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    
                    SizedBox(height: isTablet ? 30 : 24),
                    
                    // Preview
                    Container(
                      padding: EdgeInsets.all(isTablet ? 20 : 16),
                      decoration: BoxDecoration(
                        color: _getColorValue(_selectedColor).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: _getColorValue(_selectedColor)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: isTablet ? 30 : 24,
                            backgroundColor: _getColorValue(_selectedColor),
                            child: Icon(
                              _getIconData(_selectedIcon),
                              color: Colors.white,
                              size: isTablet ? 28 : 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            _nameController.text.isEmpty ? 'Your Name' : _nameController.text,
                            style: TextStyle(
                              fontSize: isTablet ? 20 : 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.error),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    
                    SizedBox(height: isTablet ? 24 : 20),
                    
                    // Join button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isJoining ? null : _joinGame,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: isTablet ? 20 : 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 5,
                        ),
                        child: _isJoining
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                'Join Game!',
                                style: TextStyle(
                                  fontSize: isTablet ? 22 : 20,
                                  fontWeight: FontWeight.bold,
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
    );
  }
}