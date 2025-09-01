import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/student_model.dart';
import '../models/user_model.dart';
import '../models/game_session_model.dart';
import '../services/firestore_service.dart';
import '../services/game_session_service.dart';
import '../services/game_state_service.dart';
import '../services/session_service.dart';
import 'clean_multiplayer_screen.dart';
import 'multiplayer_game_setup_page.dart';
import 'teacher_pronunciation_monitor.dart';

class SimpleStudentSelector extends StatefulWidget {
  final String? teacherId;
  final String? gameCode;

  const SimpleStudentSelector({
    super.key,
    this.teacherId,
    this.gameCode,
  });

  @override
  State<SimpleStudentSelector> createState() => _SimpleStudentSelectorState();
}

class _SimpleStudentSelectorState extends State<SimpleStudentSelector> {
  final List<StudentModel> _selectedStudents = [];
  bool _isLoading = false;

  Future<List<StudentModel>> _getStudents() async {
    try {
      // Get all active students for simple tap-to-play
      return await FirestoreService.getAllActiveStudents();
    } catch (e) {
      print('Error getting students: $e');
      return [];
    }
  }

  void _toggleStudent(StudentModel student) {
    setState(() {
      if (_selectedStudents.any((s) => s.studentId == student.studentId)) {
        _selectedStudents.removeWhere((s) => s.studentId == student.studentId);
      } else {
        if (_selectedStudents.length < 2) { // Max 2 players
          _selectedStudents.add(student);
        } else {
          // Replace the first selected student
          _selectedStudents[0] = student;
        }
      }
    });
  }

  Future<void> _startGame() async {
    if (_selectedStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least one student'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create user models for selected students first
      final users = _selectedStudents.map((student) => 
        UserModel(
          id: student.studentId,
          displayName: student.displayName,
          emailAddress: '${student.studentId}@student.local',
          pin: '0000',
          isAdmin: false,
          createdAt: student.createdAt,
          playerColor: student.playerColor,
        )
      ).toList();

      // Create a proper game session with the students
      final gameSession = await GameSessionService.createGameSession(
        createdBy: widget.teacherId ?? 'teacher',
        gameName: 'Quick Game - ${_selectedStudents.map((s) => s.displayName).join(' vs ')}',
        maxPlayers: _selectedStudents.length,
      );

      // Navigate directly to game with QR overlay
      if (mounted) {
        // Create teacher user
        final teacherUser = UserModel(
          id: widget.teacherId ?? 'teacher',
          displayName: 'Teacher',
          emailAddress: 'teacher@school.com',
          pin: '0000',
          isAdmin: true,
          createdAt: DateTime.now(),
        );
        
        // Convert students to user models
        final expectedPlayers = _selectedStudents.map((student) => 
          UserModel(
            id: student.studentId,
            displayName: student.displayName,
            emailAddress: '${student.studentId}@student.local',
            pin: '0000',
            isAdmin: false,
            createdAt: student.createdAt,
            playerColor: student.playerColor,
          )
        ).toList();
        
        // Save session for auto-restore on app restart
        await SessionService.saveGameSession(gameSession);
        await SessionService.saveUser(teacherUser);
        await SessionService.saveCurrentRoute('/multiplayer-game');
        
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => TeacherPronunciationMonitor(
              user: teacherUser,
              gameSession: gameSession,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error starting game: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not start game. Please try again.'),
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
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(isTablet ? 24 : 16),
                  decoration: BoxDecoration(
                    color: AppColors.gamePrimary,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedStudents.isEmpty 
                              ? 'Who wants to play?' 
                              : _selectedStudents.length == 1
                                  ? 'Pick another friend or tap PLAY!'
                                  : 'Tap PLAY to start!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isTablet ? 32 : 20, // Reduced from 24 to 20 for mobile
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2, // Allow text to wrap to 2 lines if needed
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8), // Fixed spacing instead of Spacer
                      if (_selectedStudents.isNotEmpty)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 20 : 12, // Reduced padding for mobile
                            vertical: isTablet ? 10 : 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_selectedStudents.length} ${_selectedStudents.length == 1 ? 'Player' : 'Players'}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isTablet ? 20 : 14, // Reduced from 16 to 14 for mobile
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Student Grid
                Expanded(
                  child: FutureBuilder<List<StudentModel>>(
                    future: _getStudents(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }
                      
                      final students = snapshot.data ?? [];
                      
                      if (students.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.school,
                                size: isTablet ? 120 : 80,
                                color: AppColors.textDisabled,
                              ),
                              SizedBox(height: 20),
                              Text(
                                'No students found',
                                style: TextStyle(
                                  fontSize: isTablet ? 24 : 18,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                'Ask your teacher to add students',
                                style: TextStyle(
                                  fontSize: isTablet ? 18 : 14,
                                  color: AppColors.textDisabled,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      return GridView.builder(
                        padding: EdgeInsets.all(isTablet ? 32 : 20),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isTablet ? 4 : 3,
                          crossAxisSpacing: isTablet ? 24 : 16,
                          mainAxisSpacing: isTablet ? 24 : 16,
                          childAspectRatio: 1,
                        ),
                        itemCount: students.length,
                        itemBuilder: (context, index) {
                          final student = students[index];
                          final isSelected = _selectedStudents.any(
                            (s) => s.studentId == student.studentId
                          );
                          final selectionIndex = _selectedStudents.indexWhere(
                            (s) => s.studentId == student.studentId
                          );
                          
                          return GestureDetector(
                            onTap: () => _toggleStudent(student),
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? student.playerColor 
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected 
                                      ? student.playerColor 
                                      : Colors.grey.shade300,
                                  width: isSelected ? 4 : 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isSelected 
                                        ? student.playerColor.withOpacity(0.4)
                                        : Colors.black.withOpacity(0.1),
                                    blurRadius: isSelected ? 20 : 8,
                                    offset: Offset(0, isSelected ? 8 : 4),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Avatar
                                      Text(
                                        student.avatarUrl,
                                        style: TextStyle(
                                          fontSize: isTablet ? 60 : 48,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      // Name
                                      Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8),
                                        child: Text(
                                          student.displayName,
                                          style: TextStyle(
                                            fontSize: isTablet ? 18 : 14,
                                            fontWeight: isSelected 
                                                ? FontWeight.bold 
                                                : FontWeight.w500,
                                            color: isSelected 
                                                ? Colors.white 
                                                : AppColors.textPrimary,
                                          ),
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Player number badge
                                  if (isSelected)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        width: isTablet ? 32 : 24,
                                        height: isTablet ? 32 : 24,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.2),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${selectionIndex + 1}',
                                            style: TextStyle(
                                              fontSize: isTablet ? 18 : 14,
                                              fontWeight: FontWeight.bold,
                                              color: student.playerColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            
            // Play button
            if (_selectedStudents.isNotEmpty)
              Positioned(
                bottom: isTablet ? 40 : 24,
                left: 0,
                right: 0,
                child: Center(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _startGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 80 : 60,
                        vertical: isTablet ? 30 : 24,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40),
                      ),
                      elevation: 10,
                      shadowColor: AppColors.success,
                    ),
                    child: _isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_circle_fill,
                                size: isTablet ? 40 : 32,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'PLAY!',
                                style: TextStyle(
                                  fontSize: isTablet ? 32 : 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
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
    );
  }
}