import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../widgets/pencil_letter.dart';
import 'roll_and_read_game.dart';

class TeacherNameScreen extends StatelessWidget {
  final String prefix;
  final String name;
  final Color backgroundColor;

  const TeacherNameScreen({
    super.key,
    this.prefix = "Mrs.",
    this.name = "ELSON",
    this.backgroundColor = const Color(0xFFF5F5F5),
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Calculate letter size based on screen width and word length
    final letterSize = isTablet 
        ? (screenWidth * 0.8) / (name.length + 1)
        : (screenWidth * 0.9) / (name.length + 1);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: AppColors.lightGray.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Paper texture effect
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.white,
                        AppColors.lightGray.withOpacity(0.1),
                        AppColors.white,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
                // Main content
                Center(
                  child: PencilWordDisplay(
                    prefix: prefix,
                    word: name,
                    letterSize: letterSize.clamp(80.0, 200.0),
                    spacing: letterSize.clamp(80.0, 200.0) * 0.75,
                  ),
                ),
                // Navigation to game
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RollAndReadGame(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gamePrimary,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'Start Game',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}