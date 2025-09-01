import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/student_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/session_service.dart';

class StudentSelectionForJoin extends StatefulWidget {
  const StudentSelectionForJoin({super.key});

  @override
  State<StudentSelectionForJoin> createState() => _StudentSelectionForJoinState();
}

class _StudentSelectionForJoinState extends State<StudentSelectionForJoin> {
  Future<List<StudentModel>> _getStudents() async {
    try {
      return await FirestoreService.getAllActiveStudents();
    } catch (e) {
      print('Error getting students: $e');
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
        gamesPlayed: student.gamesPlayed,
        gamesWon: 0, // Default for students
        wordsCorrect: student.wordsRead, // Map wordsRead to wordsCorrect
      );
      
      // Save the student user to session so it can be used in the game
      await SessionService.saveUser(studentUser);
      
      // Navigate to student join game page for simple game code entry
      // Student has already been selected, so they just need to enter the game code
      if (mounted) {
        Navigator.pushNamed(context, '/student-join-game');
      }
    } catch (e) {
      print('Error selecting student: $e');
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
                    'Tap your name to join a game',
                    style: TextStyle(
                      fontSize: isTablet ? 24 : 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'After selecting your name, you\'ll enter the game code from your teacher',
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
              child: FutureBuilder<List<StudentModel>>(
                future: _getStudents(),
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
                  
                  return Center(
                    child: Padding(
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
            
            // Footer instruction
            Container(
              padding: EdgeInsets.all(isTablet ? 24 : 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.primary,
                      size: isTablet ? 24 : 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Select your name, then enter the game code your teacher gives you!',
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
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
            color: student.playerColor.withOpacity(0.3),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: student.playerColor.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar with colored background
            Container(
              width: isTablet ? 80 : 60,
              height: isTablet ? 80 : 60,
              decoration: BoxDecoration(
                color: student.playerColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: student.playerColor,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  student.avatarUrl,
                  style: TextStyle(
                    fontSize: isTablet ? 40 : 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                student.displayName,
                style: TextStyle(
                  fontSize: isTablet ? 18 : 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
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