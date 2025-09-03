import 'package:flutter/foundation.dart';

/// Safe print utility that won't throw errors in web environments
/// where console.log might not be available
void safePrint(String message) {
  try {
    // Try using debugPrint first (Flutter's safe print)
    if (kDebugMode) {
      // In debug mode, attempt to print
      // debugPrint already handles web environment issues
      debugPrint(message);
    }
  } catch (e) {
    // Silently ignore print errors
    // This prevents the "dart exception thrown from converted Future" error
  }
}

/// Safe error print that won't throw
void safeError(String message) {
  try {
    if (kDebugMode) {
      debugPrint('$message');
    }
  } catch (e) {
    // Silently ignore print errors
  }
}