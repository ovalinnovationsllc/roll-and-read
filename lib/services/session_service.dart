import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/game_session_model.dart';
import '../utils/safe_print.dart';
import 'firestore_service.dart';

class SessionService {
  static const String _userKey = 'roll_and_read_user';
  static const String _gameSessionKey = 'roll_and_read_game_session';
  static const String _currentRouteKey = 'roll_and_read_current_route';

  // Save user session
  static Future<void> saveUser(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = json.encode(user.toJson());
      await prefs.setString(_userKey, userJson);
    } catch (e) {
      safeError('Error saving user session: $e');
    }
  }

  // Get saved user
  static Future<UserModel?> getUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        final userMap = json.decode(userJson) as Map<String, dynamic>;
        return UserModel.fromMap(userMap);
      }
    } catch (e) {
      safeError('Error loading user session: $e');
    }
    return null;
  }

  // Get fresh user data from Firestore and update session
  static Future<UserModel?> refreshUser() async {
    try {
      final cachedUser = await getUser();
      if (cachedUser == null) return null;
      
      // Check if Firebase is ready before attempting refresh
      if (!FirestoreService.isFirebaseReady) {
        safePrint('🔥 Firebase not ready, using cached user data: ${cachedUser.displayName}');
        return cachedUser;
      }
      
      // Refresh user data from Firestore
      final freshUser = await FirestoreService.getUserByEmail(cachedUser.emailAddress);
      if (freshUser != null) {
        // Update the cached session with fresh data
        await saveUser(freshUser);
        safePrint('✅ User session refreshed from Firestore: ${freshUser.displayName}');
        return freshUser;
      }
      
      // If Firestore fails, return cached user
      safePrint('⚠️ Failed to refresh from Firestore, using cached user: ${cachedUser.displayName}');
      return cachedUser;
    } catch (e) {
      safeError('Error refreshing user session: $e');
      return await getUser(); // Fallback to cached data
    }
  }

  // Save game session
  static Future<void> saveGameSession(GameSessionModel gameSession) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gameJson = json.encode(gameSession.toJson());
      await prefs.setString(_gameSessionKey, gameJson);
    } catch (e) {
      safeError('Error saving game session: $e');
    }
  }

  // Get saved game session
  static Future<GameSessionModel?> getGameSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gameJson = prefs.getString(_gameSessionKey);
      if (gameJson != null) {
        final gameMap = json.decode(gameJson) as Map<String, dynamic>;
        return GameSessionModel.fromJson(gameMap);
      }
    } catch (e) {
      safeError('Error loading game session: $e');
      safePrint('⚠️ WARNING: Error loading game session, but NOT clearing - might be recoverable');
      // DON'T clear session on load error - it might be a temporary issue
      // Only clear if explicitly requested
    }
    return null;
  }

  // Clear only the game session (keeps user logged in)
  static Future<void> clearGameSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_gameSessionKey);
      await prefs.remove(_currentRouteKey);
      safePrint('🧹 Cleared game session (user remains logged in)');
    } catch (e) {
      safeError('Error clearing game session: $e');
    }
  }

  // Save current route
  static Future<void> saveCurrentRoute(String route) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentRouteKey, route);
    } catch (e) {
      safeError('Error saving current route: $e');
    }
  }

  // Get saved route
  static Future<String?> getCurrentRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_currentRouteKey);
    } catch (e) {
      safeError('Error loading current route: $e');
    }
    return null;
  }

  // Clear all session data
  static Future<void> clearSession() async {
    try {
      safePrint('🧹 CLEARING SESSION - User requested session clear');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      await prefs.remove(_gameSessionKey);
      await prefs.remove(_currentRouteKey);
      safePrint('🧹 Session cleared successfully');
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

  // Get initial route that's safe for local storage initialization state
  static Future<String> getInitialRouteSafe(bool isStorageReady) async {
    try {
      safePrint('📱 getInitialRouteSafe called with Storage ready: $isStorageReady');
      final savedRoute = await getCurrentRoute();
      final user = await getUser();
      final gameSession = await getGameSession();
      
      safePrint('🔍 Session check - savedRoute: $savedRoute');
      safePrint('🔍 Session check - user: ${user?.displayName} (admin: ${user?.isAdmin})');
      safePrint('🔍 Session check - gameSession: ${gameSession?.gameId} (status: ${gameSession?.status})');

      // NEW USER CHECK: If no saved data exists, this is a fresh app launch
      if (savedRoute == null && user == null && gameSession == null) {
        safePrint('🆕 New user detected - no saved session data, starting at home page');
        return '/';
      }

      // If local storage isn't ready, we should still try to restore the session
      // Don't clear valid sessions just because of storage issues
      if (!isStorageReady) {
        safePrint('⚠️ Local storage not ready, but checking if we can still restore session');
        if (savedRoute != null && user != null && gameSession != null) {
          // Try to restore the game even without storage ready (it might come online)
          if (savedRoute.startsWith('/multiplayer-game') && 
              (gameSession.status.toString().contains('inProgress') || 
               gameSession.status.toString().contains('waitingForPlayers'))) {
            safePrint('✅ STORAGE DOWN BUT RESTORING GAME: ${gameSession.gameId}');
            safePrint('✅ User: ${user.displayName} will rejoin when storage comes online');
            return savedRoute;
          }
        }
        safePrint('🏠 Local storage not ready and no valid session to restore, going to home');
        return '/';
      }

      // More aggressive check for any completed/cancelled games or games older than 24 hours
      // Also validate against Firebase to ensure the game still exists
      if (gameSession != null) {
        safePrint('🔍 Checking saved game session: ${gameSession.gameId}, Status: ${gameSession.status}');
        final isOldGame = gameSession.endedAt != null && 
                         DateTime.now().difference(gameSession.endedAt!).inHours > 24;
        final isCompletedOrCancelled = gameSession.status == GameStatus.completed || 
                                      gameSession.status == GameStatus.cancelled;
        safePrint('🔍 Game checks: isOld=$isOldGame, isCompleted=$isCompletedOrCancelled');
        
        // Check if game still exists in local storage
        bool gameExistsInStorage = true;
        try {
          safePrint('🔍 Checking if game exists in local storage...');
          final existingGame = await FirestoreService.getGameSession(gameSession.gameId);
          gameExistsInStorage = existingGame != null;
          safePrint('🔍 Game exists in local storage: $gameExistsInStorage');
        } catch (e) {
          safePrint('❌ Error checking game existence in local storage: $e');
          gameExistsInStorage = false;
        }
        
        // CRITICAL FIX: Don't clear teacher sessions based on game storage checks!
        // Teachers go to dashboard, not the game
        final isTeacher = user?.isAdmin ?? false;
        
        // Only clear session if game is DEFINITELY completed/cancelled or very old
        // For teachers, ONLY check completed/cancelled status, NOT storage
        if (isCompletedOrCancelled || isOldGame) {
          safePrint('🚨 CLEARING SESSION: Found completed/old game session');
          safePrint('🚨 Game ID: ${gameSession.gameId}, Status: ${gameSession.status}, Old: $isOldGame');
          safePrint('🚨 Reason: isCompleted=$isCompletedOrCancelled, isOld=$isOldGame');
          await clearSession();
          return '/';
        } else if (!isTeacher && !gameExistsInStorage) {
          // Only clear student sessions if game doesn't exist
          safePrint('🚨 CLEARING STUDENT SESSION: Game no longer exists in storage');
          await clearSession();
          return '/';
        } else {
          safePrint('✅ PRESERVING SESSION: Found valid game session: ${gameSession.gameId}, Status: ${gameSession.status}');
          safePrint('✅ Storage check result: $gameExistsInStorage (but allowing restoration anyway)');
        }
      }

      // If we have a saved route and valid session data, use it
      if (savedRoute != null && user != null) {
        // Teachers should go to dashboard, not rejoin games
        if (user.isAdmin && savedRoute.startsWith('/admin-dashboard')) {
          // Teachers can always return to dashboard
          safePrint('✅ Restoring teacher dashboard');
          // Clear any leftover game session for teachers
          if (gameSession != null) {
            safePrint('🧹 Clearing teacher\'s old game session (teachers monitor, not play)');
            await clearGameSession();
          }
          return savedRoute;
        } else if (user.isAdmin) {
          // Teacher but not on dashboard route - send to dashboard
          safePrint('🎓 Teacher detected - redirecting to dashboard');
          if (gameSession != null) {
            await clearGameSession();
          }
          return '/admin-dashboard';
        }
        
        // Students: Only restore multiplayer game if the game is actually active
        if (!user.isAdmin && savedRoute.startsWith('/multiplayer-game') && gameSession != null && 
           (gameSession.status == GameStatus.inProgress || gameSession.status == GameStatus.waitingForPlayers)) {
          safePrint('✅ Restoring active game session for student: ${gameSession.gameId}');
          safePrint('✅ Student: ${user.displayName}');
          safePrint('✅ Game Status: ${gameSession.status}');
          return savedRoute;
        } else {
          // If user has a saved game route but game is not active, clear the game session
          if (savedRoute.startsWith('/multiplayer-game') && gameSession != null) {
            safePrint('🧹 Clearing inactive game session for fresh start');
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove(_gameSessionKey);
            await prefs.remove(_currentRouteKey);
          }
        }
        // Don't restore other routes - let users start fresh from home
        safePrint('🏠 Not restoring saved route, sending user to home page');
      }

      // Default to home page
      return '/';
    } catch (e) {
      safeError('Error determining initial route: $e');
      safePrint('🚨 CLEARING SESSION: Error during getInitialRouteSafe - $e');
      // If there's any error, clear session and go to home page
      await clearSession();
      return '/';
    }
  }

  // Helper method to check if a game exists in local storage
  static Future<bool> _checkGameExistsInStorage(String gameId) async {
    try {
      // Firebase is assumed initialized if we reach this point
      
      // Try to get the game from local storage directly
      final gameSession = await FirestoreService.getGameSession(gameId.toUpperCase());
      
      return gameSession != null;
    } catch (e) {
      safePrint('Error checking if game exists in local storage: $e');
      return false; // If there's an error, assume game doesn't exist
    }
  }
}