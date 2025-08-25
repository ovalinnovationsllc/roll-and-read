import 'dart:convert';
import '../models/user_model.dart';
import '../models/game_session_model.dart';
import '../utils/safe_print.dart';

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
}