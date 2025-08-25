import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import 'admin_login_page.dart';
import 'user_login_page.dart';
import 'game_join_page.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final isLargeScreen = screenSize.shortestSide >= 800; // Large tablets/desktops
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.lightGray.withOpacity(0.3),
              AppColors.background,
              AppColors.lightGray.withOpacity(0.3),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Main centered content
              Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // App Icon
                        Container(
                          padding: const EdgeInsets.all(25),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.mediumBlue.withOpacity(0.4),
                                blurRadius: 30,
                                spreadRadius: 10,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/app_icon.png',
                            width: isLargeScreen ? 300 : (isTablet ? 240 : 180),
                            height: isLargeScreen ? 300 : (isTablet ? 240 : 180),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: isLargeScreen ? 300 : (isTablet ? 240 : 180),
                                height: isLargeScreen ? 300 : (isTablet ? 240 : 180),
                                decoration: BoxDecoration(
                                  color: AppColors.gamePrimary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  Icons.school,
                                  size: isLargeScreen ? 150 : (isTablet ? 120 : 90),
                                  color: Colors.white,
                                ),
                              );
                            },
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Title
                        Text(
                          "ROLL AND READ",
                          style: TextStyle(
                            fontSize: isTablet ? 48 : 36,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            letterSpacing: 3,
                            height: 1.2,
                          ),
                        ),
                        
                        const SizedBox(height: 60),
                        
                        // Join Game button
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/game-join');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 60 : 50,
                              vertical: isTablet ? 25 : 20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(35),
                            ),
                            elevation: 8,
                            shadowColor: AppColors.mediumBlue,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_circle_filled,
                                size: isTablet ? 32 : 28,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'JOIN GAME',
                                style: TextStyle(
                                  fontSize: isTablet ? 22 : 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Footer at bottom
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    // Teacher access button
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/teacher-login');
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.admin_panel_settings,
                            size: isTablet ? 20 : 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Teacher Access',
                            style: TextStyle(
                              fontSize: isTablet ? 15 : 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Built by Oval Innovations, LLC',
                      style: TextStyle(
                        fontSize: isTablet ? 12 : 11,
                        color: AppColors.textDisabled,
                        fontStyle: FontStyle.italic,
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