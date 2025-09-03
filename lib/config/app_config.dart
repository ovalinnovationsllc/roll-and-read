import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // Get Gemini API key from environment - never hardcode keys!
  static String get geminiApiKey {
    try {
      if (dotenv.isInitialized) {
        final key = dotenv.env['GEMINI_API_KEY'];
        if (key != null && key.isNotEmpty) {
          return key;
        }
      }
    } catch (e) {
    }
    return '';
  }

  // Get demo mode setting from environment
  static bool get useDemoMode {
    try {
      if (dotenv.isInitialized) {
        final mode = dotenv.env['USE_DEMO_MODE']?.toLowerCase();
        if (mode == 'false') return false;
        if (mode == 'true') return true;
      }
    } catch (e) {
    }
    // Default to demo mode if no API key is available
    return geminiApiKey.isEmpty;
  }

  // Check if real AI is available
  static bool get hasApiKey => geminiApiKey.isNotEmpty;

  // Firebase configuration from environment with fallbacks
  static String get firebaseApiKey {
    try {
      if (dotenv.isInitialized) {
        final key = dotenv.env['FIREBASE_API_KEY'];
        if (key != null && key.isNotEmpty) {
          return key;
        }
      }
    } catch (e) {
    }
    // Environment file not loaded - show helpful error
    return '';
  }

  static String get firebaseAuthDomain {
    try {
      if (dotenv.isInitialized) {
        final domain = dotenv.env['FIREBASE_AUTH_DOMAIN'];
        if (domain != null && domain.isNotEmpty) {
          return domain;
        }
      }
    } catch (e) {
    }
    return '';
  }

  static String get firebaseProjectId {
    try {
      if (dotenv.isInitialized) {
        final projectId = dotenv.env['FIREBASE_PROJECT_ID'];
        if (projectId != null && projectId.isNotEmpty) {
          return projectId;
        }
      }
    } catch (e) {
    }
    return '';
  }

  static String get firebaseStorageBucket {
    try {
      if (dotenv.isInitialized) {
        final bucket = dotenv.env['FIREBASE_STORAGE_BUCKET'];
        if (bucket != null && bucket.isNotEmpty) {
          return bucket;
        }
      }
    } catch (e) {
    }
    return '';
  }

  static String get firebaseMessagingSenderId {
    try {
      if (dotenv.isInitialized) {
        final senderId = dotenv.env['FIREBASE_MESSAGING_SENDER_ID'];
        if (senderId != null && senderId.isNotEmpty) {
          return senderId;
        }
      }
    } catch (e) {
    }
    return '';
  }

  static String get firebaseAppId {
    try {
      if (dotenv.isInitialized) {
        final appId = dotenv.env['FIREBASE_APP_ID'];
        if (appId != null && appId.isNotEmpty) {
          return appId;
        }
      }
    } catch (e) {
    }
    return '';
  }
}