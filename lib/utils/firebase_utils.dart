import '../services/firestore_service.dart';

class FirebaseUtils {
  /// Wait for Firebase to be ready with timeout
  /// Throws Exception if Firebase doesn't become ready within timeout
  static Future<void> waitForFirebaseReady({
    int maxAttempts = 20, // 10 seconds total by default
    int delayMs = 500,
  }) async {
    int attempts = 0;
    
    while (!FirestoreService.isFirebaseReady && attempts < maxAttempts) {
      await Future.delayed(Duration(milliseconds: delayMs));
      attempts++;
    }
    
    if (!FirestoreService.isFirebaseReady) {
      throw Exception('Firebase initialization timeout');
    }
  }
}