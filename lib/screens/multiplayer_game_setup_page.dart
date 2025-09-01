import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_colors.dart';
import '../models/student_model.dart';
import '../models/game_session_model.dart';
import '../models/user_model.dart';
import '../services/game_session_service.dart';
import 'clean_multiplayer_screen.dart';

class MultiplayerGameSetupPage extends StatefulWidget {
  final List<StudentModel> selectedStudents;
  final GameSessionModel gameSession;

  const MultiplayerGameSetupPage({
    super.key,
    required this.selectedStudents,
    required this.gameSession,
  });

  @override
  State<MultiplayerGameSetupPage> createState() => _MultiplayerGameSetupPageState();
}

class _MultiplayerGameSetupPageState extends State<MultiplayerGameSetupPage> {
  int _selectedPlayerIndex = -1;
  bool _isJoining = false;

  void _selectPlayer(int index) {
    setState(() {
      _selectedPlayerIndex = index;
    });
  }

  Future<void> _joinGame() async {
    if (_selectedPlayerIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please tap your name to join the game'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isJoining = true;
    });

    try {
      final selectedStudent = widget.selectedStudents[_selectedPlayerIndex];
      
      // Create user model from student
      final user = UserModel(
        id: selectedStudent.studentId,
        displayName: selectedStudent.displayName,
        emailAddress: '${selectedStudent.studentId}@student.local',
        pin: '0000',
        isAdmin: false,
        createdAt: selectedStudent.createdAt,
        playerColor: selectedStudent.playerColor,
        avatarUrl: selectedStudent.avatarUrl,
      );

      // Join the existing game session
      await GameSessionService.joinGameSession(
        gameId: widget.gameSession.gameId,
        user: user,
      );

      if (mounted) {
        // Navigate to the multiplayer game
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => CleanMultiplayerScreen(
              user: user,
              gameSession: widget.gameSession,
              isTeacherMode: false,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isJoining = false;
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

  void _copyGameCode() {
    Clipboard.setData(ClipboardData(text: widget.gameSession.gameId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Game code copied to clipboard!'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );
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
            children: [
              // Header
              Container(
                width: double.infinity,
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
                    Text(
                      '2-Player Game Ready!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isTablet ? 28 : 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Players: ${widget.selectedStudents[0].displayName} vs ${widget.selectedStudents[1].displayName}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: isTablet ? 18 : 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Game Code Display
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isTablet ? 24 : 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary, width: 2),
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
                      Icons.qr_code,
                      size: isTablet ? 60 : 50,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Game Code:',
                      style: TextStyle(
                        fontSize: isTablet ? 20 : 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 24 : 20,
                        vertical: isTablet ? 12 : 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lightGray,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.gameSession.gameId.substring(0, 6).toUpperCase(),
                        style: TextStyle(
                          fontSize: isTablet ? 32 : 28,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: AppColors.textPrimary,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _copyGameCode,
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy Code'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Instructions
              Text(
                'Each player needs their own device:',
                style: TextStyle(
                  fontSize: isTablet ? 20 : 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Player Selection
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Tap your name to join:',
                      style: TextStyle(
                        fontSize: isTablet ? 18 : 16,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    
                    // Player Cards
                    ...widget.selectedStudents.asMap().entries.map((entry) {
                      final index = entry.key;
                      final student = entry.value;
                      final isSelected = _selectedPlayerIndex == index;
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: GestureDetector(
                          onTap: () => _selectPlayer(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: double.infinity,
                            padding: EdgeInsets.all(isTablet ? 20 : 16),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? student.playerColor 
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: student.playerColor,
                                width: isSelected ? 4 : 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isSelected ? student.playerColor : Colors.black)
                                      .withOpacity(0.2),
                                  blurRadius: isSelected ? 20 : 8,
                                  offset: Offset(0, isSelected ? 8 : 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Text(
                                  student.avatarUrl,
                                  style: TextStyle(fontSize: isTablet ? 40 : 32),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    student.displayName,
                                    style: TextStyle(
                                      fontSize: isTablet ? 24 : 20,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected 
                                          ? Colors.white 
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: isTablet ? 32 : 24,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    
                    const SizedBox(height: 30),
                    
                    // Join Game Button
                    if (_selectedPlayerIndex != -1)
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
                              borderRadius: BorderRadius.circular(40),
                            ),
                            elevation: 10,
                          ),
                          child: _isJoining
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.play_circle_fill,
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