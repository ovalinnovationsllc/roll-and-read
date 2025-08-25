import 'dart:convert';
import '../models/user_model.dart';
import '../models/game_session_model.dart';
import '../utils/safe_print.dart';
import 'firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Conditional import for web-specific localStorage
import 'session_service_web.dart' if (dart.library.io) 'session_service_mobile.dart' as platform;

class SessionService {
  static const String _userKey = 'roll_and_read_user';
  static const String _gameSessionKey = 'roll_and_read_game_session';
  static const String _currentRouteKey = 'roll_and_read_current_route';

  // Save user session
  static Future<void> saveUser(UserModel user) async {
    try {
      final userJson = json.encode(user.toJson());
      await platform.setString(_userKey, userJson);
    } catch (e) {
      safeError('Error saving user session: $e');
    }
  }

  // Get saved user
  static Future<UserModel?> getUser() async {
    try {
      final userJson = await platform.getString(_userKey);
      if (userJson != null) {
        final userMap = json.decode(userJson) as Map<String, dynamic>;
        return UserModel.fromMap(userMap);
      }
    } catch (e) {
      safeError('Error loading user session: $e');
    }
    return null;
  }

  // Save game session
  static Future<void> saveGameSession(GameSessionModel gameSession) async {
    try {
      final gameJson = json.encode(gameSession.toJson());
      await platform.setString(_gameSessionKey, gameJson);
    } catch (e) {
      safeError('Error saving game session: $e');
    }
  }

  // Get saved game session
  static Future<GameSessionModel?> getGameSession() async {
    try {
      final gameJson = await platform.getString(_gameSessionKey);
      if (gameJson != null) {
        final gameMap = json.decode(gameJson) as Map<String, dynamic>;
        return GameSessionModel.fromJson(gameMap);
      }
    } catch (e) {
      safeError('Error loading game session: $e');
      // Clear corrupted session data
      await clearSession();
    }
    return null;
  }

  // Save current route
  static Future<void> saveCurrentRoute(String route) async {
    try {
      await platform.setString(_currentRouteKey, route);
    } catch (e) {
      safeError('Error saving current route: $e');
    }
  }

  // Get saved route
  static Future<String?> getCurrentRoute() async {
    try {
      return await platform.getString(_currentRouteKey);
    } catch (e) {
      safeError('Error loading current route: $e');
    }
    return null;
  }

  // Clear all session data
  static Future<void> clearSession() async {
    try {
      await platform.remove(_userKey);
      await platform.remove(_gameSessionKey);
      await platform.remove(_currentRouteKey);
    } catch (e) {
      safeError('Error clearing session: $e');
    }
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final user = await getUser();
    return user != null;
  }

  // Check if user is in a game
  static Future<bool> isInGame() async {
    final gameSession = await getGameSession();
    return gameSession != null;
  }

  // Get initial route based on session state
  static Future<String> getInitialRoute() async {
    try {
      final savedRoute = await getCurrentRoute();
      final user = await getUser();
      final gameSession = await getGameSession();

      // If we have a saved route and valid session data, use it
      if (savedRoute != null && user != null) {
        if (savedRoute.startsWith('/multiplayer-game') && gameSession != null) {
          return savedRoute;
        } else if (savedRoute.startsWith('/admin-dashboard') && user.isAdmin) {
          return savedRoute;
        } else if (savedRoute == '/game-join' || savedRoute == '/user-login') {
          return savedRoute;
        }
      }

      // Default to home page
      return '/';
    } catch (e) {
      safeError('Error determining initial route: $e');
      // If there's any error, just go to home page
      return '/';
    }
  }

  // Get initial route that's safe for Firebase initialization state
  static Future<String> getInitialRouteSafe(bool isFirebaseReady) async {
    try {
      final savedRoute = await getCurrentRoute();
      final user = await getUser();
      final gameSession = await getGameSession();

      // If Firebase isn't ready, avoid Firebase-dependent routes
      if (!isFirebaseReady) {
        // Clear any Firebase-dependent saved routes and default to home
        if (savedRoute != null && (savedRoute.startsWith('/multiplayer-game') || 
            savedRoute.startsWith('/admin-dashboard'))) {
          await clearSession(); // Clear potentially stale session data
        }
        return '/';
      }

      // More aggressive check for any completed/cancelled games or games older than 24 hours
      // Also validate against Firebase to ensure the game still exists
      if (gameSession != null) {
        final isOldGame = gameSession.endedAt != null && 
                         DateTime.now().difference(gameSession.endedAt!).inHours > 24;
        final isCompletedOrCancelled = gameSession.status == GameStatus.completed || 
                                      gameSession.status == GameStatus.cancelled;
        
        // Check if game still exists in Firebase (handles cases where Firebase data was deleted)
        bool gameExistsInFirebase = false;
        try {
          gameExistsInFirebase = await _checkGameExistsInFirebase(gameSession.gameId);
        } catch (e) {
          safePrint('❌ Error checking game existence in Firebase: $e');
          gameExistsInFirebase = false; // Assume doesn't exist if error
        }
        
        if (isCompletedOrCancelled || isOldGame || !gameExistsInFirebase) {
          safePrint('🚨 Found stale/completed/deleted game session on app launch - clearing and going to home');
          safePrint('🚨 Game ID: ${gameSession.gameId}, Status: ${gameSession.status}, Old: $isOldGame, ExistsInFirebase: $gameExistsInFirebase');
          await clearSession();
          return '/';
        } else {
          safePrint('✅ Found valid game session: ${gameSession.gameId}, Status: ${gameSession.status}');
        }
      }

      // If we have a saved route and valid session data, use it
      if (savedRoute != null && user != null) {
        // Only restore multiplayer game if the game is actually active
        if (savedRoute.startsWith('/multiplayer-game') && gameSession != null && 
           (gameSession.status == GameStatus.inProgress || gameSession.status == GameStatus.waitingForPlayers)) {
          safePrint('✅ Restoring active game session: ${gameSession.gameId}');
          return savedRoute;
        } else if (savedRoute.startsWith('/admin-dashboard') && user.isAdmin) {
          // Teachers can always return to dashboard
          safePrint('✅ Restoring teacher dashboard');
          return savedRoute;
        } else {
          // If user has a saved game route but game is not active, clear the game session
          if (savedRoute.startsWith('/multiplayer-game') && gameSession != null) {
            safePrint('🧹 Clearing inactive game session for fresh start');
            await platform.remove(_gameSessionKey);
            await platform.remove(_currentRouteKey);
          }
        }
        // Don't restore other routes - let users start fresh from home
        safePrint('🏠 Not restoring saved route, sending user to home page');
      }

      // Default to home page
      return '/';
    } catch (e) {
      safeError('Error determining initial route: $e');
      // If there's any error, clear session and go to home page
      await clearSession();
      return '/';
    }
  }

  // Helper method to check if a game exists in Firebase
  static Future<bool> _checkGameExistsInFirebase(String gameId) async {
    try {
      if (!FirestoreService.isFirebaseReady) {
        return false; // If Firebase isn't ready, assume game doesn't exist
      }
      
      // Try to get the game document from Firestore directly
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final gameDoc = await firestore.collection('gameSessions').doc(gameId.toUpperCase()).get();
      
      return gameDoc.exists;
    } catch (e) {
      safePrint('Error checking if game exists in Firebase: $e');
      return false; // If there's an error, assume game doesn't exist
    }
  }
}