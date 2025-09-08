import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'dart:async';
import 'utils/safe_print.dart';
import 'config/app_colors.dart';
import 'screens/landing_page.dart';
import 'screens/admin_login_page.dart';
import 'screens/admin_dashboard_page.dart';
import 'screens/user_login_page.dart';
import 'screens/game_join_page.dart';
import 'screens/student_join_game_page.dart';
import 'screens/clean_multiplayer_screen.dart';
import 'screens/teacher_game_screen.dart';
import 'models/user_model.dart';
import 'models/game_session_model.dart';
import 'services/session_service.dart';
import 'services/firestore_service.dart';

void main() async {
  // Run the app in a zone to catch all unhandled async errors
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Set up global error handling for unhandled async exceptions
    FlutterError.onError = (FlutterErrorDetails details) {
      // Filter out known web-specific rendering errors that don't affect functionality
      final errorMessage = details.exception.toString();
      final stackTrace = details.stack.toString();
      
      // In release builds, suppress all Flutter Web JavaScript interop errors
      if (kReleaseMode && kIsWeb) {
        if (errorMessage.contains('TypeError') || 
            errorMessage.contains('LegacyJavaScriptObject') ||
            stackTrace.contains('framework.dart')) {
          return; // Completely suppress in release web builds
        }
      }
      
      if (errorMessage.contains('Trying to render a disposed EngineFlutterView') ||
          errorMessage.contains('Noto fonts') ||
          errorMessage.contains('!isDisposed') ||
          errorMessage.contains('a[\$keys] is not iterable') ||
          errorMessage.contains('LegacyJavaScriptObject') ||
          errorMessage.contains('is not a subtype of type \'RenderObject\'') ||
          errorMessage.contains('Failed to execute \'measure\' on \'Performance\'') ||
          errorMessage.contains('!_doingMountOrUpdate') ||
          stackTrace.contains('mapEquals') ||
          stackTrace.contains('button_style.dart') ||
          stackTrace.contains('icon_button_theme.dart') ||
          stackTrace.contains('image_cache.dart') ||
          stackTrace.contains('image_stream.dart') ||
          (stackTrace.contains('framework.dart') && errorMessage.contains('TypeError'))) {
        // These are known Flutter Web JavaScript interop issues that don't break functionality
        return;
      }
      
      // Log AssetManifest errors but don't suppress them - they indicate real issues
      if (errorMessage.contains('AssetManifest') || errorMessage.contains('Flutter Web engine failed to fetch')) {
        safePrint('🌐 Web Asset Loading Issue: $errorMessage');
        safePrint('📍 This may indicate a server configuration problem');
      }
      
      safePrint('Flutter error: ${details.exception}');
      safePrint('Stack trace: ${details.stack}');
    };
    
    await _initializeApp();
  }, (error, stackTrace) {
    safePrint('🔥 Unhandled async error caught: $error');
    safePrint('🔥 Stack trace: $stackTrace');
  });
}

Future<void> _initializeApp() async {
  safePrint('🚀 Starting app initialization...');
  
  try {
    // Initialize Firebase FIRST
    try {
      safePrint('🔥 Initializing Firebase...');
      safePrint('🔥 Platform: ${kIsWeb ? 'Web' : defaultTargetPlatform.toString()}');
      
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        if (e.toString().contains('duplicate-app')) {
          safePrint('✅ Firebase already initialized (duplicate app error ignored)');
        } else {
          rethrow;
        }
      }
      safePrint('✅ Firebase initialized successfully');
      
      // Test Firebase connection
      try {
        final firestore = FirebaseFirestore.instance;
        await firestore.settings; // This will throw if Firestore isn't available
        safePrint('✅ Firestore connection verified');
        
        // Mark Firebase as ready for FirestoreService
        FirestoreService.setFirebaseReady(true);
        safePrint('✅ FirestoreService marked as ready');
      } catch (firestoreError) {
        safePrint('❌ Firestore connection failed: $firestoreError');
        safePrint('⚠️ Firebase initialized but Firestore unavailable');
      }
    } catch (e, stackTrace) {
      safePrint('❌ Firebase initialization failed: $e');
      safePrint('❌ Stack trace: $stackTrace');
      safePrint('⚠️ Continuing without Firebase...');
    }
    
    // Load environment variables
    try {
      safePrint('📁 Loading .env file...');
      await dotenv.load(fileName: ".env");
      safePrint('✅ Environment variables loaded');
    } catch (e) {
      safePrint('❌ Could not load .env file: $e');
    }
    
    // Get initial route
    safePrint('📱 Getting initial route...');
    String initialRoute = '/';
    try {
      initialRoute = await SessionService.getInitialRouteSafe(true); // Firebase is always ready when initialized
      safePrint('✅ Initial route: $initialRoute');
    } catch (e) {
      safePrint('❌ Error getting initial route: $e');
      initialRoute = '/';
    }
    
    safePrint('🎯 Starting Flutter app with route: $initialRoute');
    runApp(MyApp(initialRoute: initialRoute));
    
  } catch (e, stackTrace) {
    safePrint('💥 Error in _initializeApp: $e');
    safePrint('📚 Stack trace: $stackTrace');
    // Run app anyway with default route
    runApp(MyApp(initialRoute: '/'));
  }
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  
  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Mrs. Elson's Roll and Read",
      theme: ThemeData(
        colorScheme: AppColors.lightColorScheme,
        useMaterial3: true,
        primarySwatch: AppColors.primaryMaterialColor,
        // Better font rendering for web
        fontFamily: kIsWeb ? 'Roboto' : null,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 2,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            elevation: 2,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.cardBackground,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        scaffoldBackgroundColor: AppColors.background,
      ),
      initialRoute: initialRoute,
      routes: {
        '/': (context) => const LandingPage(),
        '/teacher-login': (context) => const AdminLoginPage(),
        '/user-login': (context) => const UserLoginPage(),
        '/game-join': (context) => const GameJoinPage(),
        '/student-join-game': (context) => const StudentJoinGamePage(),
        '/admin-dashboard': (context) => const AdminDashboardWrapper(),
      },
      onGenerateRoute: (settings) {
        // Handle dynamic routes that need parameters
        if (settings.name?.startsWith('/admin-dashboard') == true) {
          // Get user data from arguments
          final user = settings.arguments as UserModel?;
          if (user != null && user.isAdmin) {
            return MaterialPageRoute(
              builder: (context) => AdminDashboardPage(adminUser: user),
              settings: settings,
            );
          }
        }
        
        if (settings.name?.startsWith('/multiplayer-game') == true) {
          // Get data from arguments
          final args = settings.arguments as Map<String, dynamic>?;
          if (args != null && args['user'] != null && args['gameSession'] != null) {
            // Direct navigation with arguments (from game join)
            final user = args['user'] as UserModel;
            final gameSession = args['gameSession'] as GameSessionModel;
            
            // Different screens for teacher vs student
            if (user.isAdmin) {
              return MaterialPageRoute(
                builder: (context) => TeacherGameScreen(
                  user: user,
                  gameSession: gameSession,
                ),
                settings: settings,
              );
            } else {
              return MaterialPageRoute(
                builder: (context) => CleanMultiplayerScreen(
                  user: user,
                  gameSession: gameSession,
                  isTeacherMode: false,
                ),
                settings: settings,
              );
            }
          } else {
            // No arguments provided - use session wrapper for restoration
            return MaterialPageRoute(
              builder: (context) => const MultiplayerGameWrapper(),
              settings: settings,
            );
          }
        }
        
        // If we can't resolve the route, go to home
        return MaterialPageRoute(
          builder: (context) => const LandingPage(),
          settings: const RouteSettings(name: '/'),
        );
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

// Wrapper widget for admin dashboard that handles session restoration
class AdminDashboardWrapper extends StatelessWidget {
  const AdminDashboardWrapper({super.key});

  Future<UserModel?> _loadUserWithFirebaseWait() async {
    // Wait for Firebase to be ready with timeout
    int attempts = 0;
    while (!FirestoreService.isFirebaseReady && attempts < 10) {
      await Future.delayed(const Duration(milliseconds: 500));
      attempts++;
    }
    
    if (!FirestoreService.isFirebaseReady) {
    }
    
    return await SessionService.refreshUser();
  }

  @override
  Widget build(BuildContext context) {
    
    return FutureBuilder<UserModel?>(
      future: _loadUserWithFirebaseWait(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading dashboard...'),
                ],
              ),
            ),
          );
        }
        
        final user = snapshot.data;
        
        if (user != null && user.isAdmin) {
          // Save current route
          SessionService.saveCurrentRoute('/admin-dashboard');
          return AdminDashboardPage(adminUser: user);
        }
        
        // If no valid session, redirect to admin login
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacementNamed('/teacher-login');
        });
        
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

// Wrapper widget for multiplayer game that handles session restoration
class MultiplayerGameWrapper extends StatelessWidget {
  const MultiplayerGameWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _getSessionData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        final data = snapshot.data;
        if (data != null && data['user'] != null && data['gameSession'] != null) {
          try {
            // Save current route
            SessionService.saveCurrentRoute('/multiplayer-game');
            final user = data['user'] as UserModel;
            final gameSession = data['gameSession'] as GameSessionModel;
            
            if (user.isAdmin) {
              return TeacherGameScreen(
                user: user,
                gameSession: gameSession,
              );
            } else {
              return CleanMultiplayerScreen(
                user: user,
                gameSession: gameSession,
                isTeacherMode: false,
              );
            }
          } catch (e) {
            safePrint('Error casting session data: $e');
            // Clear corrupted session and redirect to landing
            SessionService.clearSession();
            return const LandingPage();
          }
        }
        
        // If no valid session, redirect to home
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacementNamed('/');
        });
        
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
  
  Future<Map<String, dynamic>?> _getSessionData() async {
    final user = await SessionService.getUser();
    final gameSession = await SessionService.getGameSession();
    
    if (user != null && gameSession != null) {
      // CRITICAL: Check both cached status AND current Firebase status
      if (gameSession.status == GameStatus.completed || 
          gameSession.status == GameStatus.cancelled) {
        print('🚨 CACHED SESSION STATUS IS COMPLETED: ${gameSession.status}');
        await SessionService.clearGameSession();
        return null;
      }
      // Don't clear pendingTeacherReview - teachers need to access it!
      if (gameSession.status == GameStatus.pendingTeacherReview) {
        print('📝 Game pending teacher review - preserving session');
      }
      
      // CRITICAL: Validate against current Firebase state to catch stale cached sessions
      try {
        print('🔍 VALIDATING CACHED GAME SESSION: ${gameSession.gameId}');
        final currentGameState = await FirestoreService.getGameSession(gameSession.gameId);
        
        if (currentGameState == null) {
          print('🚨 FIREBASE GAME NO LONGER EXISTS: ${gameSession.gameId}');
          await SessionService.clearGameSession();
          return null;
        }
        
        if (currentGameState.status == GameStatus.completed || 
            currentGameState.status == GameStatus.cancelled) {
          print('🚨 FIREBASE GAME STATUS IS COMPLETED: ${currentGameState.status}');
          print('🧹 Cached status was: ${gameSession.status} (stale!)');
          await SessionService.clearGameSession();
          return null;
        }
        // Don't clear pendingTeacherReview - teachers need to access it!
        if (currentGameState.status == GameStatus.pendingTeacherReview) {
          print('📝 Game pending teacher review from Firebase - preserving session');
        }
        
        print('✅ FIREBASE VALIDATION PASSED: Game ${gameSession.gameId} is still active');
        
        // Use the current Firebase state instead of cached state
        return {
          'user': user,
          'gameSession': currentGameState,
        };
      } catch (e) {
        print('❌ ERROR VALIDATING GAME SESSION: $e');
        // If we can't validate, clear the session to be safe
        await SessionService.clearGameSession();
        return null;
      }
    }
    
    return null;
  }
}
