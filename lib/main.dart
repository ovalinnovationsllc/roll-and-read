import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'utils/safe_print.dart';
import 'config/app_config.dart';
import 'config/app_colors.dart';
import 'screens/landing_page.dart';
import 'screens/admin_login_page.dart';
import 'screens/admin_dashboard_page.dart';
import 'screens/user_login_page.dart';
import 'screens/game_join_page.dart';
import 'screens/multiplayer_game_page.dart';
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
      if (errorMessage.contains('Trying to render a disposed EngineFlutterView') ||
          errorMessage.contains('Noto fonts') ||
          errorMessage.contains('!isDisposed') ||
          errorMessage.contains('Unable to load asset: "AssetManifest.bin.json"') ||
          errorMessage.contains('Flutter Web engine failed to fetch')) {
        // These are known Flutter Web issues that don't break functionality
        return;
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
    // Load environment variables
    try {
      safePrint('📁 Loading .env file...');
      await dotenv.load(fileName: ".env");
      safePrint('✅ Environment variables loaded');
    } catch (e) {
      safePrint('❌ Could not load .env file: $e');
    }
    
    // Initialize Firebase with better error handling
    try {
      safePrint('🔥 Initializing Firebase...');
      
      // Use platform-specific configuration
      // iOS: Uses GoogleService-Info.plist
      // Android: Uses google-services.json
      // Web: Uses custom options from environment
      if (defaultTargetPlatform == TargetPlatform.iOS || 
          defaultTargetPlatform == TargetPlatform.android) {
        // Use default Firebase configuration files
        await Firebase.initializeApp();
      } else {
        // Web platform - use custom options from environment
        if (AppConfig.firebaseApiKey.isEmpty || 
            AppConfig.firebaseProjectId.isEmpty || 
            AppConfig.firebaseAppId.isEmpty) {
          throw Exception('Missing Firebase configuration for web platform');
        }
        
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: AppConfig.firebaseApiKey,
            authDomain: AppConfig.firebaseAuthDomain,
            projectId: AppConfig.firebaseProjectId,
            storageBucket: AppConfig.firebaseStorageBucket,
            messagingSenderId: AppConfig.firebaseMessagingSenderId,
            appId: AppConfig.firebaseAppId,
          ),
        );
      }
      
      // Set Firebase as ready for Firestore operations
      FirestoreService.setFirebaseReady(true);
      safePrint('✅ Firebase initialized successfully');
      
    } catch (e) {
      safePrint('❌ Firebase initialization failed: $e');
      FirestoreService.setFirebaseReady(false);
    }
    
    // Get Firebase-safe initial route
    safePrint('📱 Getting initial route...');
    String initialRoute = '/';
    try {
      // Use Firebase-safe route determination
      final isFirebaseReady = FirestoreService.isFirebaseReady;
      safePrint('🔥 Firebase ready status: $isFirebaseReady');
      initialRoute = await SessionService.getInitialRouteSafe(isFirebaseReady);
      safePrint('✅ Initial route (Firebase ready: $isFirebaseReady): $initialRoute');
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
            return MaterialPageRoute(
              builder: (context) => MultiplayerGamePage(
                user: args['user'] as UserModel,
                gameSession: args['gameSession'] as GameSessionModel,
              ),
              settings: settings,
            );
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

  @override
  Widget build(BuildContext context) {
    // Check if Firebase is ready before attempting to load user data
    if (!FirestoreService.isFirebaseReady) {
      safePrint('AdminDashboardWrapper - Firebase not ready, redirecting to home');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return FutureBuilder<UserModel?>(
      future: SessionService.getUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        final user = snapshot.data;
        print('AdminDashboardWrapper - User loaded: ${user?.displayName}, isAdmin: ${user?.isAdmin}');
        
        if (user != null && user.isAdmin) {
          // Save current route
          SessionService.saveCurrentRoute('/admin-dashboard');
          return AdminDashboardPage(adminUser: user);
        }
        
        // If no valid session, redirect to admin login
        print('AdminDashboardWrapper - No valid admin session, redirecting to login');
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
            return MultiplayerGamePage(
              user: data['user'] as UserModel,
              gameSession: data['gameSession'] as GameSessionModel,
            );
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
    // Check if Firebase is ready before attempting to load session data
    if (!FirestoreService.isFirebaseReady) {
      safePrint('MultiplayerGameWrapper - Firebase not ready, cannot load session');
      return null;
    }
    
    final user = await SessionService.getUser();
    final gameSession = await SessionService.getGameSession();
    
    if (user != null && gameSession != null) {
      return {
        'user': user,
        'gameSession': gameSession,
      };
    }
    
    return null;
  }
}
