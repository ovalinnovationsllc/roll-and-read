import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import '../config/app_colors.dart';
import 'game_code_entry_page.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final isLargeScreen = screenSize.shortestSide >= 800; // Large tablets/desktops
    
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
                        // App Icon with long press for teacher access
                        GestureDetector(
                          onLongPress: () {
                            // Show teacher access options after long press on Mrs. Elson icon
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.white,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                              ),
                              builder: (context) => SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Teacher & Admin Access',
                                        style: TextStyle(
                                          fontSize: isTablet ? 20 : 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      
                                      // Teacher Dashboard
                                      ListTile(
                                        leading: const Icon(Icons.admin_panel_settings, color: AppColors.adminPrimary),
                                        title: const Text('Teacher Dashboard'),
                                        subtitle: const Text('Manage students and games'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          Navigator.pushNamed(context, '/teacher-login');
                                        },
                                      ),
                                      
                                      const SizedBox(height: 10),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(25),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.mediumBlue.withOpacity(0.4),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/mrs_elson_full.png',
                              width: isLargeScreen ? 400 : (isTablet ? 320 : 240),
                              height: isLargeScreen ? 400 : (isTablet ? 320 : 240),
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: isLargeScreen ? 400 : (isTablet ? 320 : 240),
                                  height: isLargeScreen ? 400 : (isTablet ? 320 : 240),
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
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Title
                        Text(
                          "Roll and Read",
                          style: GoogleFonts.bubblegumSans(
                            fontSize: isTablet ? 60 : 44,
                            fontWeight: FontWeight.w400,
                            color: AppColors.primary,
                            letterSpacing: 2,
                            height: 1.2,
                          ),
                        ),
                        
                        const SizedBox(height: 60),
                        
                        
                        // Join Game button for students
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GameCodeEntryPage(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 60 : 45,
                              vertical: isTablet ? 20 : 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            elevation: 8,
                            shadowColor: AppColors.primary,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/dice_blue.png',
                                width: isTablet ? 28 : 22,
                                height: isTablet ? 28 : 22,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.casino,
                                    size: isTablet ? 28 : 22,
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'JOIN GAME',
                                style: TextStyle(
                                  fontSize: isTablet ? 20 : 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Debug: Resume Game button - REMOVED
                        /* OutlinedButton(
                          onPressed: () async {
                            try {
                              final user = await SessionService.getUser();
                              final gameSession = await SessionService.getGameSession();
                              final savedRoute = await SessionService.getCurrentRoute();
                              
                              safePrint('🐛 DEBUG - Detailed session check:');
                              safePrint('🐛 User: ${user?.displayName} (admin: ${user?.isAdmin}, id: ${user?.id})');
                              safePrint('🐛 Game: ${gameSession?.gameId} (status: ${gameSession?.status})');
                              safePrint('🐛 Game players: ${gameSession?.players.map((p) => '${p.displayName}(${p.userId})').toList()}');
                              safePrint('🐛 Game created: ${gameSession?.createdAt}');
                              safePrint('🐛 Game ended: ${gameSession?.endedAt}');
                              safePrint('🐛 Route: $savedRoute');
                              
                              // Show this info to user too
                              final debugInfo = '''
User: ${user?.displayName ?? 'null'} (${user?.isAdmin == true ? 'Teacher' : 'Student'})
Game: ${gameSession?.gameId ?? 'null'}
Status: ${gameSession?.status ?? 'null'}
Route: ${savedRoute ?? 'null'}
Players: ${gameSession?.players.length ?? 0}
Created: ${gameSession?.createdAt ?? 'null'}
Ended: ${gameSession?.endedAt ?? 'null'}
Winner: ${gameSession?.winnerId ?? 'none'}
                              ''';
                              
                              if (user != null && gameSession != null && 
                                  (gameSession.status.toString().contains('inProgress') || 
                                   gameSession.status.toString().contains('waitingForPlayers'))) {
                                safePrint('🐛 Attempting to resume game...');
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CleanMultiplayerScreen(
                                      gameSession: gameSession,
                                      user: user,
                                      isTeacherMode: user.isAdmin,
                                    ),
                                  ),
                                );
                              } else {
                                // Show debug info to user with force resume option
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Debug: Session Data'),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(debugInfo),
                                          if (user != null && gameSession != null)
                                            const SizedBox(height: 16),
                                          if (user != null && gameSession != null)
                                            Text(
                                              'Game status is "${gameSession.status}". Force resume anyway?',
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      if (user != null && gameSession != null)
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            safePrint('🐛 FORCE resuming game despite status');
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => CleanMultiplayerScreen(
                                                  gameSession: gameSession,
                                                  user: user,
                                                  isTeacherMode: user.isAdmin,
                                                            ),
                                              ),
                                            );
                                          },
                                          child: const Text('FORCE RESUME'),
                                        ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            } catch (e) {
                              safePrint('🐛 Error checking session: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.mediumBlue),
                            foregroundColor: AppColors.mediumBlue,
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 40 : 30,
                              vertical: isTablet ? 15 : 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            'RESUME GAME',
                            style: TextStyle(
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ), */
                      ],
                    ),
                  ),
                ),
              ),
              
              // Footer at bottom with company link
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    // Company name as hyperlink
                    GestureDetector(
                      onTap: () async {
                        final url = 'https://www.ovalinnovationsllc.com';
                        try {
                          final uri = Uri.parse(url);
                          // Use launchUrl with webOnlyWindowName for web compatibility
                          await launchUrl(
                            uri, 
                            mode: LaunchMode.externalApplication,
                            webOnlyWindowName: '_blank',
                          );
                        } catch (e) {
                          // Silently fail if URL launcher is not available
                          debugPrint('Could not launch URL: $e');
                        }
                      },
                      child: Text(
                        'Built by Oval Innovations, LLC',
                        style: TextStyle(
                          fontSize: isTablet ? 12 : 11,
                          color: AppColors.primary.withOpacity(0.7),
                          fontStyle: FontStyle.italic,
                          decoration: TextDecoration.underline,
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

// Custom painter for rainbow-curved text
class RainbowTextPainter extends CustomPainter {
  final String text;
  final TextStyle textStyle;

  RainbowTextPainter({
    required this.text,
    required this.textStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height * 1.5; // Move center down for upward arc
    final double radius = size.width * 0.5; // Larger radius for gentler curve
    
    // Remove spaces from text for better distribution
    final String displayText = text.replaceAll(' ', '');
    final int charCount = displayText.length;
    
    // Wider arc for better spacing
    final double totalAngle = 1.8; // About 103 degrees for better spread
    final double startAngle = -totalAngle / 2 - 1.57; // Center the arc
    
    for (int i = 0; i < charCount; i++) {
      // Calculate angle for this character with even distribution
      final double charAngle = startAngle + (i / (charCount - 1)) * totalAngle;
      
      // Calculate position on the arc
      final double x = centerX + radius * cos(charAngle);
      final double y = centerY + radius * sin(charAngle);
      
      // Create text painter for individual character
      final textPainter = TextPainter(
        text: TextSpan(
          text: displayText[i],
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      
      // Save canvas state
      canvas.save();
      
      // Translate to character position
      canvas.translate(x, y);
      
      // Rotate the character to follow the curve
      canvas.rotate(charAngle + 1.57); // Add 90 degrees to make text face outward
      
      // Draw the character centered at its position
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      
      // Restore canvas state
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}