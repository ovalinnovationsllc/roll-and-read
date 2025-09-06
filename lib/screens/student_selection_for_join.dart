import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../widgets/player_avatar.dart';
import '../models/student_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/session_service.dart';
import '../services/game_session_service.dart';
import 'clean_multiplayer_screen.dart';

class StudentSelectionForJoin extends StatefulWidget {
  final String? gameCode;
  
  const StudentSelectionForJoin({super.key, this.gameCode});

  @override
  State<StudentSelectionForJoin> createState() => _StudentSelectionForJoinState();
}

class _StudentSelectionForJoinState extends State<StudentSelectionForJoin> {
  late Future<List<StudentModel>> _studentsFuture;
  
  @override
  void initState() {
    super.initState();
    // Initialize the future once to prevent multiple loads
    _studentsFuture = _getStudents();
  }
  
  Future<List<StudentModel>> _getStudents() async {
    try {
      final allStudents = await FirestoreService.getAllActiveStudents();
      
      // If no game code provided, show all students (backward compatibility)
      if (widget.gameCode == null) {
        return allStudents;
      }
      
      // Get the game session to find out which teacher created it
      final gameSession = await GameSessionService.getGameSession(widget.gameCode!);
      if (gameSession == null) {
        // Game not found, show all students
        return allStudents;
      }
      
      // Filter students to only show those belonging to the teacher who created the game
      final teachersStudents = allStudents
          .where((student) => student.teacherId == gameSession.createdBy)
          .toList();
      
      return teachersStudents;
    } catch (e) {
      return [];
    }
  }

  void _selectStudent(StudentModel student) async {
    try {
      // Convert student to user model and save to session
      final studentUser = UserModel(
        id: student.studentId,
        displayName: student.displayName,
        emailAddress: '${student.studentId}@student.local', // Dummy email for student
        pin: '0000', // Default pin for students
        playerColor: student.playerColor,
        avatarUrl: student.avatarUrl,
        isAdmin: false,
        createdAt: student.createdAt,
        teacherId: student.teacherId, // Preserve the teacher ID
        gamesPlayed: student.gamesPlayed,
        gamesWon: 0, // Default for students
        wordsRead: student.wordsRead,
      );
      
      // Save the student user to session so it can be used in the game
      await SessionService.saveUser(studentUser);
      
      if (mounted) {
        if (widget.gameCode != null) {
          // We already have a game code, try to join directly
          await _joinGameDirectly(studentUser, widget.gameCode!);
        } else {
          // Navigate to student join game page for game code entry
          Navigator.pushNamed(context, '/student-join-game');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting student: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _joinGameDirectly(UserModel user, String gameCode) async {
    try {
      // Get the game session
      final game = await GameSessionService.getGameSession(gameCode);
      if (game == null) {
        throw Exception('Game not found.');
      }

      if (game.players.length >= game.maxPlayers) {
        throw Exception('This game is full.');
      }

      // Join the game
      final updatedGame = await GameSessionService.joinGameSession(
        gameId: gameCode,
        user: user,
      );

      if (updatedGame == null) {
        throw Exception('Failed to join game.');
      }

      // Save the updated game session
      await SessionService.saveGameSession(updatedGame);

      // Navigate to the multiplayer game
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CleanMultiplayerScreen(
              user: user,
              gameSession: updatedGame,
              isTeacherMode: false,
            ),
          ),
        );
      }
    } catch (e) {
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
      appBar: AppBar(
        title: const Text('Who are you?'),
        backgroundColor: AppColors.gamePrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header instruction
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isTablet ? 32 : 20),
              child: Column(
                children: [
                  Icon(
                    Icons.person_search,
                    size: isTablet ? 80 : 60,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Who are you?',
                    style: TextStyle(
                      fontSize: isTablet ? 24 : 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap your name to join the game',
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            // Student Grid
            Expanded(
              child: Center(
                child: FutureBuilder<List<StudentModel>>(
                future: _studentsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppColors.primary),
                          const SizedBox(height: 16),
                          Text(
                            'Loading students...',
                            style: TextStyle(
                              fontSize: isTablet ? 18 : 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  final students = snapshot.data ?? [];
                  
                  if (students.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.school_outlined,
                            size: isTablet ? 120 : 80,
                            color: AppColors.textDisabled,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No students found',
                            style: TextStyle(
                              fontSize: isTablet ? 24 : 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ask your teacher to add student profiles first',
                            style: TextStyle(
                              fontSize: isTablet ? 16 : 14,
                              color: AppColors.textDisabled,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return SingleChildScrollView(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: isTablet ? 800 : 600,
                      ),
                      padding: EdgeInsets.all(isTablet ? 32 : 20),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: isTablet ? 24 : 16,
                        runSpacing: isTablet ? 24 : 16,
                        children: students.map((student) {
                          return SizedBox(
                            width: isTablet ? 160 : 120,
                            height: isTablet ? 160 : 120,
                            child: _buildStudentCard(student, isTablet),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(StudentModel student, bool isTablet) {
    return GestureDetector(
      onTap: () => _selectStudent(student),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: student.playerColor.withOpacity(0.4),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: student.playerColor.withOpacity(0.25),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Enhanced Player Avatar
            PlayerAvatar(
              displayName: student.displayName,
              avatarUrl: student.avatarUrl,
              playerColor: student.playerColor,
              size: isTablet ? 80 : 60,
              showName: false, // We'll show the name separately below for better layout
            ),
            
            const SizedBox(height: 8),
            
            // Enhanced name display with color accent
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: student.playerColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: student.playerColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                student.displayName,
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.bold,
                  color: student.playerColor,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}