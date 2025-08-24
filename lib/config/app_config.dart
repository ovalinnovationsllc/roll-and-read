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
      print('Error loading API key from environment: $e');
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
      print('Error loading demo mode setting: $e');
    }
    // Default to demo mode if no API key is available
    return geminiApiKey.isEmpty;
  }

  // Check if real AI is available
  static bool get hasApiKey => geminiApiKey.isNotEmpty;
}