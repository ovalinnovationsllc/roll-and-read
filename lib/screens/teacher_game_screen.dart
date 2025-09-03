import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_colors.dart';
import '../models/user_model.dart';
import '../models/game_session_model.dart';
import 'clean_multiplayer_screen.dart';

class TeacherGameScreen extends StatelessWidget {
  final UserModel user;
  final GameSessionModel gameSession;

  const TeacherGameScreen({
    super.key,
    required this.user,
    required this.gameSession,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gameBackground,
      appBar: AppBar(
        title: Text(
          'Teacher View',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.gamePrimary,
        foregroundColor: Colors.white,
        actions: [],
      ),
      body: CleanMultiplayerScreen(
        user: user,
        gameSession: gameSession,
        isTeacherMode: true,
      ),
    );
  }

}