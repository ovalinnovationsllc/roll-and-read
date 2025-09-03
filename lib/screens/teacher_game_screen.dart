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
    final gameCode = gameSession.gameId.length >= 6 
        ? gameSession.gameId.substring(0, 6).toUpperCase() 
        : gameSession.gameId.toUpperCase();
        
    return Scaffold(
      backgroundColor: AppColors.gameBackground,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Game: $gameCode',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 12),
            IconButton(
              icon: Icon(Icons.copy, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: gameCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Game code copied!'),
                    backgroundColor: AppColors.success,
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              tooltip: 'Copy game code',
            ),
            SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Teacher',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.gamePrimary,
        foregroundColor: Colors.white,
        centerTitle: true,
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