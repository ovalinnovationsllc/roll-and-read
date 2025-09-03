import 'package:flutter/material.dart';
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
              
              // Footer at bottom - hidden teacher access
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    // Hidden teacher access via long press on company name
                    GestureDetector(
                      onLongPress: () {
                        // Show teacher access options after long press
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
                      child: Text(
                        'Built by Oval Innovations, LLC',
                        style: TextStyle(
                          fontSize: isTablet ? 12 : 11,
                          color: AppColors.textDisabled,
                          fontStyle: FontStyle.italic,
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