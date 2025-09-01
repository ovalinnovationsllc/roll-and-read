import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/student_model.dart';
import '../models/game_session_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/game_session_service.dart';
import 'multiplayer_game_setup_page.dart';

class SimpleGameJoinPage extends StatefulWidget {
  const SimpleGameJoinPage({super.key});

  @override
  State<SimpleGameJoinPage> createState() => _SimpleGameJoinPageState();
}

class _SimpleGameJoinPageState extends State<SimpleGameJoinPage> {
  final _gameCodeController = TextEditingController();
  bool _isLoading = false;
  List<StudentModel> _students = [];
  bool _studentsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      final students = await FirestoreService.getAllActiveStudents();
      setState(() {
        _students = students;
        _studentsLoaded = true;
      });
    } catch (e) {
      print('Error loading students: $e');
      setState(() {
        _studentsLoaded = true;
      });
    }
  }

  Future<void> _joinGame() async {
    final gameCode = _gameCodeController.text.trim().toUpperCase();
    if (gameCode.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-character game code'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Find the game session by partial ID match
      final gameSession = await GameSessionService.findGameByPartialId(gameCode);
      
      if (gameSession == null) {
        throw Exception('Game not found. Check the code and try again.');
      }

      if (mounted) {
        // Navigate to the multiplayer setup page where players can select themselves
        // For now, we'll show all students and let them pick. In a real implementation,
        // the game session would store which specific students were selected
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MultiplayerGameSetupPage(
              selectedStudents: _students.take(2).toList(), // Show first 2 students as example
              gameSession: gameSession,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining game: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;

    return Scaffold(
      backgroundColor: AppColors.gameBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(isTablet ? 24 : 20),
                decoration: BoxDecoration(
                  color: AppColors.gamePrimary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.group_add,
                      size: isTablet ? 60 : 50,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Join a Game',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isTablet ? 32 : 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter the game code your friend shared',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: isTablet ? 18 : 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Game Code Input
              Container(
                padding: EdgeInsets.all(isTablet ? 24 : 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Game Code:',
                      style: TextStyle(
                        fontSize: isTablet ? 20 : 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _gameCodeController,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isTablet ? 28 : 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        hintText: 'ABC123',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: isTablet ? 28 : 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: AppColors.primary, width: 3),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 20 : 16,
                          vertical: isTablet ? 16 : 12,
                        ),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 6,
                      onChanged: (value) {
                        if (value.length == 6) {
                          // Auto-join when 6 characters entered
                          _joinGame();
                        }
                      },
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Join Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _joinGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: isTablet ? 20 : 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40),
                    ),
                    elevation: 10,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.login,
                              size: isTablet ? 32 : 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'JOIN GAME!',
                              style: TextStyle(
                                fontSize: isTablet ? 24 : 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Back Button
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Back to Home',
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _gameCodeController.dispose();
    super.dispose();
  }
}