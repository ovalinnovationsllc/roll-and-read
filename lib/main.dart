import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/landing_page.dart';
import 'screens/admin_login_page.dart';
import 'screens/admin_dashboard_page.dart';
import 'screens/user_login_page.dart';
import 'screens/game_join_page.dart';
import 'screens/multiplayer_game_page.dart';
import 'models/user_model.dart';
import 'models/game_session_model.dart';
import 'services/session_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables (with error handling for web)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // On web, .env file might not be accessible, use fallback
    print('Could not load .env file: $e');
  }
  
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyAJ-zI4UrZxL2Z6qvt4qfEsDPnmgrm5iuI",
      authDomain: "roll-and-read.firebaseapp.com",
      projectId: "roll-and-read",
      storageBucket: "roll-and-read.firebasestorage.app",
      messagingSenderId: "13557902076",
      appId: "1:13557902076:web:44d0c76a6fad7aca514579",
    ),
  );
  
  // Determine initial route based on session state
  final initialRoute = await SessionService.getInitialRoute();
  
  runApp(MyApp(initialRoute: initialRoute));
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  
  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Mrs. Elson's Roll and Read",
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      initialRoute: initialRoute,
      routes: {
        '/': (context) => const LandingPage(),
        '/admin-login': (context) => const AdminLoginPage(),
        '/user-login': (context) => const UserLoginPage(),
        '/game-join': (context) => const GameJoinPage(),
        '/admin-dashboard': (context) => const AdminDashboardWrapper(),
        '/multiplayer-game': (context) => const MultiplayerGameWrapper(),
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
            return MaterialPageRoute(
              builder: (context) => MultiplayerGamePage(
                user: args['user'] as UserModel,
                gameSession: args['gameSession'] as GameSessionModel,
              ),
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
    return FutureBuilder<UserModel?>(
      future: SessionService.getUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
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
          Navigator.of(context).pushReplacementNamed('/admin-login');
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
          // Save current route
          SessionService.saveCurrentRoute('/multiplayer-game');
          return MultiplayerGamePage(
            user: data['user'] as UserModel,
            gameSession: data['gameSession'] as GameSessionModel,
          );
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
      return {
        'user': user,
        'gameSession': gameSession,
      };
    }
    
    return null;
  }
}
